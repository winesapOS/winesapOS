#!/bin/bash

WINESAPOS_DEBUG_TESTS="${WINESAPOS_DEBUG_TESTS:-false}"
if [[ "${WINESAPOS_DEBUG_TESTS}" == "true" ]]; then
    set -x
else
    set +x
fi

echo "Tests start time: $(date)"

current_shell=$(cat /proc/$$/comm)
if [[ "${current_shell}" != "bash" ]]; then
    echo "winesapOS scripts require Bash but ${current_shell} detected. Exiting..."
    exit 1
fi

# Load default environment variables.
# shellcheck disable=SC1091
. ./env/winesapos-env-defaults.sh

WINESAPOS_DEVICE="${WINESAPOS_DEVICE:-vda}"

if [[ "${WINESAPOS_CREATE_DEVICE}" == "true" ]];
    then DEVICE="$(cat /tmp/winesapos-device.txt)"
else
    DEVICE="/dev/${WINESAPOS_DEVICE}"
fi

failed_tests=0
winesapos_test_failure() {
    # shellcheck disable=SC2003 disable=SC2086
    failed_tests=$(expr ${failed_tests} + 1)
    echo FAIL
}

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    DEVICE_WITH_PARTITION="${DEVICE}"
    if echo "${DEVICE}" | grep -q -P "^/dev/(nvme|loop)"; then
        # "nvme" and "loop" devices separate the device name and partition number by using a "p".
        # Example output: /dev/loop0p
        DEVICE_WITH_PARTITION="${DEVICE}p"
    fi

    echo "Testing partitions..."
    parted_print="$(parted "${DEVICE}" print)"

    printf "\t\tChecking the partition table type..."
    if echo "${parted_print}" | grep -q "Partition Table: ${WINESAPOS_PARTITION_TABLE}"; then
        echo PASS
    else
        winesapos_test_failure
    fi

    printf "\t\tChecking that %s1 is not formatted..." "${DEVICE_WITH_PARTITION}"
    if echo "${parted_print}" | grep -P "^ 1 " | grep -q -P "kB\s+primary"; then
        echo PASS
    else
        winesapos_test_failure
    fi

    printf "\t\tChecking that the boot partition has the 'boot' partition flag..."
    if parted "${DEVICE}" print | grep ext4 | grep -q boot; then
        echo PASS
    else
        winesapos_test_failure
    fi

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        printf "\t\tChecking that %s2 is formatted as exFAT..." "${DEVICE_WITH_PARTITION}"
        # 'parted' does not support finding if a partition is exFAT formatted.
        # 'lsblk -f' does but that does not work inside of a container.
        # https://github.com/winesapOS/winesapOS/issues/507
        if echo "${parted_print}" | grep -P "^ 2 " | grep -q -P "GB\s+primary"; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\t\tChecking that %s2 has the 'msftdata' partition flag..." "${DEVICE_WITH_PARTITION}"
        if parted "${DEVICE}" print | grep -q msftdata; then
            echo PASS
        else
            winesapos_test_failure
        fi
    fi

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        printf "\t\tChecking that %s3 is formatted as FAT32..." "${DEVICE_WITH_PARTITION}"
        if echo "${parted_print}" | grep -P "^ 3 " | grep -q fat; then
            echo PASS
        else
            winesapos_test_failure
        fi
    else
        printf "\t\tChecking that %s2 is formatted as FAT32..." "${DEVICE_WITH_PARTITION}"
        if echo "${parted_print}" | grep -P "^ 2 " | grep -q fat; then
            echo PASS
        else
            winesapos_test_failure
        fi
    fi

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        printf "\t\tChecking that %s4 is formatted as ext4..." "${DEVICE_WITH_PARTITION}"
        if echo "${parted_print}" | grep -P "^ 4 " | grep -q ext4; then
            echo PASS
        else
            winesapos_test_failure
        fi
    else
        printf "\t\tChecking that %s3 is formatted as ext4..." "${DEVICE_WITH_PARTITION}"
        if echo "${parted_print}" | grep -P "^ 3 " | grep -q ext4; then
            echo PASS
        else
            winesapos_test_failure
        fi
    fi

    if [[ "${WINESAPOS_ENABLE_PORTABLE_STORAGE}" == "true" ]]; then
        printf "\t\tChecking that %s5 is formatted as Btrfs..." "${DEVICE_WITH_PARTITION}"
        if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
            if parted /dev/mapper/cryptroot print | grep -q -P "^ 1 .*btrfs"; then
                echo PASS
            else
                winesapos_test_failure
            fi
        else
            if echo "${parted_print}" | grep -P "^ 5 " | grep -q btrfs; then
                echo PASS
            else
                winesapos_test_failure
            fi
        fi
    else
        printf "\t\tChecking that %s4 is formatted as Btrfs..." "${DEVICE_WITH_PARTITION}"
        if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
            if parted /dev/mapper/cryptroot print | grep -q -P "^ 1 .*btrfs"; then
                echo PASS
            else
                winesapos_test_failure
            fi
        else
            if echo "${parted_print}" | grep -P "^ 4 " | grep -q btrfs; then
                echo PASS
            else
                winesapos_test_failure
            fi
        fi
    fi

    printf "Checking that optimal IO schedulers are enabled..."
    if grep -q kyber "${WINESAPOS_INSTALL_DIR}"/etc/udev/rules.d/60-winesapos-io-schedulers.rules; then
        echo PASS
    else
        winesapos_test_failure
    fi

    printf "Testing partitions complete.\n\n"

    echo "Testing /etc/fstab mounts..."

    echo "Debug output of fstab contents below..."
    cat "${WINESAPOS_INSTALL_DIR}"/etc/fstab

    printf "\t\tChecking that each mount exists in /etc/fstab...\n"
    for i in \
      "^(\/dev\/mapper\/cryptroot|LABEL\=).*\s+/\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1,discard" \
      "^(\/dev\/mapper\/cryptroot|LABEL\=).*\s+/home\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1" \
      "^(\/dev\/mapper\/cryptroot|LABEL\=).*\s+/swap\s+btrfs\s+rw,noatime,nodiratime,compress-force=zstd:1" \
      "^(none|tmpfs)\s+/tmp\s+tmpfs\s+rw.*\s+0\s+0" \
      "^(none|tmpfs)\s+/var/log\s+tmpfs\s+rw.*\s+0\s+0" \
      "^(none|tmpfs)\s+/var/tmp\s+tmpfs\s+rw.*\s+0\s+0"
        do printf "\t\t%s..." "${i}"
        if grep -q -P "${i}" "${WINESAPOS_INSTALL_DIR}"/etc/fstab; then
            echo PASS
        else
            winesapos_test_failure
        fi
    done

    if [[ "${WINESAPOS_BOOTLOADER}" == "grub" ]]; then
        fstab_efi="^LABEL\=.*\s+/boot/efi\s+vfat\s+rw"
        printf "\t\t%s..." "${fstab_efi}"
        if grep -q -P "${fstab_efi}" "${WINESAPOS_INSTALL_DIR}"/etc/fstab; then
            echo PASS
        else
            winesapos_test_failure
        fi
   elif [[ "${WINESAPOS_BOOTLOADER}" == "systemd-boot" ]]; then
        fstab_efi="^LABEL\=.*\s+/boot\s+vfat\s+rw"
        printf "\t\t%s..." "${fstab_efi}"
        if grep -q -P "${fstab_efi}" "${WINESAPOS_INSTALL_DIR}"/etc/fstab; then
            echo PASS
        else
            winesapos_test_failure
        fi
    fi
    printf "Testing /etc/fstab mounts complete.\n\n"

    echo "Testing Btrfs subvolumes..."

    printf "\t\tChecking that the Btrfs subvolumes exist...\n"
    for i in \
      ".snapshots" \
      "home" \
      "home/\.snapshots" \
      "swap"
        do printf "\t\t%s..." "${i}"
        if btrfs subvolume list "${WINESAPOS_INSTALL_DIR}" | grep -q -P " ${i}$"; then
            echo PASS
        else
            winesapos_test_failure
        fi
    done

    printf "Testing Btrfs subvolumes complete.\n\n"
