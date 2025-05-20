#!/bin/bash

WINESAPOS_IMAGE_TYPE="$(grep VARIANT_ID /usr/lib/os-release-winesapos | cut -d = -f 2)"

# The secure image requires that the "sudo" password be provided for the "winesap" user.
# This password is also required to be reset during the first login so it is unknown.
# Prompt the user to enter in their password.
# On other image types, they do not require a password to run "sudo" commands so using
# the command "sudo -S" to read the password from standard input still works as expected.
if [[ "${WINESAPOS_IMAGE_TYPE}" == "secure" ]]; then
    while true;
        do user_pw=$(kdialog --title "winesapOS First-Time Setup" --password 'Please enter your password (default: "winesap") to start the first-time setup.')
        if echo "${user_pw}" | sudo -S whoami; then
            # Break out of the "while" loop if the password works with the "sudo -S" command.
            break 2
        fi
    done
fi

# Enable shell debugging.
set -x
START_TIME=$(date --iso-8601=seconds)
exec > >(sudo tee "/var/winesapos/setup_${START_TIME}.log") 2>&1
echo "Start time: ${START_TIME}"

current_shell=$(cat /proc/$$/comm)
if [[ "${current_shell}" != "bash" ]]; then
    echo "winesapOS scripts require Bash but ${current_shell} detected. Exiting..."
    exit 1
fi

CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_AUR_INSTALL=(yay --noconfirm -S --removemake)
CMD_FLATPAK_INSTALL=(flatpak install -y --noninteractive)

export WINESAPOS_USER_NAME="${USER}"

os_detected=$(grep -P ^ID= /etc/os-release | cut -d= -f2)

qdbus_cmd="qdbus6"

if [ "${os_detected}" != "arch" ] && [ "${os_detected}" != "manjaro" ]; then
    kdialog --title "winesapOS First-Time Setup" --msgbox "Unsupported operating system. Please use Arch Linux or Manjaro."
    exit 1
fi

if [[ "${WINESAPOS_IMAGE_TYPE}" == "secure" ]]; then
    echo "Allow passwordless 'sudo' for AUR packages installed via 'yay' to be done automatically..."
    sudo -E sh -c 'mv /etc/sudoers.d/${WINESAPOS_USER_NAME} /root/etc-sudoersd-${WINESAPOS_USER_NAME}; echo "${WINESAPOS_USER_NAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${WINESAPOS_USER_NAME}; chmod 0440 /etc/sudoers.d/${WINESAPOS_USER_NAME}'
    echo "Allow passwordless 'sudo' for AUR packages installed via 'yay' to be done automatically complete."
fi

# Enable Btrfs quotas for Snapper.
# Snapper does not work during the winesapOS build so this needs to happen during the first-time setup.
sudo snapper -c root setup-quota
sudo snapper -c home setup-quota
sudo btrfs qgroup limit 50G /.snapshots
sudo btrfs qgroup limit 50G /home/.snapshots

homebrew_install() {
    # Install dependencies.
    sudo "${CMD_PACMAN_INSTALL[@]}" base-devel procps-ng curl file git libxcrypt-compat
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # shellcheck disable=SC2016
    echo 'export PATH="${PATH}:/home/linuxbrew/.linuxbrew/bin"' >> ~/.bashrc
    # shellcheck disable=SC2016
    echo 'export PATH="${PATH}:/home/linuxbrew/.linuxbrew/bin"' >> ~/.zshrc
}

nix_install() {
    curl -L https://install.determinate.systems/nix | sudo sh -s -- install --no-confirm
    sudo systemctl enable --now nix-daemon
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    nix-channel --add https://nixos.org/channels/nixpkgs-unstable
    nix-channel --update
}

chrome_install() {
    if ! flatpak list | grep -q com.google.Chrome; then
        sudo "${CMD_FLATPAK_INSTALL[@]}" com.google.Chrome
    fi
    if [[ ! -f /home/"${USER}"/Desktop/com.google.Chrome.desktop ]]; then
        cp /var/lib/flatpak/app/com.google.Chrome/current/active/export/share/applications/com.google.Chrome.desktop /home/"${USER}"/Desktop/
        sed -i 's/Exec=/Exec=\/usr\/bin\/eatmydata\ /g' /home/"${USER}"/Desktop/com.google.Chrome.desktop
    fi
}

decky_loader_install() {
    # First install the 'zenity' dependency.
    sudo "${CMD_PACMAN_INSTALL[@]}" zenity
    curl --location --remote-name "https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/decky_installer.desktop" --output-dir /home/"${USER}"/Desktop/
    crudini --ini-options=nospace --set /home/"${USER}"/Desktop/decky_installer.desktop "Desktop Entry" Icon steam
}

export answer_install_ge="false"
proton_ge_install() {
    export answer_install_ge="true"
    mkdir -p /home/"${USER}"/.local/share/Steam/compatibilitytools.d/
    PROTON_GE_VERSION="GE-Proton9-27"
    curl https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_GE_VERSION}/${PROTON_GE_VERSION}.tar.gz --location --output /home/"${USER}"/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz
    tar -x -v -f /home/"${USER}"/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz --directory /home/"${USER}"/.local/share/Steam/compatibilitytools.d/
    rm -f /home/"${USER}"/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz
}

proton_sarek_install() {
    mkdir -p /home/"${USER}"/.local/share/Steam/compatibilitytools.d/
    PROTON_SAREK_VERSION="Proton-Sarek9-27"
    curl https://github.com/pythonlover02/Proton-Sarek/releases/download/${PROTON_SAREK_VERSION}/${PROTON_SAREK_VERSION}-async.tar.gz --location --output /home/"${USER}"/.local/share/Steam/compatibilitytools.d/${PROTON_SAREK_VERSION}-async.tar.gz
    tar -x -v -f /home/"${USER}"/.local/share/Steam/compatibilitytools.d/${PROTON_SAREK_VERSION}-async.tar.gz --directory /home/"${USER}"/.local/share/Steam/compatibilitytools.d/
    rm -f /home/"${USER}"/.local/share/Steam/compatibilitytools.d/${PROTON_SAREK_VERSION}-async.tar.gz
}

zerotier_install() {
    if [[ "${WINESAPOS_IMAGE_TYPE}" == "minimal" ]]; then
        sudo "${CMD_PACMAN_INSTALL[@]}" zerotier-one
        "${CMD_AUR_INSTALL[@]}" zerotier-gui-git
    fi
    # ZeroTier GUI will fail to launch with a false-positive error if the service is not running.
    sudo systemctl enable --now zerotier-one
}

xbox_controller_install() {
    # This package contains proprietary firmware that we cannot ship
    # which is why it is installed as part of the first-time setup.
    "${CMD_AUR_INSTALL[@]}" xone-dkms-git
    sudo touch /etc/modules-load.d/winesapos-controllers.conf
    echo -e "xone-wired\nxone-dongle\nxone-gip\nxone-gip-gamepad\nxone-gip-headset\nxone-gip-chatpad\nxone-gip-guitar" | sudo tee -a /etc/modules-load.d/winesapos-controllers.conf
    for i in xone-wired xone-dongle xone-gip xone-gip-gamepad xone-gip-headset xone-gip-chatpad xone-gip-guitar;
        do sudo modprobe --verbose ${i}
    done
    sudo git clone https://github.com/medusalix/xpad-noone /usr/src/xpad-noone-1.0
    # shellcheck disable=SC2010
    for kernel in $(ls -1 /usr/lib/modules/ | grep -P "^[0-9]+"); do
        sudo dkms install -m xpad-noone -v 1.0 -k "${kernel}"
    done
    echo -e "\nxpad-noone\n" | sudo tee -a /etc/modules-load.d/winesapos-controllers.conf
    echo -e "\nblacklist xpad\n" | sudo tee -a /etc/modprobe.d/winesapos-controllers.conf
    sudo rmmod xpad
    sudo modprobe xpad-noone
}

