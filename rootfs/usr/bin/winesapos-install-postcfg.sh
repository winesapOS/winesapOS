#!/bin/bash

set -x

# Configure a newly installed winesapOS system. This is ran inside of the target system by the
# Calamares 'shellprocess@postcfg' module, after the rootfs tarball has been extracted and before
# the boot loader is installed.

# The live winesapOS media that is running the installer is already using the default file system
# labels. Use labels suffixed with a "2", for the second installation, so that the two do not
# conflict, which otherwise leads to both of them being unbootable.
btrfs filesystem label / winesapos-root2

# The separate boot partition is created by the "partitionLayout" in partition.conf, or by the user
# during manual partitioning. Calamares already labels the one it creates itself.
if [[ "$(findmnt --noheadings --output FSTYPE /boot)" == "ext4" ]]; then
    e2label "$(findmnt --noheadings --output SOURCE /boot)" winesapos-boot2
fi

efi_device="$(findmnt --noheadings --output SOURCE /boot/efi)"
if [[ -n "${efi_device}" ]]; then
    fatlabel "${efi_device}" WOS-EFI2
fi

# winesapOS configures GRUB to boot using file system labels. All of them need to point at the new
# labels so that this installation boots itself instead of the live media that installed it.
sed -i 's/linux_root_device_thisversion=LABEL=winesapos-root$/linux_root_device_thisversion=LABEL=winesapos-root2/g' /etc/grub.d/10_linux
# shellcheck disable=SC2026
sed -i 's/winesapos-root\//winesapos-root2\//'g /usr/share/libalpm/hooks/winesapos-etc-grub.d-10_linux.hook
sed -i 's/--label winesapos-root /--label winesapos-root2 /g' /usr/share/grub/grub-mkconfig_lib
sed -i 's/--label winesapos-root /--label winesapos-root2 /g' /usr/share/libalpm/hooks/winesapos-usr-share-grub-grub-mkconfig_lib.hook

root_source="$(findmnt --noheadings --output SOURCE /)"
luks_device=""
if [[ "${root_source}" == "/dev/mapper/"* ]]; then
    dm_device="$(basename "$(readlink -f "${root_source}")")"
    # A device mapper device lists the device it is built on top of here.
    luks_slave="$(find "/sys/class/block/${dm_device}/slaves" -maxdepth 1 -mindepth 1 -printf '%f\n' 2> /dev/null | head -n 1)"
    if [[ -n "${luks_slave}" ]]; then
        luks_device="/dev/${luks_slave}"
    fi
fi

if [[ -n "${luks_device}" ]] && cryptsetup isLuks "${luks_device}"; then
    echo "INFO: The root file system is encrypted on ${luks_device}."
    cryptsetup config "${luks_device}" --label winesapos-luks2

    if grep -q "cryptdevice=LABEL=winesapos-luks:" /etc/default/grub; then
        sed -i 's/cryptdevice=LABEL=winesapos-luks:/cryptdevice=LABEL=winesapos-luks2:/g' /etc/default/grub
    elif ! grep -q "cryptdevice=" /etc/default/grub; then
        sed -i 's#GRUB_CMDLINE_LINUX="#GRUB_CMDLINE_LINUX="cryptdevice=LABEL=winesapos-luks2:cryptroot root=/dev/mapper/cryptroot #g' /etc/default/grub
    fi

    ## Only the secure image builds an initramfs that can unlock the root file system. Installing an
    ## encrypted system from any other image has to have these hooks added.
    if ! grep -E "^HOOKS=" /etc/mkinitcpio.conf | grep -q encrypt; then
        sed -i 's/^\(HOOKS=.*\)filesystems/\1keymap encrypt filesystems/' /etc/mkinitcpio.conf
    fi

    # Disable the crypttab since the 'encrypt' initramfs hook would ask for the password twice.
    luks_uuid="$(blkid -s UUID -o value "${luks_device}")"
    if [[ -n "${luks_uuid}" ]] && [[ -f /etc/crypttab ]]; then
        sed -i "\#${luks_uuid}#d" /etc/crypttab
    fi

    # Calamares will set '/dev/mapper/luks-<UUID>' but winesapOS needs to use '/dev/mapper/cryptroot' instead.
    root_fs_uuid="$(findmnt --noheadings --first-only --output UUID /)"
    if [[ -n "${root_fs_uuid}" ]]; then
        echo "INFO: Replacing ${root_source} with UUID=${root_fs_uuid} in /etc/fstab."
        sed -i "s#^${root_source}\([[:space:]]\)#UUID=${root_fs_uuid}\1#" /etc/fstab
    fi
