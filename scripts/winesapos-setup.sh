#!/bin/zsh

# Enable shell debugging.
set -x
START_TIME=$(date --iso-8601=seconds)
exec > >(sudo tee /etc/winesapos/setup_${START_TIME}.log) 2>&1
echo "Start time: ${START_TIME}"

CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(sudo -u winesap yay --noconfirm -S --removemake)
CMD_FLATPAK_INSTALL=(flatpak install -y --noninteractive)

kdialog --title "winesapOS First-Time Setup" --msgbox "The first-time setup requires an Internet connection to download the correct graphics drivers.\nSelect OK once connected."

os_detected=$(grep -P ^ID= /etc/os-release | cut -d= -f2)

if [ "${os_detected}" != "arch" ] && [ "${os_detected}" != "manjaro" ] && [ "${os_detected}" != "steamos" ]; then
    echo Unsupported operating system. Please use Arch Linux, Manjaro, or Steam OS 3.
    exit 1
fi

echo "Ensuring that the Vapor theme is applied..."
lookandfeeltool --apply com.valve.vapor.desktop
echo "Ensuring that the Vapor theme is applied complete."

sudo pacman -S -y

kdialog --title "Rotate Screen" --yesno "Do you want to rotate the screen (for devices that have a tablet screen such as the Steam Deck, GPD Win Max, etc.)?"
if [ $? -eq 0 ]; then
    # Rotate GRUB.
    sudo sed -i s'/GRUB_GFXMODE=.*/GRUB_GFXMODE=720x1280,auto/'g /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    # Rotate the desktop temporarily.
    export embedded_display_port=$(xrandr | grep eDP | grep " connected" | cut -d" " -f1)
    xrandr --output ${embedded_display_port} --rotate right
    # Rotate the desktop permanently.
    sudo -E crudini --set /etc/lightdm/lightdm.conf SeatDefaults display-setup-script "xrandr --output ${embedded_display_port} --rotate right"
fi

graphics_selected=$(kdialog --menu "Select your desired graphics driver..." amd AMD intel Intel nvidia NVIDIA)
# Keep track of the selected graphics drivers for upgrade purposes.
echo ${graphics_selected} | sudo tee /etc/winesapos/graphics

if [[ "${graphics_selected}" == "amd" ]]; then
    sudo pacman -S --noconfirm \
      extra/xf86-video-amdgpu
elif [[ "${graphics_selected}" == "intel" ]]; then
    sudo pacman -S --noconfirm \
      extra/xf86-video-intel \
      community/intel-media-driver \
      community/intel-compute-runtime
elif [[ "${graphics_selected}" == "nvidia" ]]; then
    sudo pacman -S --noconfirm \
      extra/nvidia-dkms \
      extra/nvidia-utils \
      multilib/lib32-nvidia-utils \
      extra/opencl-nvidia \
      multilib/lib32-opencl-nvidia

    # Block the loading of conflicting open source NVIDIA drivers.
    sudo touch /etc/modprobe.d/winesapos-nvidia.conf
    echo "blacklist nouveau
blacklist nvidiafb
blacklist nv
blacklist rivafb
blacklist rivatv
blacklist uvcvideo" | sudo tee /etc/modprobe.d/winesapos-nvidia.conf
fi

kdialog --title "Swap" --yesno "Do you want to enable swap (recommended)?"
if [ $? -eq 0 ]; then
    swap_size_selected=$(kdialog --title "Swap" --inputbox "Swap size (GB):" "8")
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
fi

kdialog --title "Locale" --yesno "Do you want to change the current locale (en_US.UTF-8 UTF-8)?"
if [ $? -eq 0 ]; then
    kdialog --title "Locale" --yesno "Do you want to see all availables locales in /etc/locale.gen?"
    if [ $? -eq 0 ]; then
        kdialog --title /etc/locale.gen --textbox /etc/locale.gen
    fi

    locale_selected=$(kdialog --title "Select locale..." --inputbox "Locale for /etc/locale.gen:" "en_US.UTF-8 UTF-8")
    echo "${locale_selected}" | sudo tee -a /etc/locale.gen
    sudo locale-gen
    sudo sed -i '/^LANG/d' /etc/locale.conf
    echo "LANG=$(echo ${locale_selected} | cut -d' ' -f1)" | sudo tee -a /etc/locale.conf
    sed -i '/^LANG/d' /home/winesap/.config/plasma-localerc
    echo "LANG=$(echo ${locale_selected} | cut -d' ' -f1)" >> /home/winesap/.config/plasma-localerc
fi

kdialog --title "Locale" --yesno "Do you want to change the current time zone (UTC)?"
if [ $? -eq 0 ]; then
    selected_time_zone=$(kdialog --title "Time Zone" --combobox "Select the desired time zone:" $(timedatectl list-timezones))
    sudo timedatectl set-timezone ${selected_time_zone}
