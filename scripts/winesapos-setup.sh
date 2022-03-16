#!/bin/zsh

set -x

os_detected=$(grep -P ^ID= /etc/os-release | cut -d= -f2)

if [ "${os_detected}" != "arch" ] && [ "${os_detected}" != "manjaro" ] && [ "${os_detected}" != "steamos" ]; then
    echo Unsupported operating system. Please use Arch Linux, Manjaro, or Steam OS 3.
    exit 1
fi

sudo pacman -S -y

echo "Installing required dependencies..."
sudo pacman -S --needed --noconfirm kdialog

graphics_selected=$(kdialog --menu "Select your desired graphics driver..." amd AMD intel Intel nvidia NVIDIA)

if [[ "${graphics_selected}" == "amd" ]]; then

    if [[ "${os_detected}" == "steamos" ]]; then
        sudo pacman -S --noconfirm \
          jupiter/mesa \
          jupiter/lib32-mesa \
          extra/xf86-video-amdgpu \
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
          extra/mesa \
          multilib/lib32-mesa \
          extra/xf86-video-amdgpu \
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
    # SteamOS does not ship Intel OpenGL drivers in Mesa so force the installation from Arch Linux repositories.
    sudo pacman -S --noconfirm \
      extra/mesa \
      multilib/lib32-mesa \
      extra/xf86-video-intel \
      extra/vulkan-intel \
      multilib/lib32-vulkan-intel \
      intel-media-driver \
      community/intel-compute-runtime
elif [[ "${graphics_selected}" == "nvidia" ]]; then
    sudo pacman -S --noconfirm \
      extra/nvidia-dkms \
      extra/nvidia-utils \
      multilib/lib32-nvidia-utils \
      extra/opencl-nvidia \
      multilib/lib32-opencl-nvidia
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

kdialog --title "System Upgrade" --yesno "Do you want to upgrade all system packages?\nThis may take a long time."
if [ $? -eq 0 ]; then
    yay -Su
fi

kdialog --msgbox "Please reboot to load new changes."