waydroid_install() {
    "${CMD_AUR_INSTALL[@]}" waydroid
    "${CMD_AUR_INSTALL[@]}" waydroid-image-gapps
}

broadcom_find_device() {
    export broadcom_network_device_found=0
    # Example output:
    # Bus 001 Device 003: ID 0a5c:bd1e Broadcom Corp. BCM43143 802.11bgn (1x1) Wireless Adapter
    if lsusb | grep -i -P "network|wireless" | grep -i -q broadcom; then
        export broadcom_network_device_found=1
    fi
    # Example output:
    # 03:00.0 Network controller: Broadcom Inc. and subsidiaries BCM4360 802.11ac Dual Band Wireless Network Adapter (rev 03)
    if lspci | grep -i -P "network|wireless" | grep -i -q broadcom; then
        export broadcom_network_device_found=1
    fi
}

# Only install Broadcom Wi-Fi drivers if (1) there is a Broadcom network adapter and (2) there is no Internet connection detected.
broadcom_wifi_auto() {
    broadcom_find_device
    if (( broadcom_network_device_found == 1 )); then
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Checking Internet connection..." 2 | cut -d" " -f1)
        test_internet_connection
        if [ $? -ne 1 ]; then
            "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog showCancelButton false
            "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
            kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Broadcom proprietary Wi-Fi drivers to be installed..." 3 | cut -d" " -f1)
            "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
            # Blacklist drives that are known to cause conflicts with the official Broadcom 'wl' driver.
            echo -e "\nblacklist b43\nblacklist b43legacy\nblacklist bcm43xx\nblacklist bcma\nblacklist brcm80211\nblacklist brcmsmac\nblacklist brcmfmac\nblacklist brcmutil\nblacklist ndiswrapper\nblacklist ssb\nblacklist tg3\n" | sudo tee /etc/modprobe.d/winesapos-broadcom-wifi.conf
            # shellcheck disable=SC2010
            broadcom_wl_dkms_pkg=$(ls -1 /var/lib/winesapos/ | grep broadcom-wl-dkms | grep -P "zst$")
            sudo pacman -U --noconfirm /var/lib/winesapos/"${broadcom_wl_dkms_pkg}"
            "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
            echo -e "broadcom\nwl" | sudo tee -a /etc/modules-load.d/winesapos-broadcom-wifi.conf
            sudo mkinitcpio -P
            "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
            kdialog --title "winesapOS First-Time Setup" --msgbox "Please reboot to load new changes."
        else
            "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog showCancelButton false
            "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
        fi
    fi
}

broadcom_wifi_ask() {
    broadcom_find_device
    if (( broadcom_network_device_found == 1 )); then
        if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to install the Broadcom proprietary network driver? Try this if network connections are not working. A reboot is required when done."; then
            broadcom_wifi_auto
        fi
    fi
}