else
    echo "INFO: The root file system is not encrypted."
    # Remove all conflicts if installing from a secure image.
    sed -i -E 's/cryptdevice=LABEL=winesapos-luks[0-9]*:[^ "]* ?//g' /etc/default/grub
    sed -i -E 's#root=/dev/mapper/cryptroot ?##g' /etc/default/grub
    hooks_current="$(grep -E "^HOOKS=" /etc/mkinitcpio.conf | sed -E 's/^HOOKS=\((.*)\).*/\1/')"
    hooks_new=""
    for hook in ${hooks_current}; do
        if [[ "${hook}" != "encrypt" ]]; then
            hooks_new="${hooks_new}${hooks_new:+ }${hook}"
        fi
    done
    if [[ "${hooks_new}" != "${hooks_current}" ]]; then
        echo "INFO: Removing the 'encrypt' initramfs hook."
        sed -i "s/^HOOKS=.*/HOOKS=(${hooks_new})/" /etc/mkinitcpio.conf
    fi
fi

# This is a brand new installation so the first-time setup has to run on the first login. The live
# media that it was copied from has already deleted the auto-start shortcut if the setup was
# completed there.
desktop_user="$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1; exit}' /etc/passwd)"
if [[ -n "${desktop_user}" ]]; then
    desktop_home="$(getent passwd "${desktop_user}" | cut -d: -f6)"
    if [[ -f "${desktop_home}/.winesapos/winesapos-setup.desktop" ]]; then
        mkdir -p "${desktop_home}/.config/autostart"
        ln -f -s "${desktop_home}/.winesapos/winesapos-setup.desktop" \
            "${desktop_home}/.config/autostart/winesapos-setup.desktop"
        chown -R "${desktop_user}":"${desktop_user}" "${desktop_home}/.config/autostart"
    fi
fi

# Reset unique identifiers.
# The hostname is handled during the first-time setup.
rm -f \
  /etc/ssh/ssh_host_* \
  /var/lib/systemd/random-seed \
  /var/lib/systemd/credential.secret \
  /var/lib/NetworkManager/secret_key

# The Calamares 'fstab' module overwrites the /etc/fstab that was copied over so the winesapOS tmpfs
# mounts need to be added back.
if ! grep -q -P "^tmpfs\s+/tmp\s" /etc/fstab; then
    echo "tmpfs    /tmp    tmpfs    rw,nosuid,nodev,inode64    0 0" >> /etc/fstab
fi
# The secure image keeps a persistent /var/log instead.
if [[ "$(grep VARIANT_ID /usr/lib/os-release-winesapos | cut -d = -f 2)" != "secure" ]]; then
    if ! grep -q -P "^tmpfs\s+/var/log\s" /etc/fstab; then
        echo "tmpfs    /var/log    tmpfs    rw,nosuid,nodev,inode64    0 0" >> /etc/fstab
    fi
fi

# Load all of the drivers required by the new hardware.
#
# 'mkinitcpio' reports a failure if any one kernel had a problem, even when it still generated a
# usable image for every kernel. winesapOS hits two of these on every build:
#
#   ==> WARNING: Possibly missing '/bin/bash' for script: /usr/lib/initcpio/hooks/ventoy
#   ==> ERROR: module not found: 'apple_bce'
#
# The Ventoy hook warning is harmless and the 'apple_bce' driver for T2 Macs is only built against
# the Nobara kernel, not Linux LTS. Neither is a reason to fail an installation, so only stop if no
# initramfs was generated at all.
if ! mkinitcpio -P; then
    echo "WARNING: 'mkinitcpio' reported errors. Checking whether an initramfs was still generated..."
fi

if [[ "$(find /boot -maxdepth 1 -name 'initramfs-*.img' | wc -l)" == "0" ]]; then
    echo "ERROR: No initramfs was generated."
    exit 1
fi

echo "INFO: Generated these initramfs images:"
find /boot -maxdepth 1 -name 'initramfs-*.img' -printf '%p %s bytes\n'
