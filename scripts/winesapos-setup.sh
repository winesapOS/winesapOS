#!/bin/zsh

set -x

CMD_FLATPAK_INSTALL=(flatpak install -y --noninteractive)

kdialog --title "winesapOS First-Time Setup" --msgbox "The first-time setup requires an Internet connection to download the correct graphics drivers.\nSelect OK once connected."

os_detected=$(grep -P ^ID= /etc/os-release | cut -d= -f2)

if [ "${os_detected}" != "arch" ] && [ "${os_detected}" != "manjaro" ] && [ "${os_detected}" != "steamos" ]; then
    echo Unsupported operating system. Please use Arch Linux, Manjaro, or Steam OS 3.
    exit 1
fi

sudo pacman -S -y

graphics_selected=$(kdialog --menu "Select your desired graphics driver..." amd AMD intel Intel nvidia NVIDIA)
# Keep track of the selected graphics drivers for upgrade purposes.
echo ${graphics_selected} | sudo tee /etc/winesapos/graphics

if [[ "${graphics_selected}" == "amd" ]]; then
    sudo pacman -S --noconfirm \
      winesapos/mesa-steamos \
      winesapos/lib32-mesa-steamos \
      extra/xf86-video-amdgpu

    if [[ "${os_detected}" == "steamos" ]]; then
        sudo pacman -S --noconfirm \
          jupiter/vulkan-radeon \
          jupiter/lib32-vulkan-radeon \
          jupiter/libva-mesa-driver \
          jupiter/lib32-libva-mesa-driver \
          jupiter/mesa-vdpau \
          jupiter/lib32-mesa-vdpau \
          jupiter/opencl-mesa \
          jupiter/lib32-opencl-mesa
    else
        sudo pacman -S --noconfirm \
          extra/vulkan-radeon \
          multilib/lib32-vulkan-radeon \
          extra/libva-mesa-driver \
          multilib/lib32-libva-mesa-driver \
          extra/mesa-vdpau \
          multilib/lib32-mesa-vdpau \
          extra/opencl-mesa \
          multilib/lib32-opencl-mesa
    fi

elif [[ "${graphics_selected}" == "intel" ]]; then
    sudo pacman -S --noconfirm \
      winesapos/mesa-steamos \
      winesapos/lib32-mesa-steamos \
      extra/xf86-video-intel \
      community/intel-media-driver \
      community/intel-compute-runtime

    if [[ "${os_detected}" == "steamos" ]]; then
        sudo pacman -S --noconfirm \
          jupiter/vulkan-intel \
          jupiter/lib32-vulkan-intel
    else
        sudo pacman -S --noconfirm \
          extra/vulkan-intel \
          multilib/lib32-vulkan-intel
    fi

elif [[ "${graphics_selected}" == "nvidia" ]]; then
    sudo pacman -S --noconfirm \
      extra/nvidia-dkms \
      extra/nvidia-utils \
      multilib/lib32-nvidia-utils \
      extra/opencl-nvidia \
      multilib/lib32-opencl-nvidia
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

kdialog --title "Steam" --yesno "Do you want to install Steam?"
if [ $? -eq 0 ]; then
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
fi

kdialog --title "Google Chrome" --yesno "Do you want to install Google Chrome?"
if [ $? -eq 0 ]; then
    sudo ${CMD_FLATPAK_INSTALL} com.google.Chrome
    cp /var/lib/flatpak/app/com.google.Chrome/current/active/export/share/applications/com.google.Chrome.desktop /home/winesap/Desktop/
    sudo chown winesap.winesap /home/winesap/Desktop/google-chrome.desktop
    chmod +x /home/winesap/Desktop/google-chrome.desktop
fi

kdialog --title "System Upgrade" --yesno "Do you want to upgrade all system packages?\nThis may take a long time."
if [ $? -eq 0 ]; then
    yay -S -u --noconfirm
fi

# Delete the shortcut symlink so this will not auto-start again during the next login.
rm -f ~/.config/autostart/winesapos-setup.desktop

kdialog --msgbox "Please reboot to load new changes."