test_internet_connection() {
    # Check with https://ping.archlinux.org/ to see if we have an Internet connection.
    # shellcheck disable=SC2046 disable=SC2126
    return $(curl -s https://ping.archlinux.org/ | grep "This domain is used for connectivity checking" | wc -l)
}

loop_test_internet_connection() {
    while true;
        do kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Checking Internet connection..." 2 | cut -d" " -f1)
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog showCancelButton false
        if ! test_internet_connection; then
            "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
            # Break out of the "while" loop if we have an Internet connection.
            break 2
        fi
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
        if ! kdialog --title "winesapOS First-Time Setup" \
                --yesno "A working Internet connection for setting up graphics drivers is not detected. \
                \nPlease connect to the Internet and try again, or select Cancel to quit Setup." \
                --yes-label "Retry" \
                --no-label "Cancel"; then
            # Exit the script if the user selects "Cancel".
            exit 1
        fi
    done
}

screen_rotate_ask() {
    if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to rotate the screen (for devices that have a tablet screen)?"; then
        rotation_selected=$(kdialog --title "winesapOS First-Time Setup" --menu "Select the desired screen orientation..." right "90 degrees right (clockwise)" left "90 degrees left (counter-clockwise)" inverted "180 degrees inverted (upside-down)")
        export fbcon_rotate=0
        if [[ "${rotation_selected}" == "right" ]]; then
            export fbcon_rotate=1
            sudo sed -i 's/GRUB_GFXMODE=.*/GRUB_GFXMODE=720x1280,auto/g' /etc/default/grub
        elif [[ "${rotation_selected}" == "left" ]]; then
            export fbcon_rotate=3
            sudo sed -i 's/GRUB_GFXMODE=.*/GRUB_GFXMODE=720x1280,auto/g' /etc/default/grub
        elif [[ "${rotation_selected}" == "inverted" ]]; then
            export fbcon_rotate=2
        fi
        # Rotate the TTY output.
        sudo -E sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"fbcon:rotate=${fbcon_rotate} /g" /etc/default/grub
        echo ${fbcon_rotate} | sudo tee /sys/class/graphics/fbcon/rotate_all
        export embedded_display_port
        # Example output: eDP-1
        embedded_display_port=$(kscreen-doctor -o | grep eDP | head -n 1 | awk '{print $3}')
        # Rotate the display. This is persistent across reboots.
        kscreen-doctor "output.${embedded_display_port}.rotation.${rotation_selected}"
    fi
}

asus_setup() {
    if sudo dmidecode -s system-manufacturer | grep -P "^ASUS"; then
        echo "ASUS computer detected."
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for ASUS utilities to be installed..." 1 | cut -d" " -f1)
        "${CMD_AUR_INSTALL[@]}" asusctl-git
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
    else
        echo "ASUS computer not detected."
    fi
}

framework_setup() {
    system_manufacturer=$(sudo dmidecode -s system-manufacturer)
    if [[ "${system_manufacturer}" == "Framework" ]]; then
        echo "Framework laptop detected."
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Framework drivers to be installed..." 8 | cut -d" " -f1)
        if lscpu | grep -q Intel; then
            # Enable better power management of NVMe devices on Intel Framework devices.
            sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvme.noacpi=1 /g' /etc/default/grub
        fi
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
        # Fix keyboard.
        echo "blacklist hid_sensor_hub" | sudo tee /etc/modprobe.d/winesapos-framework-als-deactivate.conf
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
        # Fix firmware updates.
        sudo mkdir /etc/fwupd/
        echo -e "[uefi_capsule]\nDisableCapsuleUpdateOnDisk=true" | sudo tee /etc/fwupd/uefi_capsule.conf
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
        # Enable support for the ambient light sensor.
        sudo "${CMD_PACMAN_INSTALL[@]}" iio-sensor-proxy
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4
        # Enable the ability to disable the touchpad while typing.
        sudo touch /usr/share/libinput/50-framework.quirks
        echo '[Framework Laptop 16 Keyboard Module]
MatchName=Framework Laptop 16 Keyboard Module*
MatchUdevType=keyboard
MatchDMIModalias=dmi:*svnFramework:pnLaptop16*
AttrKeyboardIntegration=internal' | sudo tee /usr/share/libinput/50-framework.quirks
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5
        # Enable a better audio profile for Framework Laptops.
        # https://github.com/cab404/framework-dsp
        sudo "${CMD_PACMAN_INSTALL[@]}" easyeffects
        TMP=$(mktemp -d) && \
        CFG=${XDG_CONFIG_HOME:-~/.config}/easyeffects && \
        mkdir -p "${CFG}" && \
        curl -Lo "${TMP}/fwdsp.zip https://github.com/cab404/framework-dsp/archive/refs/heads/master.zip" && \
        unzip -d "${TMP}" "$TMP"/fwdsp.zip 'framework-dsp-master/config/*/*' && \
        sed -i 's|%CFG%|'"$CFG"'|g' "${TMP}"/framework-dsp-master/config/*/*.json && \
        cp -rv "${TMP}"/framework-dsp-master/config/* "${CFG}" && \
        rm -rf "${TMP}"
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6
        # Automatically configure the correct region for the Wi-Fi device.
        COUNTRY_CODE="$(curl -s ipinfo.io | jq -r .country)"
        export COUNTRY_CODE
        ## Temporarily.
        sudo -E iw reg set "${COUNTRY_CODE}"
        ## Permanently.
        sudo "${CMD_PACMAN_INSTALL[@]}" wireless-regdb
        # shellcheck disable=SC2027 disable=SC2086
        echo "WIRELESS_REGDOM=\""${COUNTRY_CODE}"\"" | sudo tee -a /etc/conf.d/wireless-regdom
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7
        # Enable support for the LED matrix on the Framework Laptop 16.
        "${CMD_AUR_INSTALL[@]}" inputmodule-control
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
    else
        echo "Framework laptop not detected."
    fi
}

mac_setup() {
    echo "Turning on the Mac fan service if the hardware is Apple..."
    if sudo dmidecode -s system-product-name | grep -P ^Mac; then
        echo "Mac hardware detected."
        sudo systemctl enable --now mbpfan
        # Networking over USB does not work on T2 Macs.
        # https://wiki.t2linux.org/guides/postinstall/
        echo -e "blacklist cdc_ncm\nblacklist cdc_mbim\n" | sudo tee -a /etc/modprobe.d/winesapos-mac.conf
        # Enable audio workaround for T2 Macs.
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="efi=noruntime intel_iommu=on iommu=pt pcie_ports=compat /g' /etc/default/grub
    else
        echo "No Mac hardware detected."
    fi
    echo "Turning on the Mac fan service if the hardware is Apple complete."
}

steam_deck_setup() {
    if sudo dmidecode -s system-product-name | grep -P "^(Galileo|Jupiter)"; then
        # Configure S3 deep sleep.
        sudo sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="mem_sleep_default=deep /g' /etc/default/grub
    fi
}

surface_setup() {
    # https://github.com/linux-surface/linux-surface/wiki/Installation-and-Setup#arch
    system_family=$(sudo dmidecode -s system-family)
    if [[ "${system_family}" == "Surface" ]]; then
        echo "Microsoft Surface laptop detected."
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Microsoft Surface drivers to be installed..." 3 | cut -d" " -f1)
        # The recommended GPG key is no longer valid.
        # shellcheck disable=SC2016
        echo -e "\n[linux-surface]\nServer = https://pkg.surfacelinux.com/arch/\nSigLevel = Never" | sudo tee -a /etc/pacman.conf
        sudo pacman -S -y
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
        sudo "${CMD_PACMAN_INSTALL[@]}" iptsd
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
        sudo pacman -R -n --nodeps --nodeps --noconfirm libwacom
        # Install build dependencies for 'libwacom-surface' first.
        sudo "${CMD_PACMAN_INSTALL[@]}" meson ninja
        "${CMD_AUR_INSTALL[@]}" libwacom-surface
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
    else
        echo "Microsoft Surface laptop not detected."
    fi
}

winesapos_version_check() {
    winesapos_ver_latest="$(curl https://raw.githubusercontent.com/winesapOS/winesapOS/stable/rootfs/usr/lib/os-release-winesapos | grep VERSION_ID | cut -d = -f 2)"
    winesapos_ver_current="$(grep VERSION_ID /usr/lib/os-release-winesapos | cut -d = -f 2)"
    # 'sort -V' does not work with semantic numbers.
    # As a workaround, adding an underline to versions without a suffix allows the semantic sort to work.
    # shellcheck disable=SC2086
    if [[ $(echo -e "${winesapos_ver_latest}\n${winesapos_ver_current}" | sed '/-/!{s/$/_/}' | sort -V) == "$(echo -e ${winesapos_ver_latest}"\n"${winesapos_ver_current} | sed '/-/!{s/$/_/}')" ]]; then
        echo "No newer version found."
    else
        if ! kdialog --title "winesapOS First-Time Setup" --yesno "This is an older version of winesapOS. It is recommended to either download the latest image or run the winesapOS Upgrade on the desktop first. Do you want to continue the first-time setup?"; then
            exit 0
        fi
    fi
}

# Download the Steam bootstrap files in the background.
# This allows the Steam Gamescope Session to work on the next reboot.
steam_bootstrap() {
    if [[ -f /usr/bin/steam ]]; then
        tmux new-session -d -s steam 'xwfb-run --error-file /tmp/weston.log steam &> /tmp/steam.log'
    fi
}

# Only automatically handle the case for the Steam Deck.
screen_rotate_auto() {
    # "Jupiter" is the code name for the Steam Deck LCD.
    # "Galileo" is the code name for the Steam Deck OLED.
    if sudo dmidecode -s system-product-name | grep -P "^(Galileo|Jupiter)"; then
        echo "Steam Deck hardware detected."
        export embedded_display_port
        # Example output: eDP-1
        embedded_display_port=$(kscreen-doctor -o | grep eDP | head -n 1 | awk '{print $3}')
        # Rotate the display. This is persistent across reboots.
        kscreen-doctor "output.${embedded_display_port}.rotation.right"
        # Rotate GRUB.
        sudo sed -i 's/GRUB_GFXMODE=.*/GRUB_GFXMODE=720x1280,auto/g' /etc/default/grub
        # Rotate the initramfs output.
        sudo sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon:rotate=1 /g' /etc/default/grub
    fi
}

repo_mirrors_region_auto() {
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the setup to update the Pacman cache..." 2 | cut -d" " -f1)
    if [ "${os_detected}" = "arch" ]; then
        # shellcheck disable=SC2016
        echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist
        # shellcheck disable=SC2016
        echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' | sudo tee -a /etc/pacman.d/mirrorlist
    elif [[ "${os_detected}" == "manjaro" ]]; then
        sudo pacman-mirrors --geoip -f 5
    fi
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    sudo pacman -S -y
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
}

repo_mirrors_region_ask() {
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the setup to find package repository mirrors..." 1 | cut -d" " -f1)
    # Dialog to ask the user what mirror region they want to use
    if [ "${os_detected}" = "arch" ]; then
        # Fetch the list of regions from the Arch Linux mirror status JSON API.
        # Some regions contain a space. We need to map each newline into an array here.
        mapfile -t mirror_regions < <(curl -s https://archlinux.org/mirrors/status/json/ | jq -r '.urls[].country' | sort | uniq | sed '1d')
    elif [ "${os_detected}" = "manjaro" ]; then
        # Fetch the list of regions from the Manjaro mirror status JSON API.
        # Unlike Arch Linux, Manjaro uses underscores instead of spaces so the logic is cleaner.
        # shellcheck disable=SC2207
        mirror_regions=( $(curl -s https://repo.manjaro.org/status.json | jq -r '.[].country' | sort | uniq) )
    fi
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close

    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the setup to update the Pacman cache..." 2 | cut -d" " -f1)
    chosen_region=$(kdialog --title "winesapOS First-Time Setup" \
                            --combobox "Select your desired mirror region, \nor press Cancel to use default settings:" \
                            "${mirror_regions[@]}")

    if [ "${os_detected}" = "arch" ]; then
        # Check if the user selected a mirror region.
        if [ -n "${chosen_region}" ]; then
            # This seems like a better idea than writing global config we cannot reliably remove a line.
            sudo reflector --verbose --latest 10 --sort rate --threads 10 --save /etc/pacman.d/mirrorlist --country "${chosen_region}"
            # Ideally we should be sorting by `rate` for consistency but it may get too slow.
        else
            # Fallback to the Arch Linux and Rackspace global mirrors.
            # shellcheck disable=SC2016
            echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist
            # shellcheck disable=SC2016
            echo 'Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch' | sudo tee -a /etc/pacman.d/mirrorlist
        fi
    elif [[ "${os_detected}" == "manjaro" ]]; then
        if [ -n "${chosen_region}" ]; then
            sudo pacman-mirrors -c "${chosen_region}"
        else
            sudo pacman-mirrors -f 5
        fi
    fi
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    sudo pacman -S -y
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
}

graphics_drivers_auto() {
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the graphics driver to be installed..." 1 | cut -d" " -f1)
    echo mesa | sudo tee /var/winesapos/graphics

    # Enable GSP firmware support for older NVIDIA graphics cards.
    sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nouveau.config=NvGspRm=1 /g' /etc/default/grub
    # Enable experimental support for old graphics cards starting with Kepler.
    echo "NVK_I_WANT_A_BROKEN_VULKAN_DRIVER=1" | sudo tee -a /etc/environment

    # Here are all of the possible virtualization technologies that systemd can detect:
    # https://www.freedesktop.org/software/systemd/man/latest/systemd-detect-virt.html
    virtualization_detected="$(systemd-detect-virt)"
    # Oracle VM VirtualBox.
    if [[ "${virtualization_detected}" == "oracle" ]]; then
        sudo pacman -S --noconfirm virtualbox-guest-utils
        sudo systemctl enable --now vboxservice
        sudo usermod -a -G vboxsf winesap
    elif [[ "${virtualization_detected}" == "vmware" ]]; then
        sudo pacman -S --noconfirm \
          open-vm-tools \
          xf86-video-vmware \
          xf86-input-vmmouse \
          gtkmm3
        sudo systemctl enable --now \
          vmtoolsd \
          vmware-vmblock-fuse
    fi
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
}

graphics_drivers_ask() {
    graphics_selected=$(kdialog --title "winesapOS First-Time Setup" --menu "Select your desired graphics driver..." amd AMD intel Intel nvidia-open "NVIDIA Open (for DLSS, Turing and newer)" nvidia-mesa "NVIDIA Mesa (for portability, Kepler and newer)" virtualbox VirtualBox vmware VMware)
    # Keep track of the selected graphics drivers for upgrade purposes.
    echo "${graphics_selected}" | sudo tee /var/winesapos/graphics
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the graphics driver to be installed..." 2 | cut -d" " -f1)
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

    if [[ "${graphics_selected}" == "amd" ]]; then
        true
    elif [[ "${graphics_selected}" == "intel" ]]; then
        sudo pacman -S --noconfirm \
          extra/intel-media-driver \
          extra/intel-compute-runtime
    elif [[ "${graphics_selected}" == "nvidia-open" ]]; then
        sudo pacman -S --noconfirm \
          extra/nvidia-open-dkms \
          extra/nvidia-utils \
          multilib/lib32-nvidia-utils \
          extra/opencl-nvidia \
          multilib/lib32-opencl-nvidia

        # Enable Wayland support.
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia_drm.modeset=1 nvidia_drm.fbdev=1 /g' /etc/default/grub

        # Block the loading of conflicting open source NVIDIA drivers.
        sudo touch /etc/modprobe.d/winesapos-nvidia.conf
        echo "blacklist nova
blacklist nouveau
blacklist nvidiafb
blacklist nv
blacklist rivafb
blacklist rivatv
blacklist uvcvideo" | sudo tee /etc/modprobe.d/winesapos-nvidia.conf

        # Enable NVIDIA services to prevent crashes.
        # https://github.com/winesapOS/winesapOS/issues/837
        sudo systemctl enable nvidia-hibernate nvidia-persistenced nvidia-powerd nvidia-resume nvidia-suspend

        # Enable NVIDIA hibernation support.
        sudo mkdir /var/tmp-nvidia
        echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1
options nvidia NVreg_TemporaryFilePath=/var/tmp-nvidia" | sudo tee /etc/modprobe.d/winesapos-nvidia-hibernate.conf
    elif [[ "${graphics_selected}" == "nvidia-mesa" ]]; then
        # Enable GSP firmware support for older graphics cards.
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nouveau.config=NvGspRm=1 /g' /etc/default/grub

        # Enable experimental support for old NVIDIA graphics cards starting with Kepler.
        echo "NVK_I_WANT_A_BROKEN_VULKAN_DRIVER=1" | sudo tee -a /etc/environment

        # Block the loading of conflicting NVIDIA Open Kernel Module drivers.
        sudo touch /etc/modprobe.d/winesapos-nvidia.conf
        echo "blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
blacklist i2c_nvidia_gpu" | sudo tee /etc/modprobe.d/winesapos-nvidia.conf
    elif [[ "${graphics_selected}" == "virtualbox" ]]; then
        sudo pacman -S --noconfirm virtualbox-guest-utils
        sudo systemctl enable --now vboxservice
        sudo usermod -a -G vboxsf winesap
    elif [[ "${graphics_selected}" == "vmware" ]]; then
        sudo pacman -S --noconfirm \
          open-vm-tools \
          xf86-video-vmware \
          xf86-input-vmmouse \
          gtkmm3
        sudo systemctl enable --now \
          vmtoolsd \
          vmware-vmblock-fuse
    fi
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
}

swap_method_auto() {
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for zram to be enabled..." 1 | cut -d" " -f1)
    # Configure optimized zram settings based on our own research and testing.
    echo "vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 1" | sudo tee /etc/sysctl.d/99-vm-zram-parameters.conf
    echo "[zram0]
zram-size = ram * 2
compression-algorithm = lz4" | sudo tee /etc/systemd/zram-generator.conf
    sudo systemctl daemon-reload && sudo systemctl enable systemd-zram-setup@zram0.service
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
}

swap_method_ask() {
    swap_selected=$(kdialog --title "winesapOS First-Time Setup" --menu "Select your method for swap..." zram "zram (fast to create, does not enable hibernation, uses CPU)" swapfile "swapfile (slow to create, enables hibernation, uses I/O)" none "none")
    if [[ "${swap_selected}" == "zram" ]]; then
        swap_method_auto
    elif [[ "${swap_selected}" == "swapfile" ]]; then
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the swapfile to be enabled..." 1 | cut -d" " -f1)
        # shellcheck disable=SC1083 disable=SC2003 disable=SC2046
        swap_size_suggested="$(expr $(grep MemTotal /proc/meminfo  | awk {'print $2'}) / 1024 / 1024 + 1)"
        swap_size_selected=$(kdialog --title "winesapOS First-Time Setup" --inputbox "Swap size in GB. Set to RAM size or more for hibernation support." "${swap_size_suggested}")
        if echo "${swap_size_selected}" | grep -q -P "^[1-9]"; then
            echo "vm.swappiness=1" | sudo tee -a /etc/sysctl.d/00-winesapos.conf
            sudo touch /swap/swapfile
            # Avoid Btrfs copy-on-write.
            sudo chattr +C /swap/swapfile
            # Now fill in the swap file.
            sudo dd if=/dev/zero of=/swap/swapfile bs=1M count="${swap_size_selected}000"
            # A swap file requires strict permissions to work.
            sudo chmod 0600 /swap/swapfile
            sudo mkswap /swap/swapfile
            sudo swaplabel --label winesapos-swap /swap/swapfile
            sudo swapon /swap/swapfile
            echo "/swap/swapfile    none    swap    defaults    0 0" | sudo tee -a /etc/fstab
            # Enable hibernation support.
            sudo sed -i 's/fsck/resume fsck/g' /etc/mkinitcpio.conf
        fi
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
    fi
}

time_auto() {
    sudo touch /etc/localtime
    sudo tzupdate
}

locale_ask() {
    if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change the current locale (en_US.UTF-8 UTF-8)?"; then
        if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to see all availables locales in /etc/locale.gen?"; then
            kdialog --title "winesapOS First-Time Setup" --textbox /etc/locale.gen
        fi
        locale_selected=$(kdialog --title "winesapOS First-Time Setup" --inputbox "Locale for /etc/locale.gen:" "en_US.UTF-8 UTF-8")
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the locale to be setup..." 2 | cut -d" " -f1)
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
        echo "${locale_selected}" | sudo tee -a /etc/locale.gen
        sudo locale-gen
        sudo sed -i '/^LANG/d' /etc/locale.conf
        echo "LANG=$(echo "${locale_selected}" | cut -d' ' -f1)" | sudo tee -a /etc/locale.conf
        sed -i '/^LANG/d' /home/"${USER}"/.config/plasma-localerc
        echo "LANG=$(echo "${locale_selected}" | cut -d' ' -f1)" >> /home/"${USER}"/.config/plasma-localerc
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
    fi
}

time_ask() {
    if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change the current time zone (UTC)?"; then
        selected_time_zone=$(kdialog --title "winesapOS First-Time Setup" --combobox "Select the desired time zone:" "$(timedatectl list-timezones)")
        sudo timedatectl set-timezone "${selected_time_zone}"
    fi
}

productivity_auto() {
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for recommended productivity applications to be installed..." 17 | cut -d" " -f1)
    # Calibre for an ebook manager.
    sudo "${CMD_FLATPAK_INSTALL[@]}" com.calibre_ebook.calibre
    cp /var/lib/flatpak/app/com.calibre_ebook.calibre/current/active/export/share/applications/com.calibre_ebook.calibre.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    # Cheese for a webcam utility.
    sudo "${CMD_FLATPAK_INSTALL[@]}" org.gnome.Cheese
    cp /var/lib/flatpak/app/org.gnome.Cheese/current/active/export/share/applications/org.gnome.Cheese.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
    # ClamAV / ClamTk anti-virus.
    sudo "${CMD_PACMAN_INSTALL[@]}" clamav clamtk
    sudo freshclam
    cp /usr/share/applications/clamtk.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
    # CoolerControl for computer fan management.
    "${CMD_AUR_INSTALL[@]}" coolercontrol
    cp /usr/share/applications/org.coolercontrol.CoolerControl.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4
    # FileZilla for FTP file transfers.
    sudo "${CMD_FLATPAK_INSTALL[@]}" org.filezillaproject.Filezilla
    cp /var/lib/flatpak/exports/share/applications/org.filezillaproject.Filezilla.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5
    # Flatseal for managing Flatpaks.
    sudo "${CMD_FLATPAK_INSTALL[@]}" com.github.tchx84.Flatseal
    cp /var/lib/flatpak/app/com.github.tchx84.Flatseal/current/active/export/share/applications/com.github.tchx84.Flatseal.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6
    # Google Chrome web browser.
    chrome_install
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7
    # GParted for managing partitions.
    sudo "${CMD_PACMAN_INSTALL[@]}" gparted
    cp /usr/share/applications/gparted.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 8
    # Homebrew package manager.
    homebrew_install
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 9
    # KeePassXC for an encrypted password manager.
    sudo "${CMD_FLATPAK_INSTALL[@]}" org.keepassxc.KeePassXC
    cp /var/lib/flatpak/app/org.keepassxc.KeePassXC/current/active/export/share/applications/org.keepassxc.KeePassXC.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 10
    # LibreOffice for an office suite.
    sudo "${CMD_FLATPAK_INSTALL[@]}" org.libreoffice.LibreOffice
    cp /var/lib/flatpak/app/org.libreoffice.LibreOffice/current/active/export/share/applications/org.libreoffice.LibreOffice.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 11
    # Nix package manager.
    nix_install
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 12
    # PeaZip compression utility.
    sudo "${CMD_FLATPAK_INSTALL[@]}" io.github.peazip.PeaZip
    cp /var/lib/flatpak/app/io.github.peazip.PeaZip/current/active/export/share/applications/io.github.peazip.PeaZip.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 13
    # qBittorrent for torrents.
    sudo "${CMD_FLATPAK_INSTALL[@]}" org.qbittorrent.qBittorrent
    cp /var/lib/flatpak/app/org.qbittorrent.qBittorrent/current/active/export/share/applications/org.qbittorrent.qBittorrent.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 14
    # QDirStat for managing storage space.
    sudo "${CMD_AUR_INSTALL[@]}" qdirstat
    cp /usr/share/applications/qdirstat.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 15
    # VeraCrypt for managing encrypted storage.
    sudo "${CMD_PACMAN_INSTALL[@]}" veracrypt
    cp /usr/share/applications/veracrypt.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 16
    # VLC media player.
    sudo "${CMD_FLATPAK_INSTALL[@]}" org.videolan.VLC
    cp /var/lib/flatpak/app/org.videolan.VLC/current/active/export/share/applications/org.videolan.VLC.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
}

productivity_ask() {
    prodpkgs=$(kdialog --title "winesapOS First-Time Setup" --separate-output --checklist "Select productivity packages to install:" \
                       com.calibre_ebook.calibre:flatpak "Calibre (ebooks)" off \
                       org.gnome.Cheese:flatpak "Cheese (webcam)" off \
                       com.gitlab.davem.ClamTk:flatpak "ClamTk (anti-virus)" off \
                       coolercontrol:pkg "CoolerControl (fan control)" off \
                       org.filezillaproject.Filezilla:flatpak "FileZilla (FTP)" off \
                       com.github.tchx84.Flatseal:flatpak "Flatseal (Flatpak manager)" off \
                       com.google.Chrome "Google Chrome (web browser)" off \
                       gparted:pkg "GParted (partition manager)" off \
                       homebrew:other "Homebrew (package manager)" off \
                       org.keepassxc.KeePassXC:flatpak "KeePassXC (password manager)" off \
                       org.libreoffice.LibreOffice:flatpak "LibreOffice (office suite)" off \
                       nix:other "Nix (package manager)" off \
                       io.github.peazip.PeaZip:flatpak "PeaZip (compression)" off \
                       qdirstat:pkg "QDirStat (storage space analyzer)" off \
                       org.qbittorrent.qBittorrent:flatpak "qBittorrent (torrent)" off \
                       veracrypt:pkg "VeraCrypt (file encryption)" off \
                       org.videolan.VLC:flatpak "VLC (media player)" off)
    for prodpkg in ${prodpkgs}
        do kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for ${prodpkg} to be installed..." 2 | cut -d" " -f1)
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

        if echo "${prodpkg}" | grep -P ":flatpak$"; then
            sudo "${CMD_FLATPAK_INSTALL[@]}" "$(echo "${prodpkg}" | cut -d: -f1)"
        fi

        if echo "${prodpkg}" | grep -P ":pkg$"; then
            "${CMD_AUR_INSTALL[@]}" "$(echo "${prodpkg}" | cut -d: -f1)"
        fi

        if echo "${gamepkg}" | grep -P "^homebrew:other$"; then
            homebrew_install
        fi

        if echo "${gamepkg}" | grep -P "^nix:other$"; then
            nix_install
        fi

        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
    done
}

gaming_auto() {
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for recommended gaming applications to be installed..." 27 | cut -d" " -f1)
    # AntiMicroX for configuring controller input.
    sudo "${CMD_FLATPAK_INSTALL[@]}" io.github.antimicrox.antimicrox
    cp /var/lib/flatpak/app/io.github.antimicrox.antimicrox/current/active/export/share/applications/io.github.antimicrox.antimicrox.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    # Bottles for running any Windows game or application.
    sudo "${CMD_FLATPAK_INSTALL[@]}" com.usebottles.bottles
    cp /var/lib/flatpak/app/com.usebottles.bottles/current/active/export/share/applications/com.usebottles.bottles.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
    # CoreCtrl for overclocking and/or undervolting.
    sudo "${CMD_PACMAN_INSTALL[@]}" corectrl
    cp "${WINESAPOS_INSTALL_DIR}"/usr/share/applications/org.corectrl.CoreCtrl.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
    # Chiaki for PS4 and PS5 game streaming.
    sudo "${CMD_FLATPAK_INSTALL[@]}" io.github.streetpea.Chiaki4deck
    cp /var/lib/flatpak/app/io.github.streetpea.Chiaki4deck/current/active/export/share/applications/io.github.streetpea.Chiaki4deck.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4
    # Decky Loader.
    decky_loader_install
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5
    # Discord for social gaming.
    sudo "${CMD_FLATPAK_INSTALL[@]}" com.discordapp.Discord
    cp /var/lib/flatpak/app/com.discordapp.Discord/current/active/export/share/applications/com.discordapp.Discord.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6
    # Heroic Games Launcher.
    sudo "${CMD_FLATPAK_INSTALL[@]}" com.heroicgameslauncher.hgl
    cp /var/lib/flatpak/app/com.heroicgameslauncher.hgl/current/active/export/share/applications/com.heroicgameslauncher.hgl.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7
    # Ludusavi.
    "${CMD_AUR_INSTALL[@]}" ludusavi
    cp /usr/share/applications/com.mtkennerly.ludusavi.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 8
    # Lutris.
    sudo "${CMD_FLATPAK_INSTALL[@]}" net.lutris.Lutris
    cp /var/lib/flatpak/app/net.lutris.Lutris/current/active/export/share/applications/net.lutris.Lutris.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 9
    # MangoHud.
    "${CMD_AUR_INSTALL[@]}" mangohud-git lib32-mangohud-git
    # Flatpak's non-interactive mode does not work for MangoHud.
    # Instead, install a specific version of MangoHud.
    # https://github.com/winesapOS/winesapOS/issues/336
    sudo "${CMD_FLATPAK_INSTALL[@]}" runtime/org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/23.08
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 10
    # Moonlight and Sunshine.
    sudo "${CMD_FLATPAK_INSTALL[@]}" com.moonlight_stream.Moonlight dev.lizardbyte.app.Sunshine
    cp /var/lib/flatpak/app/com.moonlight_stream.Moonlight/current/active/export/share/applications/com.moonlight_stream.Moonlight.desktop /home/"${USER}"/Desktop/
    cp /var/lib/flatpak/app/dev.lizardbyte.app.Sunshine/current/active/export/share/applications/dev.lizardbyte.app.Sunshine.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 11
    # Nexus Mods app.
    "${CMD_AUR_INSTALL[@]}" nexusmods-app-bin
    cp /usr/share/applications/com.nexusmods.app.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 12
    # NonSteamLaunchers.
    curl --location --remote-name "https://raw.githubusercontent.com/moraroy/NonSteamLaunchers-On-Steam-Deck/refs/heads/main/NonSteamLaunchers.desktop" --output-dir /home/"${USER}"/Desktop/
    # NVIDIA GeForce Now.
    ## A dependency for NVIDIA GeForce Now and Xbox Cloud Gaming is Google Chrome.
    chrome_install
    ln -s /home/"${USER}"/.winesapos/winesapos-ngfn.desktop /home/"${USER}"/Desktop/winesapos-ngfn.desktop
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 13
    # Oversteer for managing racing wheels.
    sudo "${CMD_FLATPAK_INSTALL[@]}" io.github.berarma.Oversteer
    cp /var/lib/flatpak/app/io.github.berarma.Oversteer/current/active/export/share/applications/io.github.berarma.Oversteer.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 14
    # Playtron GameLAB.
    curl --location "https://api.playtron.one/api/v1/gamelab/download/linux_x64_appimage/latest" --output /home/"${USER}"/Desktop/GameLAB.AppImage
    chmod +x /home/"${USER}"/Desktop/GameLAB.AppImage
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 15
    # Prism Launcher for playing Minecraft.
    sudo "${CMD_FLATPAK_INSTALL[@]}" org.prismlauncher.PrismLauncher
    cp /var/lib/flatpak/app/org.prismlauncher.PrismLauncher/current/active/export/share/applications/org.prismlauncher.PrismLauncher.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 16
    # Proton-GE.
    proton_ge_install
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 17
    proton_sarek_install
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 18
    # Protontricks for managing dependencies in Proton.
    sudo "${CMD_FLATPAK_INSTALL[@]}" com.github.Matoking.protontricks
    ## Add a wrapper script so that the Flatpak can be used normally via the CLI.
    echo '#!/bin/bash
flatpak run com.github.Matoking.protontricks $@
' | sudo tee /usr/local/bin/protontricks
    sudo chmod +x /usr/local/bin/protontricks
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 19
    # ProtonUp-Qt for managing GE-Proton versions.
    sudo "${CMD_FLATPAK_INSTALL[@]}" net.davidotek.pupgui2
    cp /var/lib/flatpak/app/net.davidotek.pupgui2/current/active/export/share/applications/net.davidotek.pupgui2.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 20
    # OBS Studio for screen recording and live streaming.
    sudo "${CMD_FLATPAK_INSTALL[@]}" com.obsproject.Studio
    cp /var/lib/flatpak/app/com.obsproject.Studio/current/active/export/share/applications/com.obsproject.Studio.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 21
    # Open Gamepad UI.
    "${CMD_AUR_INSTALL[@]}" opengamepadui-bin opengamepadui-session-git
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 22
    # Steam.
    sudo "${CMD_PACMAN_INSTALL[@]}" steam steam-native-runtime
    cp /usr/share/applications/steam.desktop /home/"${USER}"/Desktop/
    steam_bootstrap
    "${CMD_AUR_INSTALL[@]}" gamescope-session-git gamescope-session-steam-git
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 23
    # umu-launcher.
    "${CMD_AUR_INSTALL[@]}" umu-launcher
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 24
    # Waydroid.
    waydroid_install
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 25
    # Xbox Cloud Gaming.
    ln -s /home/"${USER}"/.winesapos/winesapos-xcloud.desktop /home/"${USER}"/Desktop/winesapos-xcloud.desktop
    # Xbox controller drivers.
    xbox_controller_install
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 26
    # ZeroTier.
    zerotier_install
    cp /usr/share/applications/zerotier-gui.desktop /home/"${USER}"/Desktop/
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
}

gaming_ask() {
    gamepkgs=$(kdialog --title "winesapOS First-Time Setup" --separate-output --checklist "Select gaming packages to install:" \
                 io.github.antimicrox.antimicrox:flatpak "AntiMicroX" off \
                 com.usebottles.bottles:flatpak "Bottles" off \
                 corectrl:pkg "CoreCtrl (overclocking and/or undervolting)" off \
                 io.github.streetpea.Chiaki4deck:flatpak "Chiaki (PS4 and PS5 game streaming client)" off \
                 deckyloader:other "Decky Loader" off \
                 com.discordapp.Discord:flatpak "Discord" off \
                 emudeck:other "EmuDeck" off \
                 gamemode:pkg "GameMode (64-bit)" off \
                 lib32-gamemode:pkg "GameMode (32-bit)" off \
                 gamescope:other "Gamescope Session" off \
                 game-devices-udev:pkg "games-devices-udev (extra controller support)" off \
                 goverlay:pkg "GOverlay" off \
                 com.heroicgameslauncher.hgl:flatpak "Heroic Games Launcher" off \
                 ludusavi:pkg "Ludusavi" off \
                 net.lutris.Lutris:flatpak "Lutris" off \
                 mangohud-git:other "MangoHud" off \
                 com.moonlight_stream.Moonlight:flatpak "Moonlight (game streaming client)" off \
                 nexusmods-app-bin:pkg "Nexus Mods" off \
                 nonsteamlaunchers:other "NonSteamLaunchers" off \
                 ngfn:other "NVIDIA GeForce Now" off \
                 com.obsproject.Studio:flatpak "Open Broadcaster Software (OBS) Studio." off \
                 opengamepadui:other "Open Gamepad UI" off \
                 io.github.berarma.Oversteer:flatpak "Oversteer" off \
                 one.playtron.gamelab:other "Playtron GameLAB" off \
                 org.prismlauncher.PrismLauncher:flatpak "Prism Launcher" off \
                 proton-ge:other "Proton GE" off \
                 proton-sarek:other "Proton Sarek (for legacy graphcis cards)" off \
                 com.github.Matoking.protontricks:other "Protontricks" off \
                 net.davidotek.pupgui2:flatpak "ProtonUp-Qt" off \
                 steam:other "Steam" off \
                 dev.lizardbyte.app.Sunshine:flatpak "Sunshine (game streaming server)" off \
                 umu-launcher:pkg "umu-launcher" off \
                 waydroid:other "Waydroid (Android gaming)" off \
                 xcloud:other "Xbox Cloud Gaming" off \
                 xbox-controller-drivers:other "Xbox controller drivers" off \
                 zerotier-one:pkg "ZeroTier One VPN (CLI)" off \
                 zerotier-gui-git:pkg "ZeroTier One VPN (GUI)" off)
    for gamepkg in ${gamepkgs}
        do kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for ${gamepkg} to be installed..." 2 | cut -d" " -f1)
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

        if echo "${gamepkg}" | grep -P ":flatpak$"; then
            sudo "${CMD_FLATPAK_INSTALL[@]}" "$(echo "${gamepkg}" | cut -d: -f1)"
        fi

        if echo "${gamepkg}" | grep -P ":pkg$"; then
            "${CMD_AUR_INSTALL[@]}" "$(echo "${gamepkg}" | cut -d: -f1)"
        fi

        if echo "${gamepkg}" | grep -P "^deckyloader:other$"; then
            decky_loader_install
        fi

        if echo "${gamepkg}" | grep -P "^emudeck:other$"; then
            EMUDECK_GITHUB_URL="https://api.github.com/repos/EmuDeck/emudeck-electron/releases/latest"
            EMUDECK_URL="$(curl -s ${EMUDECK_GITHUB_URL} | grep -E 'browser_download_url.*AppImage' | cut -d '"' -f 4)"
            curl --location "${EMUDECK_URL}" --outupt /home/"${USER}"/Desktop/EmuDeck.AppImage
            chmod +x /home/"${USER}"/Desktop/EmuDeck.AppImage
        fi

        if echo "${gamepkg}" | grep -P "^gamescope:other$"; then
            sudo "${CMD_PACMAN_INSTALL[@]}" gamescope
            "${CMD_AUR_INSTALL[@]}" gamescope-session-git gamescope-session-steam-git
        fi

        if echo "${gamepkg}" | grep -P "^mangohud-git:other$"; then
            "${CMD_AUR_INSTALL[@]}" mangohud-git lib32-mangohud-git
            sudo "${CMD_FLATPAK_INSTALL[@]}" runtime/org.freedesktop.Platform.VulkanLayer.MangoHud/x86_64/23.08
        fi

        if echo "${gamepkg}" | grep -P "^nonsteamlaunchers:other$"; then
            curl --location --remote-name "https://raw.githubusercontent.com/moraroy/NonSteamLaunchers-On-Steam-Deck/refs/heads/main/NonSteamLaunchers.desktop" --output-dir /home/"${USER}"/Desktop/
        fi

        if echo "${gamepkg}" | grep -P "^ngfn:other$"; then
            chrome_install
            ln -s /home/"${USER}"/.winesapos/winesapos-ngfn.desktop /home/"${USER}"/Desktop/winesapos-ngfn.desktop
        fi

        if echo "${gamepkg}" | grep -P "^opengamepadui:other$"; then
            "${CMD_AUR_INSTALL[@]}" opengamepadui-bin opengamepadui-session-git
        fi

        if echo "${gamepkg}" | grep -P "^one.playtron.gamelab:other$"; then
            curl --location "https://api.playtron.one/api/v1/gamelab/download/linux_x64_appimage/latest" --output /home/"${USER}"/Desktop/GameLAB.AppImage
            chmod +x /home/"${USER}"/Desktop/GameLAB.AppImage
        fi

        if echo "${gamepkg}" | grep -P "^proton-ge:other$"; then
            proton_ge_install
        fi

        if echo "${gamepkg}" | grep -P "^proton-sarek:other$"; then
            proton_sarek_install
        fi

        if echo "${gamepkg}" | grep -P "^com.github.Matoking.protontricks:other$";  then
            sudo "${CMD_FLATPAK_INSTALL[@]}" com.github.Matoking.protontricks
            # Add a wrapper script so that the Flatpak can be used normally via the CLI.
            echo '#!/bin/bash
flatpak run com.github.Matoking.protontricks $@
' | sudo tee /usr/local/bin/protontricks
            sudo chmod +x /usr/local/bin/protontricks
        fi

        if echo "${gamepkg}" | grep -P "^steam:other$"; then
            sudo "${CMD_PACMAN_INSTALL[@]}" steam steam-native-runtime
            steam_bootstrap
        fi

        if echo "${gamepkg}" | grep -P "^waydroid:other$"; then
            waydroid_install
        fi

        if echo "${gamepkg}" | grep -P "^xcloud:other$"; then
            chrome_install
            ln -s /home/"${USER}"/.winesapos/winesapos-xcloud.desktop /home/"${USER}"/Desktop/winesapos-xcloud.desktop
        fi

        if echo "${gamepkg}" | grep -P "^xbox-controller-drivers:other$"; then
            chrome_install
            ln -s /home/"${USER}"/.winesapos/winesapos-xcloud.desktop /home/"${USER}"/Desktop/winesapos-xcloud.desktop
        fi
        "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
    done
}

user_password_auto() {
    # Disable debug logging as to not leak password in the log file.
    set +x
    winesap_password=$(kdialog --title "winesapOS First-Time Setup" --password "Enter your new user password:")
    echo "${USER}:${winesap_password}" | sudo chpasswd
    # Re-enable debug logging.
    set -x
}

user_password_ask() {
    if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change your password?"; then
        user_password_auto
    fi
}

root_password_auto() {
    set +x
    root_password=$(kdialog --title "winesapOS First-Time Setup" --password "Enter the new root password:")
    echo "root:${root_password}" | sudo chpasswd
    set -x
}

root_password_ask() {
    if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change the root password?"; then
        root_password_auto
    fi
}

luks_password_auto() {
    if [[ "${WINESAPOS_IMAGE_TYPE}" == "secure" ]]; then
        # Example output: "mmcblk0p5", "nvme0n1p5", "sda5"
        root_partition_shortname=$(lsblk -o name,label | grep winesapos-luks | awk '{print $1}' | grep -o -P '[a-z]+.*')
        set +x
        luks_password=$(kdialog --title "winesapOS First-Time Setup" --password "Enter the new LUKS storage encryption password:")
        echo -e "password\n${luks_password}\n${luks_password}\n" | sudo cryptsetup luksChangeKey /dev/"${root_partition_shortname}"
        set -x
    fi
}

luks_password_ask() {
    if [[ "${WINESAPOS_IMAGE_TYPE}" == "secure" ]]; then
        if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change the LUKS storage encryption password?"; then
            luks_password_auto
        fi
    fi
}

passwordless_login_remove() {
        for i in kde sddm; do
            sudo mv /etc/pam.d/"${i}" /etc/pam.d/"${i}"BAK
            grep -v "nopasswdlogin" /etc/pam.d/"${i}"BAK | sudo tee /etc/pam.d/"${i}"
            sudo rm -f /etc/pam.d/"${i}"BAK
        done
        sudo gpasswd --delete "${USER}" nopasswdlogin
        sudo groupdel nopasswdlogin
}

passwordless_login_auto() {
    if [[ "${WINESAPOS_IMAGE_TYPE}" == "secure" ]]; then
        passwordless_login_remove
    fi
}

passwordless_login_ask() {
    if ! kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to keep passwordless login enabled?"; then
        passwordless_login_remove
    fi
}

grub_hide_auto() {
    sudo crudini --ini-options=nospace --set /etc/default/grub "" GRUB_TIMEOUT 0
    sudo crudini --ini-options=nospace --set /etc/default/grub "" GRUB_TIMEOUT_STYLE hidden
}

grub_hide_ask() {
    if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to hide the GRUB boot menu?"; then
        grub_hide_auto
    fi
}

firmware_upgrade_auto() {
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for hardware firmware to be upgraded..." 2 | cut -d" " -f1)
    sudo fwupdmgr refresh --force
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    sudo fwupdmgr update --assume-yes --no-reboot-check
    "${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close
}

firmware_upgrade_ask() {
    if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to upgrade hardware firmware from LVFS with fwupdmgr?"; then
        firmware_upgrade_auto
    fi
}

if kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to use the recommended defaults for the first-time setup?"; then
    broadcom_wifi_auto
    loop_test_internet_connection
    winesapos_version_check
    repo_mirrors_region_auto
    steam_bootstrap
    screen_rotate_auto
    asus_setup
    framework_setup
    mac_setup
    steam_deck_setup
    surface_setup
    graphics_drivers_auto
    swap_method_auto
    # There is currently no way to auto detect the locale so skip it for now.
    time_auto
    productivity_auto
    gaming_auto
    luks_password_auto
    passwordless_login_auto
    grub_hide_auto
    firmware_upgrade_auto
    user_password_auto
    root_password_auto
    locale_ask
else
    broadcom_wifi_ask
    loop_test_internet_connection
    winesapos_version_check
    repo_mirrors_region_ask
    steam_bootstrap
    screen_rotate_ask
    asus_setup
    framework_setup
    mac_setup
    steam_deck_setup
    surface_setup
    graphics_drivers_ask
    swap_method_ask
    time_ask
    productivity_ask
    gaming_ask
    luks_password_ask
    passwordless_login_ask
    grub_hide_ask
    firmware_upgrade_ask
    user_password_ask
    root_password_ask
    locale_ask
fi

# Fix permissions.
sudo chown 1000:1000 /home/"${USER}"/Desktop/*.desktop
chmod +x /home/"${USER}"/Desktop/*.desktop

# Remove the Flatpak directory for the user to avoid errors.
# This directory will automatically get re-generated when a 'flatpak' command is ran.
# https://github.com/winesapOS/winesapOS/issues/516
rm -r -f /home/"${USER}"/.local/share/flatpak

kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the new drivers to be enabled on boot..." 2 | cut -d" " -f1)
"${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
# Regenerate the initramfs to load all of the new drivers.
sudo mkinitcpio -P
"${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close

# Regenerate the GRUB configuration to load the new Btrfs snapshots.
# This allows users to easily revert back to a fresh installation of winesapOS.
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Delete the shortcut symlink so this will not auto-start again during the next login.
rm -f ~/.config/autostart/winesapos-setup.desktop

echo "Running first-time setup tests..."
kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the first-time setup tests to finish..." 2 | cut -d" " -f1)

printf "\tChecking that Btrfs quotas are enabled..."
# There should be two entries for 50 GiB. One for root and one for home.
if [[ "$(sudo btrfs qgroup show -pcre / | grep -c 50.00GiB)" == "2" ]]; then
    echo PASS
else
    echo FAIL
fi
"${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

if [[ "${answer_install_ge}" == "true" ]]; then
    echo "Testing that GE Proton has been installed..."
    printf "\tChecking that GE Proton is installed..."
    # shellcheck disable=SC2010
    if ls -1 /home/"${USER}"/.local/share/Steam/compatibilitytools.d/ | grep -v -P ".tar.gz$" | grep -q -P "^GE-Proton.*"; then
        echo PASS
    else
        echo FAIL
    fi

    printf "\tChecking that the GE Proton tarball has been removed..."
    # shellcheck disable=SC2010
    if ! ls -1 /home/"${USER}"/.local/share/Steam/compatibilitytools.d/ | grep -q -P ".tar.gz$"; then
        echo PASS
    else
        echo FAIL
    fi
    echo "Testing that GE Proton has been installed complete."
fi

if sudo dmidecode -s system-product-name | grep -P "^(Galileo|Jupiter)"; then
    printf "\tChecking that GRUB enables S3 deep sleep support..."
    if sudo grep -q "mem_sleep_default=deep" /boot/grub/grub.cfg; then
        echo PASS
    else
        winesapos_test_failure
    fi
fi
echo "Running first-time setup tests complete."
"${qdbus_cmd}" "${kdialog_dbus}" /ProgressDialog org.kde.kdialog.ProgressDialog.close

if [[ "${WINESAPOS_IMAGE_TYPE}" == "secure" ]]; then
    echo "Disallow passwordless 'sudo' now that the setup is done..."
    sudo -E sh -c 'rm -f /etc/sudoers.d/${WINESAPOS_USER_NAME}; mv /root/etc-sudoersd-${WINESAPOS_USER_NAME} /etc/sudoers.d/${WINESAPOS_USER_NAME}'
    echo "Disallow passwordless 'sudo' now that the setup is done complete."
fi

kdialog --title "winesapOS First-Time Setup" --msgbox "Please reboot to load new changes."
echo "End time: $(date --iso-8601=seconds)"