fi

printf "\t\tChecking that the open file limits has been increased via systemd..."
if grep -P -q "^DefaultLimitNOFILE=524288" "${WINESAPOS_INSTALL_DIR}"/usr/lib/systemd/user.conf.d/20-file-limits.conf; then
    echo PASS
else
    winesapos_test_failure
fi

echo "Testing user creation..."

printf "\t\tChecking that the 'winesap' user exists..."
if grep -P -q "^${WINESAPOS_USER_NAME}:" "${WINESAPOS_INSTALL_DIR}"/etc/passwd; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\t\tChecking that the home directory for the 'winesap' user exists..."
if [ -d "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/ ]; then
    echo PASS
else
    winesapos_test_failure
fi

printf "Testing user creation complete.\n\n"

echo "Testing package repositories..."

printf "\tChecking that the winesapOS repository was added..."
if [[ "${WINESAPOS_ENABLE_TESTING_REPO}" == "false" ]]; then
    if grep -q -P "^\[winesapos\]" "${WINESAPOS_INSTALL_DIR}"/etc/pacman.conf; then
        echo PASS
    else
        winesapos_test_failure
    fi
else
    if grep -q -P "^\[winesapos-testing\]" "${WINESAPOS_INSTALL_DIR}"/etc/pacman.conf; then
        echo PASS
    else
        winesapos_test_failure
    fi
fi

printf "\tChecking that the winesapOS GPG key was added..."
if chroot "${WINESAPOS_INSTALL_DIR}" pacman-key --list-keys | grep -q 1805E886BECCCEA99EDF55F081CA29E4A4B01239; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the Chaotic AUR repository was added..."
if grep -q -P "^\[chaotic-aur\]" "${WINESAPOS_INSTALL_DIR}"/etc/pacman.conf; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the Chaotic AUR GPG key was added..."
if chroot "${WINESAPOS_INSTALL_DIR}" pacman-key --list-keys | grep -q 3056513887B78AEB; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that Pacman is configured to use 'curl-static'..."
if grep -q 'XferCommand = /usr/bin/curl-static' "${WINESAPOS_INSTALL_DIR}"/etc/pacman.conf; then
    echo PASS
else
    winesapos_test_failure
fi

echo "Testing package repositories complete."

echo "Testing package installations..."

function pacman_search() {
    chroot "${WINESAPOS_INSTALL_DIR}" pacman -Qsq "${1}" &> /dev/null
}

function pacman_search_loop() {
    for i in "${@}"
        do printf "\t%s..." "${i}"
        if pacman_search "${i}"; then
            echo PASS
        else
            winesapos_test_failure
        fi
    done
}

printf "\tChecking that the base system packages are installed..."
pacman_search_loop \
  accountsservice \
  arch-install-scripts \
  base \
  efibootmgr \
  flatpak \
  fprintd \
  fwupd \
  inetutils \
  inputplumber \
  iwd \
  jq \
  man-db \
  mkinitcpio \
  networkmanager \
  spice-vdagent \
  tzupdate

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    printf "\tChecking that the Linux kernel packages are installed..."
    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        pacman_search_loop linux-fsync-nobara-bin linux66 linux66-headers linux-firmware mkinitcpio-firmware amd-ucode intel-ucode apple-bcm-firmware
    elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
        pacman_search_loop linux-fsync-nobara-bin linux-lts linux-lts-headers linux-firmware mkinitcpio-firmware amd-ucode intel-ucode apple-bcm-firmware
    fi
fi

if [[ "${WINESAPOS_INSTALL_GAMING_TOOLS}" == "true" ]]; then
    printf "\tChecking that gaming tools are installed..."
    pacman_search_loop \
      gamemode \
      lib32-gamemode \
      gamescope \
      gamescope-session-git \
      gamescope-session-steam-git \
      goverlay-git \
      game-devices-udev \
      mangohud-git \
      lib32-mangohud-git \
      nexusmods-app-bin \
      opengamepadui-bin \
      openrazer-daemon \
      polychromatic \
      steam \
      steam-native-runtime \
      umu-launcher \
      vkbasalt \
      lib32-vkbasalt \
      zenity \
      zerotier-one \
      zerotier-gui-git

    # Disable this ShellCheck because we may need to loop through more files in the future.
    # shellcheck disable=SC2043
    for i in \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/EmuDeck.AppImage; do
        printf "\t\tChecking if the file $%s exists..." "${i}"
        if [ -f "${i}" ]; then
          echo PASS
        else
          winesapos_test_failure
        fi
    done
fi

printf "\t\tChecking if Firefox ESR is configured to use libeatmydata..."
if grep -q -P "^Exec=/usr/bin/eatmydata " "${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/Desktop/firefox-esr.desktop"; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the desktop environment packages are installed..."
pacman_search_loop \
  mesa \
  lib32-mesa \
  opencl-rusticl-mesa
  lib32-opencl-rusticl-mesa \
  sddm \
  vulkan-nouveau \
  xwayland-run-git

if [[ "${WINESAPOS_XORG_ENABLE}" == "true" ]]; then
    pacman_search_loop \
      xcb-util-keysyms \
      xcb-util-cursor \
      xcb-util-wm \
      xcb-util-xrm
      xf86-input-libinput \
      xorg-server \
      xorg-xinit \
      xorg-xinput \
      xterm
else
    pacman_search_loop \
      foot \
      libinput \
      wayland \
      xorg-xwayland
fi

if [[ "${WINESAPOS_DE}" == "i3" ]]; then
    pacman_search i3-wm

elif [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    pacman_search_loop \
      cinnamon \
      maui-pix \
      xorg-server \
      xed

    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        pacman_search_loop \
            cinnamon-sounds \
            cinnamon-wallpapers \
            manjaro-cinnamon-settings \
            manjaro-settings-manager$ \
            adapta-maia-theme \
            kvantum-manjaro
    fi

elif [[ "${WINESAPOS_DE}" == "cosmic" ]]; then
    pacman_search cosmic-session

elif [[ "${WINESAPOS_DE}" == "gnome" ]]; then
    pacman_search_loop \
      gnome \
      gnome-tweaks

    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        pacman_search_loop \
          manjaro-gnome-settings \
          manjaro-settings-manager
    fi

elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    pacman_search_loop \
      plasma-meta \
      plasma-nm \
      dolphin \
      ffmpegthumbs \
      gwenview \
      kdegraphics-thumbnailers \
      konsole \
      kate \
      kdeconnect \
      kio

    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        pacman_search_loop \
          manjaro-kde-settings \
          manjaro-settings-manager-knotifier \
          breath-wallpapers \
          plasma6-themes-breath \
          sddm-breath-theme
    fi

    printf "\tChecking that Plasma (Wayland) session is set as the default..."
    export wayland_session_file="plasma.desktop"
    if [[ "${WINESAPOS_DISTRO_DETECTED}" == "manjaro" ]]; then
        export wayland_session_file="plasmawayland.desktop"
    fi
    if ls "${WINESAPOS_INSTALL_DIR}/usr/share/wayland-sessions/0${wayland_session_file}" &> /dev/null; then
        echo PASS
    else
        winesapos_test_failure
    fi

    printf "\tChecking that passwordless login has been configured...\n"
    for i in kde sddm; do
        printf "\t\t%s..." "${i}"
        if grep -q "nopasswdlogin" "${WINESAPOS_INSTALL_DIR}"/etc/pam.d/"${i}"; then
            echo PASS
        else
            winesapos_test_failure
        fi
    done

    printf "\tChecking that the user is part of the 'nopasswdlogin' group..."
    if grep nopasswdlogin: "${WINESAPOS_INSTALL_DIR}"/etc/group | grep -q "${WINESAPOS_USER_NAME}"; then
        echo PASS
    else
        winesapos_test_failure
    fi

    printf "\tChecking that the virtual keyboard has been enabled by default..."
    if grep -q "InputMethod=qtvirtualkeyboard" "${WINESAPOS_INSTALL_DIR}"/etc/sddm.conf.d/winesapos.conf; then
        echo PASS
    else
        winesapos_test_failure
    fi
    echo "Configuring passwordless login complete."

elif [[ "${WINESAPOS_DE}" == "plasma-mobile" ]]; then
    pacman_search_loop \
      maliit-keyboard \
      plasma-mobile

elif [[ "${WINESAPOS_DE}" == "sway" ]]; then
    pacman_search sway
fi

printf "\tChecking that SDDM will hide Nix build users..."
if [[ "$(chroot "${WINESAPOS_INSTALL_DIR}" crudini --get /etc/sddm.conf.d/uid.conf Users MaximumUid)" == "2999" ]]; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that Bluetooth packages are installed..."
pacman_search_loop bluez bluez-utils blueman bluez-qt
printf "\tChecking that Bluetooth packages are installed complete."

printf "\tChecking that the 'bluetooth' service is enabled..."
if chroot "${WINESAPOS_INSTALL_DIR}" systemctl --quiet is-enabled bluetooth.service; then
    echo PASS
else
    winesapos_test_failure
fi

printf "Testing package installations complete.\n\n"

echo "Testing drivers installation..."
printf "\tChecking that the 'apple-bce' driver is loaded on boot..."
if grep -P "^MODULES" "${WINESAPOS_INSTALL_DIR}"/etc/mkinitcpio.conf | grep -q apple-bce; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the 'apple-touchbar' driver will load automatically..."
if grep -q "install apple-touchbar" "${WINESAPOS_INSTALL_DIR}"/usr/lib/modprobe.d/winesapos-mac.conf; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that USB modules will load automatically..."
if grep -P "^MODULES" "${WINESAPOS_INSTALL_DIR}"/etc/mkinitcpio.conf | grep -q "usbhid xhci_hcd"; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the Intel VMD module will load automatically..."
if grep -P "^MODULES" "${WINESAPOS_INSTALL_DIR}"/etc/mkinitcpio.conf | grep -q "nvme vmd"; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the 'radeon' driver will not load for specific older GPUs..."
if grep -q "options radeon si_support=0" "${WINESAPOS_INSTALL_DIR}"/usr/lib/modprobe.d/winesapos-amd.conf; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the AMDGPU workaround is configured..."
if grep -q "options amdgpu noretry=0" "${WINESAPOS_INSTALL_DIR}"/usr/lib/modprobe.d/winesapos-amd.conf; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that 'linux-fsync-nobara-bin' is installed..."
if pacman_search linux-fsync-nobara-bin; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that 'usbmuxd' is installed..."
if pacman_search usbmuxd; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that newer udev rules for 'usbmuxd' are installed..."
if grep -q "make sure iBridge (T1)" "${WINESAPOS_INSTALL_DIR}"/usr/lib/udev/rules.d/39-usbmuxd.rules; then
    echo PASS
else
    winesapos_test_failure
fi

printf "Testing drivers installation complete.\n\n"

echo "Testing that all files have been copied over..."

for i in \
  "${WINESAPOS_INSTALL_DIR}"/usr/lib/systemd/user/winesapos-mute.service \
  "${WINESAPOS_INSTALL_DIR}"/usr/lib/systemd/system/winesapos-resize-root-file-system.service \
  "${WINESAPOS_INSTALL_DIR}"/usr/lib/systemd/system/winesapos-sddm-health-check.service \
  "${WINESAPOS_INSTALL_DIR}"/etc/snapper/configs/root \
  "${WINESAPOS_INSTALL_DIR}"/etc/snapper/configs/home \
  "${WINESAPOS_INSTALL_DIR}"/usr/lib/modules-load.d/winesapos-mac.conf \
  "${WINESAPOS_INSTALL_DIR}"/usr/lib/os-release-winesapos \
  "${WINESAPOS_INSTALL_DIR}"/usr/lib/sysctl.d/50-winesapos-open-files.conf \
  "${WINESAPOS_INSTALL_DIR}"/usr/lib/sysctl.d/50-winesapos-ram-write-cache.conf \
  "${WINESAPOS_INSTALL_DIR}"/usr/local/bin/winesapos-mute.sh \
  "${WINESAPOS_INSTALL_DIR}"/usr/local/bin/winesapos-resize-root-file-system.sh \
  "${WINESAPOS_INSTALL_DIR}"/usr/local/bin/winesapos-sddm-health-check.sh \
  "${WINESAPOS_INSTALL_DIR}"/usr/share/libalpm/hooks/winesapos-etc-grub.d-10_linux.hook \
  "${WINESAPOS_INSTALL_DIR}"/usr/share/libalpm/hooks/winesapos-usr-share-grub-grub-mkconfig_lib.hook \
  "${WINESAPOS_INSTALL_DIR}"/var/winesapos/winesapos-install.log
    do printf "\t%s..." "${i}"
    if [ -f "${i}" ]; then
        echo PASS
    else
        winesapos_test_failure
    fi
done

printf "\t%s/etc/os-release-winesapos..." "${WINESAPOS_INSTALL_DIR}"
if [[ -L "${WINESAPOS_INSTALL_DIR}"/etc/os-release-winesapos ]]; then
    echo PASS
else
    winesapos_test_failure
fi

printf "Testing that all files have been copied over complete.\n\n"

echo "Testing that services are enabled..."

for i in \
  auto-cpufreq \
  cups \
  fstrim.timer \
  inputplumber \
  NetworkManager \
  sddm \
  snapd \
  snapper-timeline.timer \
  systemd-timesyncd \
  winesapos-sddm-health-check \
  winesapos-resize-root-file-system
    do printf "\t%s..." "${i}"
    if chroot "${WINESAPOS_INSTALL_DIR}" systemctl --quiet is-enabled "${i}"; then
        echo PASS
    else
        winesapos_test_failure
    fi
done

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    printf "\tapparmor..."
    if chroot "${WINESAPOS_INSTALL_DIR}" systemctl --quiet is-enabled apparmor; then
        echo PASS
    else
        winesapos_test_failure
    fi
fi

printf "Testing that services are enabled complete.\n\n"

if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
    echo "Testing the bootloader..."

    printf "\tChecking that there are no fallback initramfs images..."
    # shellcheck disable=SC2010
    if ! ls -1 "${WINESAPOS_INSTALL_DIR}"/boot | grep -q "-fallback.img"; then
        echo PASS
    else
        winesapos_test_failure
    fi

    if [[ "${WINESAPOS_BOOTLOADER}" == "grub" ]]; then
        if [[ "${WINESAPOS_PARTITION_TABLE}" == "gpt" ]]; then
            printf " \tChecking that the generic '/boot/efi/EFI/BOOT/BOOTX64.EFI' file exists..."
            if [ -f "${WINESAPOS_INSTALL_DIR}"/boot/efi/EFI/BOOT/BOOTX64.EFI ]; then
                echo PASS
            else
                winesapos_test_failure
            fi
        fi

        printf "\tChecking that GRUB packages are installed..."
        pacman_search_loop \
          grub \
          grub-btrfs

        printf "\tChecking that GRUB 2 has been installed..."
        if dd if="${DEVICE}" bs=512 count=1 2> /dev/null | strings | grep -q GRUB; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that the '/boot/grub/grub.cfg' file exists..."
        if [ -f "${WINESAPOS_INSTALL_DIR}"/boot/grub/grub.cfg ]; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that the GRUB terminal is set to 'console'..."
        if grep -q "terminal_input console" "${WINESAPOS_INSTALL_DIR}"/boot/grub/grub.cfg; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that the GRUB timeout has been set to 10 seconds..."
        if grep -q "set timeout=10" "${WINESAPOS_INSTALL_DIR}"/boot/grub/grub.cfg; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that the GRUB timeout style been set to 'menu'..."
        if grep -q "set timeout_style=menu" "${WINESAPOS_INSTALL_DIR}"/boot/grub/grub.cfg; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that GRUB has command line arguments for faster input device polling..."
        for i in usbhid.jspoll=1 usbhid.kbpoll=1 usbhid.mousepoll=1
            do printf "\t%s..." "${i}"
            if grep -q "${i}" "${WINESAPOS_INSTALL_DIR}"/boot/grub/grub.cfg; then
                echo PASS
            else
                winesapos_test_failure
            fi
        done
        printf "\tChecking that GRUB has command line arguments for faster input device polling complete."

        printf "\tChecking that GRUB has the command line argument to enable NVMe support..."
        if grep -q "nvme_load=yes" "${WINESAPOS_INSTALL_DIR}"/boot/grub/grub.cfg; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that GRUB will search for the winesapOS root label..."
        if grep -q "search --no-floppy --label winesapos-root --set root" "${WINESAPOS_INSTALL_DIR}"/boot/grub/grub.cfg; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that GRUB will boot the winesapOS root label..."
        if grep -q "root=LABEL=winesapos-root" "${WINESAPOS_INSTALL_DIR}"/boot/grub/grub.cfg; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that GRUB has the command line argument to enable Intel Xe support on the first generation of hardwarae..."
        if grep -q "i915.force_probe=!9a49 xe.force_probe=9149" "${WINESAPOS_INSTALL_DIR}"/boot/grub/grub.cfg; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that GRUB will use partition UUIDs instead of Linux UUIDs..."
        if grep -q -P "^GRUB_DISABLE_LINUX_UUID=true" "${WINESAPOS_INSTALL_DIR}"/etc/default/grub; then
            if grep -q -P "^GRUB_DISABLE_LINUX_PARTUUID=true" "${WINESAPOS_INSTALL_DIR}"/etc/default/grub; then
                echo PASS
            else
                winesapos_test_failure
            fi
        else
            winesapos_test_failure
        fi

        printf "\tChecking that GRUB will automatically boot into the correct kernel..."
        export GRUB_DEFAULT="winesapOS Linux, with Linux linux-fsync-nobara-bin"
        if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
            export GRUB_DEFAULT="winesapOS Linux \(Kernel: bin\)"
        fi
        if grep -q -P "^GRUB_DEFAULT=\"${GRUB_DEFAULT}\"" "${WINESAPOS_INSTALL_DIR}"/etc/default/grub; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that the Vimix theme for GRUB exists..."
        if [ -f "${WINESAPOS_INSTALL_DIR}"/boot/grub/themes/Vimix/theme.txt ]; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that the Vimix theme for GRUB is enabled..."
        if grep -q -P "^GRUB_THEME=/boot/grub/themes/Vimix/theme.txt" "${WINESAPOS_INSTALL_DIR}"/etc/default/grub; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that GRUB is set to use resolutions supported by our theme..."
        if grep -q -P "^GRUB_GFXMODE=1280x720,auto" "${WINESAPOS_INSTALL_DIR}"/etc/default/grub; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that GRUB is set to use the text GFX payload for better boot compatibility..."
        if grep -q -P "^GRUB_GFXPAYLOAD_LINUX=text" "${WINESAPOS_INSTALL_DIR}"/etc/default/grub; then
            echo PASS
        else
            winesapos_test_failure
        fi

        printf "\tChecking that GRUB is set to use winesapOS naming..."
        if grep -q -P "^GRUB_DISTRIBUTOR=winesapOS" "${WINESAPOS_INSTALL_DIR}"/etc/default/grub; then
            echo PASS
        else
            winesapos_test_failure
        fi

        if [[ "${WINESAPOS_BUILD_CHROOT_ONLY}" == "false" ]]; then
            printf "\tChecking that GRUB Btrfs snapshots are set to use winesapOS naming..."
            if grep -q -P "^GRUB_BTRFS_SUBMENUNAME=\"winesapOS snapshots\"" "${WINESAPOS_INSTALL_DIR}"/etc/default/grub-btrfs/config; then
                echo PASS
            else
                winesapos_test_failure
            fi
        fi

        WINESAPOS_CPU_MITIGATIONS="${WINESAPOS_CPU_MITIGATIONS:-false}"
        if [[ "${WINESAPOS_CPU_MITIGATIONS}" == "false" ]]; then
            printf "Testing that CPU mitigations are disabled in the Linux kernel..."
            if grep -q "mitigations=off" "${WINESAPOS_INSTALL_DIR}"/etc/default/grub; then
                echo PASS
            else
                winesapos_test_failure
            fi
        fi
    elif [[ "${WINESAPOS_BOOTLOADER}" == "systemd-boot" ]]; then
        printf " \tChecking that the generic '/boot/EFI/BOOT/BOOTX64.EFI' file exists..."
        if [ -f "${WINESAPOS_INSTALL_DIR}"/boot/EFI/BOOT/BOOTX64.EFI ]; then
            echo PASS
        else
            winesapos_test_failure
        fi
    fi
    echo "Testing the bootloader complete."
fi

echo "Testing that 'yay' is installed..."
printf "\tChecking for the 'yay' binary..."
if [ -f "${WINESAPOS_INSTALL_DIR}"/usr/bin/yay ]; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the 'yay' package is installed..."
pacman_search_loop yay
printf "\tChecking that the 'yay' package is installed complete."

echo "Testing that 'yay' is complete..."

echo "Testing desktop shortcuts..."
for i in \
  "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/appimagepool.desktop \
  "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/balenaEtcher.AppImage \
  "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/bauh.desktop \
  "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/blueman-manager.desktop \
  "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/firefox-esr.desktop \
  "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/terminator.desktop
    do printf "\t\tChecking if the file %s exists..." "${i}"
    if [ -f "${i}" ]; then
      echo PASS
    else
      winesapos_test_failure
    fi
done

if [[ "${WINESAPOS_INSTALL_GAMING_TOOLS}" == "true" ]]; then

    for i in \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/decky_installer.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/io.github.benjamimgois.goverlay.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/com.mtkennerly.ludusavi.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/com.nexusmods.app.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/NonSteamLaunchers.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/polychromatic.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/steam.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/steamtinkerlaunch.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/zerotier-gui.desktop
        do printf "\t\tChecking if the file %s exists..." "${i}"
        if [ -f "${i}" ]; then
          echo PASS
        else
          winesapos_test_failure
        fi
    done

fi

if [[ "${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS}" == "true" ]]; then
    for i in \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/clamtk.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/org.coolercontrol.CoolerControl.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/gparted.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/qdirstat.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/org.kde.spectacle.desktop \
      "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/Desktop/veracrypt.desktop
        do printf "\t\tChecking if the file %s exists..." "${i}"
        if [ -f "${i}" ]; then
          echo PASS
        else
          winesapos_test_failure
        fi
    done
fi

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    i="${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/Desktop/firewall-config.desktop"
    printf "\t\tChecking if the file %s exists..." "${i}"
    if [ -f "${i}" ]; then
        echo PASS
    else
        winesapos_test_failure
    fi
fi

if [[ "${WINESAPOS_DE}" == "cinnamon" ]]; then
    x=("${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/Desktop/nemo.desktop" "${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/Desktop/org.kde.pix.desktop")
elif [[ "${WINESAPOS_DE}" == "gnome" ]]; then
    x=("${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/Desktop/org.gnome.eog.desktop" "${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/Desktop/org.gnome.Nautilus.desktop")
elif [[ "${WINESAPOS_DE}" == "plasma" ]]; then
    x=("${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/Desktop/org.kde.dolphin.desktop" "${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/Desktop/org.kde.gwenview.desktop")
fi

for y in "${x[@]}";
    do printf "\t\tChecking if the file %s exists..." "${y}"
    if [ -f "${y}" ]; then
        echo PASS
    else
        winesapos_test_failure
    fi
done
echo "Testing desktop shortcuts complete."

printf "Testing that Oh My Zsh is installed..."
if [ -f "${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/.zshrc" ]; then
    echo PASS
else
    winesapos_test_failure
fi
echo "Testing that Oh My Zsh is installed complete."

printf "Testing that the mkinitcpio hooks are loaded in the correct order..."
if [[ "${WINESAPOS_ENCRYPT}" == "true" ]]; then
    grep -q "HOOKS=(base microcode udev block keyboard keymap modconf encrypt filesystems resume fsck)" "${WINESAPOS_INSTALL_DIR}"/etc/mkinitcpio.conf
    hooks_result="$?"
else
    grep -q "HOOKS=(base microcode udev block keyboard modconf filesystems resume fsck)" "${WINESAPOS_INSTALL_DIR}"/etc/mkinitcpio.conf
    hooks_result="$?"
fi
if [ "${hooks_result}" -eq 0 ]; then
     echo PASS
 else
     winesapos_test_failure
fi
echo "Testing that the mkinitcpio hooks are loaded in the correct order complete."

# Temporarily disable tests t
#echo "Testing that the Ventoy hook for mkinitcpio exists..."
#grep -P "^HOOKS=" "${WINESAPOS_INSTALL_DIR}"/etc/mkinitcpio.conf | grep -q ventoy
#if [ $? -eq 0 ]; then
#     echo PASS
# else
#     winesapos_test_failure
#fi

printf "Testing that ParallelDownloads is enabled in Pacman..."
if grep -q -P "^ParallelDownloads" "${WINESAPOS_INSTALL_DIR}"/etc/pacman.conf; then
    echo PASS
else
    winesapos_test_failure
fi
echo "Testing that ParallelDownloads is enabled in Pacman complete."

# Temporarily disable test that fails only in GitHub Actions.
# https://github.com/winesapOS/winesapOS/issues/970
#printf "Testing that Pacman is configured to use 'curl'..."
#grep -q 'XferCommand = /usr/bin/curl --connect-timeout 60 --retry 10 --retry-delay 5 -L -C - -f -o %o %u' "${WINESAPOS_INSTALL_DIR}"/etc/pacman.conf
#if [ $? -eq 0 ]; then
#    echo PASS
#else
#    winesapos_test_failure
#fi

echo "Testing that the machine-id was reset..."
printf "\t\tChecking that the /etc/machine-id file is empty..."
if [[ "$(cat "${WINESAPOS_INSTALL_DIR}"/etc/machine-id)" == "" ]]; then
    echo PASS
else
    winesapos_test_failure
fi
printf "\t\tChecking that /var/lib/dbus/machine-id is a symlink..."
if [[ -L "${WINESAPOS_INSTALL_DIR}"/var/lib/dbus/machine-id ]]; then
    echo PASS
else
    winesapos_test_failure
fi
echo "Testing that the machine-id was reset complete."

if [[ "${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS}" == "true" ]]; then
    echo "Testing that the offline ClamAV databases were downloaded..."
    for i in bytecode daily main; do
        printf "\t%s..." "${i}"
        if [[ -f "${WINESAPOS_INSTALL_DIR}"/var/lib/clamav/${i}.cvd ]]; then
            echo PASS
        else
            if [[ -f "${WINESAPOS_INSTALL_DIR}"/var/lib/clamav/${i}.cld ]]; then
                echo PASS
            else
                winesapos_test_failure
            fi
        fi
    done
    echo "Testing that the offline ClamAV databases were downloaded complete."
fi

if [[ "${WINESAPOS_FIREWALL}" == "true" ]]; then
    printf "Testing that the firewall has been installed..."
    if [[ -f "${WINESAPOS_INSTALL_DIR}"/usr/bin/firewalld ]]; then
        echo PASS
    else
        winesapos_test_failure
    fi
fi

WINESAPOS_DISABLE_KERNEL_UPDATES="${WINESAPOS_DISABLE_KERNEL_UPDATES:-true}"
if [[ "${WINESAPOS_DISABLE_KERNEL_UPDATES}" == "true" ]]; then
    printf "Testing that Pacman is configured to disable Linux kernel updates..."
    if [[ "${WINESAPOS_DISTRO}" == "manjaro" ]]; then
        if grep -q "IgnorePkg = linux66 linux66-headers linux-fsync-nobara-bin filesystem" "${WINESAPOS_INSTALL_DIR}"/etc/pacman.conf; then
            echo PASS
        else
            winesapos_test_failure
        fi
    elif [[ "${WINESAPOS_DISTRO}" == "arch" ]]; then
        if grep -q "IgnorePkg = linux-lts linux-lts-headers linux-fsync-nobara-bin filesystem" "${WINESAPOS_INSTALL_DIR}"/etc/pacman.conf; then
            echo PASS
        else
            winesapos_test_failure
        fi
    fi
fi

printf '\tChecking that the locale has been set...'
if chroot "${WINESAPOS_INSTALL_DIR}" locale --all-locales | grep -i "en_US.utf8"; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the hostname is set..."
if grep -q -P "^winesapos$" "${WINESAPOS_INSTALL_DIR}"/etc/hostname; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the hosts file is configured..."
if grep -q -P "^127.0.1.1    winesapos$" "${WINESAPOS_INSTALL_DIR}"/etc/hosts; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that all the packages from the AUR have been installed by yay..."
pacman_search_loop \
    appimagelauncher \
    appimagepool-appimage \
    auto-cpufreq \
    aw87559-firmware \
    ayaneo-platform-dkms-git \
    bauh \
    cloud-guest-utils \
    curl-static-bin \
    crudini \
    dtrx \
    firefox-esr \
    hfsprogs \
    mbpfan-git \
    oh-my-zsh-git \
    pacman-static \
    paru \
    python-iniparse-git \
    python-tests \
    rar \
    snapd

if [[ "${WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS}" == "true" ]]; then
    pacman_search_loop \
      clamav \
      distrobox \
      qdirstat
fi

if [[ "${WINESAPOS_DISTRO_DETECTED}" != "manjaro" ]]; then
    pacman_search_loop \
      zsh
else
    pacman_search_loop \
      zsh
fi

if [[ "${WINESAPOS_APPARMOR}" == "true" ]]; then
    pacman_search_loop \
      apparmor \
      krathalans-apparmor-profiles-git
fi
printf "\tChecking that all the packages from the AUR have been installed by yay done."

echo 'Testing that the PipeWire audio library is installed...'
printf "\tChecking that PipeWire packages are installed..."
pacman_search_loop \
  pavucontrol \
  libpipewire \
  lib32-libpipewire \
  pipewire-alsa \
  pipewire-jack \
  lib32-pipewire-jack \
  pipewire-pulse \
  pipewire-v4l2 \
  lib32-pipewire-v4l2 \
  wireplumber
printf "\tChecking that PipeWire packages are installed complete."

printf "\tChecking that PipeWire services are enabled..."
for i in \
  winesapos-mute.service \
  pipewire.service \
  pipewire-pulse.service
    do printf "\t%s..." "${i}"
    if ls "${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/.config/systemd/user/default.target.wants/${i}" &> /dev/null; then
        echo PASS
    else
        winesapos_test_failure
    fi
done
printf "\tChecking that PipeWire services are enabled complete."
echo 'Testing that the PipeWire audio library is installed complete.'

echo 'Testing that support for all file systems is installed...'
pacman_search_loop \
  apfsprogs-git \
  bcachefs-tools \
  btrfs-progs \
  ceph-bin \
  cifs-utils \
  dosfstools \
  e2fsprogs \
  ecryptfs-utils \
  erofs-utils \
  exfatprogs \
  f2fs-tools \
  fatx \
  gfs2-utils \
  glusterfs \
  hfsprogs \
  jfsutils \
  linux-apfs-rw-dkms-git \
  minio \
  mtools \
  nfs-utils \
  nilfs-utils \
  ntfs-3g \
  reiserfsprogs \
  reiserfs-defrag \
  squashfs-tools \
  ssdfs-tools \
  sshfs \
  udftools \
  xfsprogs \
  zfs-dkms \
  zfs-utils

printf "\tChecking the Snapper root configuration is configured to not take timeline snapshots..."
if grep -q -P "^TIMELINE_CREATE=\"no\"" "${WINESAPOS_INSTALL_DIR}"/etc/snapper/configs/root; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking the Snapper home configuration is configured to use the correct subvolume..."
if grep -q -P "^SUBVOLUME=\"/home\"" "${WINESAPOS_INSTALL_DIR}"/etc/snapper/configs/home; then
    echo PASS
else
    winesapos_test_failure
fi
echo 'Testing that support for all file systems is installed complete.'

printf "\tChecking that the correct operating system was installed..."
if grep -q "ID=${WINESAPOS_DISTRO}" "${WINESAPOS_INSTALL_DIR}"/usr/lib/os-release; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the OS variant has been set correctly..."
if grep -q -P "^VARIANT_ID=(minimal|performance|secure)" "${WINESAPOS_INSTALL_DIR}"/usr/lib/os-release-winesapos; then
    echo PASS
else
    winesapos_test_failure
fi

printf "\tChecking that the sudoers file for 'winesap' is correctly configured..."
if [[ "${WINESAPOS_SUDO_NO_PASSWORD}" == "true" ]]; then
    if grep -q "${WINESAPOS_USER_NAME} ALL=(root) NOPASSWD:ALL" "${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/${WINESAPOS_USER_NAME}"; then
        echo PASS
    else
        winesapos_test_failure
    fi
elif [[ "${WINESAPOS_SUDO_NO_PASSWORD}" == "false" ]]; then
    if grep -q "${WINESAPOS_USER_NAME} ALL=(root) ALL" "${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/${WINESAPOS_USER_NAME}"; then
        if grep -q "${WINESAPOS_USER_NAME} ALL=(root) NOPASSWD: /usr/bin/dmidecode" "${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/${WINESAPOS_USER_NAME}"; then
            echo PASS
        else
            winesapos_test_failure
        fi
    else
        winesapos_test_failure
    fi
fi

printf "\tChecking that the sudo timeout has been increased..."
if grep -q "Defaults:${WINESAPOS_USER_NAME} passwd_tries=20,timestamp_timeout=-1" "${WINESAPOS_INSTALL_DIR}/etc/sudoers.d/${WINESAPOS_USER_NAME}"; then
    echo PASS
else
    winesapos_test_failure
fi

echo "Testing that winesapOS desktop applications exist..."
for i in \
  /home/"${WINESAPOS_USER_NAME}"/.winesapos/winesapos-dual-boot.desktop \
  /home/"${WINESAPOS_USER_NAME}"/Desktop/winesapos-dual-boot.desktop \
  /usr/local/bin//winesapos-dual-boot.sh \
  /home/"${WINESAPOS_USER_NAME}"/.winesapos/winesapos-ngfn.desktop \
  /home/"${WINESAPOS_USER_NAME}"/.winesapos/winesapos-setup.sh \
  /home/"${WINESAPOS_USER_NAME}"/.winesapos/winesapos-setup.desktop \
  /home/"${WINESAPOS_USER_NAME}"/.winesapos/winesapos-xcloud.desktop \
  /home/"${WINESAPOS_USER_NAME}"/.config/autostart/winesapos-setup.desktop \
  /home/"${WINESAPOS_USER_NAME}"/Desktop/winesapos-setup.desktop \
  /home/"${WINESAPOS_USER_NAME}"/.winesapos/winesapos-upgrade-remote-stable.sh \
  /home/"${WINESAPOS_USER_NAME}"/.winesapos/winesapos-upgrade.desktop \
  /home/"${WINESAPOS_USER_NAME}"/Desktop/winesapos-upgrade.desktop \
  /home/"${WINESAPOS_USER_NAME}"/.winesapos/winesapos_logo_icon.png \
  /usr/share/sddm/faces/"${WINESAPOS_USER_NAME}".face.icon;
    do printf "\t%s..." "${i}"
    if ls "${WINESAPOS_INSTALL_DIR}${i}" &> /dev/null; then
        echo PASS
    else
        winesapos_test_failure
    fi
done
echo "Testing that winesapOS desktop applications exist complete."

if [[ "${WINESAPOS_ENABLE_KLIPPER}" == "false" ]]; then
    echo "Testing that Klipper has been disabled..."
    printf "\tChecking that Klipper settings are configured..."
    for i in "KeepClipboardContents = false" "MaxClipItems = 1" "PreventEmptyClipboard = false";
        do printf "\t%s..." "${i}"
        if grep -q -P "^${i}" "${WINESAPOS_INSTALL_DIR}"/home/"${WINESAPOS_USER_NAME}"/.config/klipperrc; then
            echo PASS
        else
            winesapos_test_failure
        fi
    done
    printf "\tChecking that the Klipper directory is mounted as a RAM file system..."
    if grep -q "ramfs    /home/${WINESAPOS_USER_NAME}/.local/share/klipper    ramfs    rw,nosuid,nodev    0 0" "${WINESAPOS_INSTALL_DIR}"/etc/fstab; then
        echo PASS
    else
        winesapos_test_failure
    fi
    echo "Testing that Klipper has been disabled complete."
fi

echo "Checking that the default text editor has been set..."
if grep -q "EDITOR=nano" "${WINESAPOS_INSTALL_DIR}"/etc/environment; then
    echo PASS
else
    winesapos_test_failure
fi
echo "Checking that the default text editor has been set complete."

printf "Checking that NetworkManager is using IWD as the backend..."
if grep -q "wifi.backend=iwd" "${WINESAPOS_INSTALL_DIR}"/etc/NetworkManager/conf.d/wifi_backend.conf; then
    echo PASS
else
    winesapos_test_failure
fi

printf "Checking that IPv4 network traffic is prioritized over IPv6..."
if grep -q "precedence ::ffff:0:0/96  100" "${WINESAPOS_INSTALL_DIR}"/etc/gai.conf; then
    echo PASS
else
    winesapos_test_failure
fi

echo "Checking that the ${WINESAPOS_USER_NAME} user name has been set in desktop shortcuts for the setup and upgrade..."
for i in winesapos-setup.desktop winesapos-upgrade.desktop;
    do printf "\t%s..." "${i}"
    if grep -q "/home/${WINESAPOS_USER_NAME}" "${WINESAPOS_INSTALL_DIR}/home/${WINESAPOS_USER_NAME}/.winesapos/${i}"; then
        echo PASS
    else
        winesapos_test_failure
    fi
done
echo "Checking that the ${WINESAPOS_USER_NAME} user name has been set in desktop shortcuts for the setup and upgrade done."

echo "Checking that the proprietary Broadcom Wi-Fi drivers are available for offline use..."
# shellcheck disable=SC2010
if ls -1 "${WINESAPOS_INSTALL_DIR}"/var/lib/winesapos/ | grep -q broadcom-wl-dkms; then
    echo PASS
else
    winesapos_test_failure
fi
echo "Checking that the proprietary Broadcom Wi-Fi drivers are available for offline use complete."

echo "Checking that a symlink was created for the 'deck' usesr for compatibility purposes..."
# shellcheck disable=SC2010
if ls -lah "${WINESAPOS_INSTALL_DIR}"/home/deck | grep -P "^lrwx"; then
    echo PASS
else
    winesapos_test_failure
fi
echo "Checking that a symlink was created for the 'deck' usesr for compatibility purposes complete."

printf "Checking that /snap is a symlink..."
if [[ -L "${WINESAPOS_INSTALL_DIR}"/snap ]]; then
    echo PASS
else
    winesapos_test_failure
fi

echo "Tests end time: $(date)"

if (( failed_tests == 0 )); then
    exit 0
else
    exit "${failed_tests}"
fi