fi

answer_install_steam="false"
kdialog --title "Steam" --yesno "Do you want to install Steam?"
if [ $? -eq 0 ]; then
    answer_install_steam="true"
    winesapos_distro_autodetect=$(grep -P "^ID=" /etc/os-release | cut -d= -f2)
    if [[ "${winesapos_distro_autodetect}" == "manjaro" ]]; then
        sudo pacman -S --noconfirm steam-manjaro steam-native
    else
        sudo pacman -S --noconfirm  steam steam-native-runtime
    fi

    # Enable the Steam Deck client beta.
    mkdir -p /home/winesap/.local/share/Steam/package/
    echo "steampal_stable_9a24a2bf68596b860cb6710d9ea307a76c29a04d" > /home/winesap/.local/share/Steam/package/beta
    cp /usr/share/applications/steam.desktop /home/winesap/Desktop/steam_runtime.desktop
    crudini --set /home/winesap/Desktop/steam_runtime.desktop "Desktop Entry" Name "Steam Desktop"
    cp /usr/share/applications/steam.desktop /home/winesap/Desktop/steam_deck_runtime.desktop
    sed -i s'/Exec=\/usr\/bin\/steam\-runtime\ \%U/Exec=\/usr\/bin\/steam-runtime\ -gamepadui\ \%U/'g /home/winesap/Desktop/steam_deck_runtime.desktop
    crudini --set /home/winesap/Desktop/steam_deck_runtime.desktop "Desktop Entry" Name "Steam Deck"
    chmod +x /home/winesap/Desktop/steam*.desktop

    # GE Proton for Steam.
    mkdir -p /home/winesap/.local/share/Steam/compatibilitytools.d/
    PROTON_GE_VERSION="GE-Proton7-24"
    curl https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_GE_VERSION}/${PROTON_GE_VERSION}.tar.gz --location --output /home/winesap/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz
    tar -x -v -f /home/winesap/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz --directory /home/winesap/.local/share/Steam/compatibilitytools.d/
    rm -f /home/winesap/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz
    chown -R 1000.1000 /home/winesap
fi

kdialog --title "Google Chrome" --yesno "Do you want to install Google Chrome?"
if [ $? -eq 0 ]; then
    sudo ${CMD_FLATPAK_INSTALL} com.google.Chrome
    cp /var/lib/flatpak/app/com.google.Chrome/current/active/export/share/applications/com.google.Chrome.desktop /home/winesap/Desktop/
    sudo chown winesap.winesap /home/winesap/Desktop/google-chrome.desktop
    chmod +x /home/winesap/Desktop/google-chrome.desktop
fi

# This package contains proprietary firmware that we cannot ship
# which is why it is installed as part of the first-time setup.
kdialog --title "Xbox Controllers" --yesno "Do you want to install Xbox controller support?"
if [ $? -eq 0 ]; then
    if [[ "${os_detected}" == "steamos" ]]; then
        sudo ${CMD_PACMAN_INSTALL} holo/xone-dkms-git
    else
        ${CMD_YAY_INSTALL} xone-dkms-git
    fi
    sudo touch /etc/modules-load.d/winesapos-controllers.conf
    echo -e "xone-wired\nxone-dongle\nxone-gip\nxone-gip-gamepad\nxone-gip-headset\nxone-gip-chatpad\nxone-gip-guitar" | sudo tee /etc/modules-load.d/winesapos-controllers.conf
    for i in xone-wired xone-dongle xone-gip xone-gip-gamepad xone-gip-headset xone-gip-chatpad xone-gip-guitar;
        do sudo modprobe --verbose ${i}
    done
fi

# Regenerate the GRUB configuration to load the new Btrfs snapshots.
# This allows users to easily revert back to a fresh installation of winesapOS.
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Delete the shortcut symlink so this will not auto-start again during the next login.
rm -f ~/.config/autostart/winesapos-setup.desktop

echo "Running first-time setup tests..."
if [[ "${answer_install_steam}" == "true" ]]; then
    echo "Testing that GE Proton has been installed..."
    echo -n "\tChecking that GE Proton is installed..."
    ls -1 /home/winesap/.local/share/Steam/compatibilitytools.d/ | grep -v -P ".tar.gz$" | grep -q -P "^GE-Proton.*"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi

    echo -n "\tChecking that the GE Proton tarball has been removed..."
    ls -1 /home/winesap/.local/share/Steam/compatibilitytools.d/ | grep -q -P ".tar.gz$"
    if [ $? -eq 1 ]; then
        echo PASS
    else
        echo FAIL
    fi
    echo "Testing that GE Proton has been installed complete."
fi
echo "Running first-time setup tests complete."

kdialog --msgbox "Please reboot to load new changes."
echo "End time: $(date --iso-8601=seconds)"
