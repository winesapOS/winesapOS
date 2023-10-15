#!/bin/zsh

# The secure image requires that the "sudo" password be provided for the "winesap" user.
# This password is also required to be reset during the first login so it is unknown.
# Prompt the user to enter in their password.
# On other image types, they do not require a password to run "sudo" commands so using
# the command "sudo -S" to read the password from standard input still works as expected.
while true;
    do user_pw=$(kdialog --title "winesapOS First-Time Setup" --password 'Please enter your password (default: "winesap") to start the first-time setup.')
    echo ${user_pw} | sudo -S whoami
    if [ $? -eq 0 ]; then
        # Break out of the "while" loop if the password works with the "sudo -S" command.
        break 2
    fi
done

# Enable shell debugging.
set -x
START_TIME=$(date --iso-8601=seconds)
exec > >(sudo tee /etc/winesapos/setup_${START_TIME}.log) 2>&1
echo "Start time: ${START_TIME}"

CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(yay --noconfirm -S --removemake)
CMD_FLATPAK_INSTALL=(flatpak install -y --noninteractive)

pacman -Q broadcom-wl-dkms
if [ $? -ne 0 ]; then
    kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to install the Broadcom proprietary Wi-Fi driver? Try this if Wi-Fi is not working. A reboot is required when done."
    if [ $? -eq 0 ]; then
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Broadcom proprietary Wi-Fi drivers to be installed..." 3 | cut -d" " -f1)
        qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
        # Blacklist drives that are known to cause conflicts with the official Broadcom 'wl' driver.
        echo -e "\nblacklist b43\nblacklist b43legacy\nblacklist bcm43xx\nblacklist bcma\nblacklist brcm80211\nblacklist brcmsmac\nblacklist brcmfmac\nblacklist brcmutil\nblacklist ndiswrapper\nblacklist ssb\nblacklist tg3\n" | sudo tee /etc/modprobe.d/winesapos.conf
        broadcom_wl_dkms_pkg=$(ls -1 /var/lib/winesapos/ | grep broadcom-wl-dkms | grep -P "zst$")
        sudo pacman -U --noconfirm /var/lib/winesapos/${broadcom_wl_dkms_pkg}
        qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
        echo "wl" | sudo tee -a /etc/modules-load.d/winesapos-wifi.conf
        sudo mkinitcpio -P
        qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
    fi
fi

test_internet_connection() {
    # Check with https://ping.archlinux.org/ to see if we have an Internet connection.
    return $(curl -s https://ping.archlinux.org/ | grep "This domain is used for connectivity checking" | wc -l)
}

while true;
    do test_internet_connection
    if [ $? -eq 1 ]; then
        # Break out of the "while" loop if we have an Internet connection.
        break 2
    fi
    kdialog --title "winesapOS First-Time Setup" \
            --yesno "A working Internet connection for setting up graphics drivers is not detected. \
            \nPlease connect to the Internet and try again, or select Cancel to quit Setup." \
            --yes-label "Retry" \
            --no-label "Cancel"
    if [ $? -eq 1 ]; then
        # Exit the script if the user selects "Cancel".
        exit 1
    fi
done

os_detected=$(grep -P ^ID= /etc/os-release | cut -d= -f2)

if [ "${os_detected}" != "arch" ] && [ "${os_detected}" != "manjaro" ] && [ "${os_detected}" != "steamos" ]; then
    echo Unsupported operating system. Please use Arch Linux, Manjaro, or Steam OS 3.
    exit 1
fi

echo "Ensuring that the Vapor theme is applied..."
lookandfeeltool --apply com.valve.vapor.desktop
echo "Ensuring that the Vapor theme is applied complete."

echo "Turning on the Mac fan service if the hardware is Apple..."
sudo dmidecode -s system-product-name | grep -P ^Mac
if [ $? -eq 0 ]; then
    echo "Mac hardware detected."
    sudo systemctl enable --now mbpfan touchbard
    # Networking over USB does not work on T2 Macs.
    # https://wiki.t2linux.org/guides/postinstall/
    echo -e "blacklist cdc_ncm\nblacklist cdc_mbim\n" | sudo tee -a /etc/modprobe.d/winesapos-mac.conf
else
    echo "No Mac hardware detected."
fi
echo "Turning on the Mac fan service if the hardware is Apple complete."

# Dialog to ask the user what mirror region they want to use
if [ "${os_detected}" = "arch" ] || [ "${os_detected}" = "steamos" ]; then
    # Fetch the list of regions from the Arch Linux mirror status JSON API
    mirror_regions=("${(@f)$(curl -s https://archlinux.org/mirrors/status/json/ | jq -r '.urls[].country' | sort | uniq | sed '1d')}")
fi 

if [ "${os_detected}" = "manjaro" ]; then
    # Fetch the list of regions from the Manjaro mirror status JSON API
    mirror_regions=("${(@f)$(curl -s https://repo.manjaro.org/status.json | jq -r '.[].country' | sort | uniq)}")
fi

kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the setup to update the Pacman cache..." 3 | cut -d" " -f1)
chosen_region=$(kdialog --title "winesapOS First-Time Setup" \
                        --combobox "Select your desired mirror region, \nor press Cancel to use default settings:" \
                        "${mirror_regions[@]}")

qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

if [ "${os_detected}" = "arch" ] || [ "${os_detected}" = "steamos" ]; then
    # Check if the user selected a mirror region.
    if [ -n "${chosen_region}" ]; then 
        # this seems like a better idea than writing global config we can't reliably remove a line
        sudo reflector --verbose --latest 10 --sort age --save /etc/pacman.d/mirrorlist --country "${chosen_region}"
        # ideally we should be sorting by `rate` for consistency but it may get too slow
    else
        # Fallback to the Arch global mirror
        echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist
    fi
fi

if [[ "${os_detected}" == "manjaro" ]]; then
    if [ -n "${chosen_region}" ]; then
        sudo pacman-mirrors -c "${chosen_region}"
    else
        sudo pacman-mirrors -f 5
    fi
fi

# We're in control now so no need for sleep()
qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

sudo pacman -S -y
qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

system_manufacturer=$(sudo dmidecode -s system-manufacturer)
if [[ "${system_manufacturer}" == "Framework" ]]; then
    echo "Framework laptop detected."
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Framework drivers to be installed..." 4 | cut -d" " -f1)
    # Fix right-click.
    XINPUT_ID=$(xinput | grep Touchpad | awk '{print $6}' | cut -d= -f2)
    xinput set-prop "${XINPUT_ID}" "libinput Click Method Enabled" 0 1
    # Enable this workaround to always run when logging into the desktop environment.
    cat << EOF > /home/${USER}/.config/autostart/winesapos-framework-laptop-touchpad.desktop
[Desktop Entry]
Exec=/bin/xinput set-prop "$(xinput | grep Touchpad | awk '{print $6}' | cut -d= -f2)" "libinput Click Method Enabled" 0 1'
Name=Framework Laptop Touchpad
Comment=Configure the double-click functionality to work on the Framework laptop
Encoding=UTF-8
Icon=/home/${USER}/.winesapos/winesapos_logo_icon.png
Terminal=false
Type=Application
Categories=Application
EOF
    chmod +x /home/${USER}/.config/autostart/winesapos-framework-laptop-touchpad.desktop
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    # Enable deep sleep.
    sudo sed -i s'/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="mem_sleep_default=deep nvme.noacpi=1 /'g /etc/default/grub
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
    # Fix keyboard.
    echo "blacklist hid_sensor_hub" | sudo tee /etc/modprobe.d/framework-als-deactivate.conf
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
    # Fix firmware updates.
    echo "DisableCapsuleUpdateOnDisk=true" | sudo tee /etc/fwupd/uefi_capsule.conf
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
else
    echo "Framework laptop not detected."
fi

# https://github.com/linux-surface/linux-surface/wiki/Installation-and-Setup#arch
system_family=$(sudo dmidecode -s system-family)
if [[ "${system_family}" == "Surface" ]]; then
    echo "Microsoft Surface laptop detected."
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Microsoft Surface drivers to be installed..." 3 | cut -d" " -f1)
    # The recommended GPG key is no longer valid.
    echo -e "\n[linux-surface]\nServer = https://pkg.surfacelinux.com/arch/\nSigLevel = Never" | sudo tee -a /etc/pacman.conf
    sudo pacman -S -y
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

    sudo ${CMD_PACMAN_INSTALL} linux-surface linux-surface-headers iptsd linux-firmware-marvell
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2

    sudo pacman -R -n --nodeps --nodeps --noconfirm libwacom
    # Install build dependencies for 'libwacom-surface' first.
    sudo ${CMD_PACMAN_INSTALL} meson
    ${CMD_YAY_INSTALL} python-ninja
    ${CMD_YAY_INSTALL} libwacom-surface
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
else
    echo "Microsoft Surface laptop not detected."
fi

# "Jupiter" is the code name for the Steam Deck.
sudo dmidecode -s system-product-name | grep -P ^Jupiter
if [ $? -eq 0 ]; then
    echo "Steam Deck hardware detected."
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Steam Deck drivers to be configured..." 3 | cut -d" " -f1)
    # Rotate the desktop temporarily.
    export embedded_display_port=$(xrandr | grep eDP | grep " connected" | cut -d" " -f1)
    xrandr --output ${embedded_display_port} --rotate right
    # Rotate the desktop permanently.
    sudo -E crudini --set /etc/lightdm/lightdm.conf SeatDefaults display-setup-script "xrandr --output ${embedded_display_port} --rotate right"
    # Rotate GRUB.
    sudo sed -i s'/GRUB_GFXMODE=.*/GRUB_GFXMODE=720x1280,auto/'g /etc/default/grub
    # Rotate the initramfs output.
    sudo sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon:rotate=1 /'g /etc/default/grub
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    # As of Linux 6.3, the Steam Deck controller is natively supported.
    sudo ${CMD_PACMAN_INSTALL} linux linux-headers
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
    ${CMD_YAY_INSTALL} opensd-git
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
else
    echo "No Steam Deck hardware detected."
    kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to rotate the screen (for devices that have a tablet screen such as AYANEO, GPD Win, etc.)?"
    if [ $? -eq 0 ]; then
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the screen to rotate..." 2 | cut -d" " -f1)
        qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
        # Rotate the desktop temporarily.
        export embedded_display_port=$(xrandr | grep eDP | grep " connected" | cut -d" " -f1)
        xrandr --output ${embedded_display_port} --rotate right
        # Rotate the desktop permanently.
        sudo -E crudini --set /etc/lightdm/lightdm.conf SeatDefaults display-setup-script "xrandr --output ${embedded_display_port} --rotate right"
        # Rotate GRUB.
        sudo sed -i s'/GRUB_GFXMODE=.*/GRUB_GFXMODE=720x1280,auto/'g /etc/default/grub
        # Rotate the initramfs output.
        sudo sed -i s'/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fbcon:rotate=1 /'g /etc/default/grub
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
    fi
fi

grep -q SteamOS /etc/os-release
if [ $? -ne 0 ]; then
    kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to install SteamOS packages (linux-steamos, mesa-steamos, and SteamOS repositories)?"
    if [ $? -eq 0 ]; then
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for SteamOS packages to be configured..." 2 | cut -d" " -f1)
        sudo crudini --set /etc/pacman.conf jupiter-rel Server 'https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch'
        sudo crudini --set /etc/pacman.conf jupiter-rel SigLevel Never
        sudo crudini --set /etc/pacman.conf holo-rel Server 'https://steamdeck-packages.steamos.cloud/archlinux-mirror/$repo/os/$arch'
        sudo crudini --set /etc/pacman.conf holo-rel SigLevel Never
        sudo pacman -S -y -y

        # Remove conflicting packages first.
        sudo pacman -R -n -s --noconfirm libva-mesa-driver mesa-vdpau opencl-mesa lib32-libva-mesa-driver lib32-mesa-vdpau lib32-opencl-mesa
        # Install without '--noconfirm' to get prompts if we want to replace resolved conflicts.
        yes | sudo pacman -S --needed \
          mesa-steamos \
          libva-mesa-driver-steamos \
          mesa-vdpau-steamos \
          opencl-mesa-steamos \
          vulkan-intel-steamos \
          vulkan-mesa-layers-steamos \
          vulkan-radeon-steamos \
          vulkan-swrast-steamos \
          lib32-mesa-steamos \
          lib32-libva-mesa-driver-steamos \
          lib32-mesa-vdpau-steamos \
          lib32-opencl-mesa-steamos \
          lib32-vulkan-intel-steamos \
          lib32-vulkan-mesa-layers-steamos \
          lib32-vulkan-radeon-steamos \
          lib32-vulkan-swrast-steamos
        qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

        sudo ${CMD_PACMAN_INSTALL} linux-steamos linux-steamos-headers
        qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
    fi
fi

graphics_selected=$(kdialog --title "winesapOS First-Time Setup" --menu "Select your desired graphics driver..." amd AMD intel Intel nvidia-new "NVIDIA (New, Maxwell and newer)" nvidia-old "NVIDIA (Old, Kepler and newer)" virtualbox VirtualBox vmware VMware)
# Keep track of the selected graphics drivers for upgrade purposes.
echo ${graphics_selected} | sudo tee /etc/winesapos/graphics
kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the graphics driver to be installed..." 2 | cut -d" " -f1)
qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

if [[ "${graphics_selected}" == "amd" ]]; then
    true
elif [[ "${graphics_selected}" == "intel" ]]; then
    sudo pacman -S --noconfirm \
      extra/intel-media-driver \
      extra/intel-compute-runtime
elif [[ "${graphics_selected}" == "nvidia-new" ]]; then
    sudo pacman -S --noconfirm \
      extra/nvidia-dkms \
      extra/nvidia-utils \
      multilib/lib32-nvidia-utils \
      extra/opencl-nvidia \
      multilib/lib32-opencl-nvidia

    # Enable partial support for gamescope.
    sudo sed -i s'/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /'g /etc/default/grub

    # Block the loading of conflicting open source NVIDIA drivers.
    sudo touch /etc/modprobe.d/winesapos-nvidia.conf
    echo "blacklist nouveau
blacklist nvidiafb
blacklist nv
blacklist rivafb
blacklist rivatv
blacklist uvcvideo" | sudo tee /etc/modprobe.d/winesapos-nvidia.conf

    # Remove the open source Nouveau driver.
    sudo pacman -R -n -s --noconfirm xf86-video-nouveau
elif [[ "${graphics_selected}" == "nvidia-old" ]]; then
    ${CMD_YAY_INSTALL} \
      nvidia-470xx-dkms \
      nvidia-470xx-utils \
      lib32-nvidia-470xx-utils \
      opencl-nvidia-470xx \
      lib32-opencl-nvidia-470xx

    # Enable partial support for gamescope.
    sudo sed -i s'/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="nvidia-drm.modeset=1 /'g /etc/default/grub

    # Block the loading of conflicting open source NVIDIA drivers.
    sudo touch /etc/modprobe.d/winesapos-nvidia.conf
    echo "blacklist nouveau
blacklist nvidiafb
blacklist nv
blacklist rivafb
blacklist rivatv
blacklist uvcvideo" | sudo tee /etc/modprobe.d/winesapos-nvidia.conf

    # Remove the open source Nouveau driver.
    sudo pacman -R -n -s --noconfirm xf86-video-nouveau
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
qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to enable swap (recommended)?"
if [ $? -eq 0 ]; then
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for swap to be enabled..." 2 | cut -d" " -f1)
    swap_size_selected=$(kdialog --title "winesapOS First-Time Setup" --inputbox "Swap size (GB):" "8")
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
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
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
elif [ $? -eq 1 ]; then
    # If the user does not want swap, ask them about zram instead.
    kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to setup zram instead (recommended if you do not use swap)?"
    if [ $? -eq 0 ]; then
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for zram to be enabled..." 2 | cut -d" " -f1)
        qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
        # zram half the size of RAM.
        winesap_ram_size=$(free -m | grep Mem | awk '{print $2}')
        zram_size=$(expr ${winesap_ram_size} / 2)
        sudo touch /etc/systemd/system/winesapos-zram.service /usr/local/bin/winesapos-zram-setup.sh
        
        # Setup script to run on boot.
        # Yes they are supposed to not be tabbed in.
        echo """#!/bin/bash

/usr/bin/modprobe zram
echo zstd > /sys/block/zram0/comp_algorithm
echo ${zram_size}M > /sys/block/zram0/disksize
/usr/bin/mkswap --label winesapos-zram /dev/zram0
/usr/bin/swapon --priority 100 /dev/zram0""" | sudo tee /usr/local/bin/winesapos-zram-setup.sh && sudo chmod +x /usr/local/bin/winesapos-zram-setup.sh

        # Now the systemd service.
        echo """[Unit]
Description=winesapOS zram setup
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash /usr/local/bin/winesapos-zram-setup.sh

[Install]
WantedBy=multi-user.target""" | sudo tee /etc/systemd/system/winesapos-zram.service

        sudo systemctl daemon-reload && sudo systemctl enable --now winesapos-zram.service

        qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
    fi
fi

kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change the current locale (en_US.UTF-8 UTF-8)?"
if [ $? -eq 0 ]; then
    kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to see all availables locales in /etc/locale.gen?"
    if [ $? -eq 0 ]; then
        kdialog --title "winesapOS First-Time Setup" --textbox /etc/locale.gen
    fi

    locale_selected=$(kdialog --title "winesapOS First-Time Setup" --inputbox "Locale for /etc/locale.gen:" "en_US.UTF-8 UTF-8")
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the locale to be setup..." 2 | cut -d" " -f1)
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    echo "${locale_selected}" | sudo tee -a /etc/locale.gen
    sudo locale-gen
    sudo sed -i '/^LANG/d' /etc/locale.conf
    echo "LANG=$(echo ${locale_selected} | cut -d' ' -f1)" | sudo tee -a /etc/locale.conf
    sed -i '/^LANG/d' /home/${USER}/.config/plasma-localerc
    echo "LANG=$(echo ${locale_selected} | cut -d' ' -f1)" >> /home/${USER}/.config/plasma-localerc
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
fi

kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change the current time zone (UTC)?"
if [ $? -eq 0 ]; then
    selected_time_zone=$(kdialog --title "winesapOS First-Time Setup" --combobox "Select the desired time zone:" $(timedatectl list-timezones))
    sudo timedatectl set-timezone ${selected_time_zone}
fi

kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to install recommended Flatpaks for productivity?"
if [ $? -eq 0 ]; then
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for recommended productivity Flatpaks to be installed..." 9 | cut -d" " -f1)
    # Cheese for a webcam utility.
    sudo ${CMD_FLATPAK_INSTALL} org.gnome.Cheese
    cp /var/lib/flatpak/app/org.gnome.Cheese/current/active/export/share/applications/org.gnome.Cheese.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    # FileZilla for FTP file transfers.
    sudo ${CMD_FLATPAK_INSTALL} org.filezillaproject.Filezilla
    cp /var/lib/flatpak/exports/share/applications/org.filezillaproject.Filezilla.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
    # Flatseal for managing Flatpaks.
    sudo ${CMD_FLATPAK_INSTALL} com.github.tchx84.Flatseal
    cp /var/lib/flatpak/app/com.github.tchx84.Flatseal/current/active/export/share/applications/com.github.tchx84.Flatseal.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
    # Google Chrome web browser.
    sudo ${CMD_FLATPAK_INSTALL} com.google.Chrome
    cp /var/lib/flatpak/app/com.google.Chrome/current/active/export/share/applications/com.google.Chrome.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4
    # KeePassXC for an encrypted password manager.
    sudo ${CMD_FLATPAK_INSTALL} org.keepassxc.KeePassXC
    cp /var/lib/flatpak/app/org.keepassxc.KeePassXC/current/active/export/share/applications/org.keepassxc.KeePassXC.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5
    # LibreOffice for an office suite.
    sudo ${CMD_FLATPAK_INSTALL} org.libreoffice.LibreOffice
    cp /var/lib/flatpak/app/org.libreoffice.LibreOffice/current/active/export/share/applications/org.libreoffice.LibreOffice.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6
    # PeaZip compression utility.
    sudo ${CMD_FLATPAK_INSTALL} io.github.peazip.PeaZip
    cp /var/lib/flatpak/app/io.github.peazip.PeaZip/current/active/export/share/applications/io.github.peazip.PeaZip.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 7
    # qBittorrent for torrents.
    sudo ${CMD_FLATPAK_INSTALL} org.qbittorrent.qBittorrent
    cp /var/lib/flatpak/app/org.qbittorrent.qBittorrent/current/active/export/share/applications/org.qbittorrent.qBittorrent.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 8
    # VLC media player.
    sudo ${CMD_FLATPAK_INSTALL} com.transmissionbt.Transmission org.videolan.VLC
    cp /var/lib/flatpak/app/org.videolan.VLC/current/active/export/share/applications/org.videolan.VLC.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
else
    for prodpkg in $(kdialog --title "winesapOS First-Time Setup" --separate-output --checklist "Select productivity packages to install:" \
                       balena-etcher:other "balenaEtcher (storage cloner)" off \
                       org.gnome.Cheese:flatpak "Cheese (webcam)" off \
                       com.gitlab.davem.ClamTk:flatpak "ClamTk (anti-virus)" off \
                       org.filezillaproject.Filezilla:flatpak "FileZilla (FTP)" off \
                       com.github.tchx84.Flatseal:flatpak "Flatseal (Flatpak manager)" off \
                       com.google.Chrome "Google Chrome (web browser)" off \
                       gparted:pkg "GParted (partition manager)" off \
                       org.keepassxc.KeePassXC:flatpak "KeePassXC (password manager)" off \
                       org.libreoffice.LibreOffice:flatpak "LibreOffice (office suite)" off \
                       io.github.peazip.PeaZip:flatpak "PeaZip (compression)" off \
                       qdirstat:pkg "QDirStat (storage space analyzer)" off \
                       shutter:pkg "Shutter (screenshots)" off \
                       org.qbittorrent.qBittorrent:flatpak "qBittorrent (torrent)" off \
                       veracrypt:pkg "VeraCrypt (file encryption)" off \
                       org.videolan.VLC:flatpak "VLC (media player)" off)
        do;
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for ${prodpkg} to be installed..." 2 | cut -d" " -f1)
        qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
        echo ${prodpkg} | grep -P ":flatpak$"
        if [ $? -eq 0 ]; then
            sudo ${CMD_FLATPAK_INSTALL} $(echo "${prodpkg}" | cut -d: -f1)
        fi
        echo ${prodpkg} | grep -P ":pkg$"
        if [ $? -eq 0 ]; then
            ${CMD_YAY_INSTALL} $(echo "${prodpkg}" | cut -d: -f1)
        fi
        echo ${prodpkg} | grep -P "^balena-etcher:other$"
        if [ $? -eq 0 ]; then
            export ETCHER_VER="1.7.9"
            wget "https://github.com/balena-io/etcher/releases/download/v${ETCHER_VER}/balenaEtcher-${ETCHER_VER}-x64.AppImage" -O /home/${USER}/Desktop/balenaEtcher.AppImage
            chmod +x /home/${USER}/Desktop/balenaEtcher.AppImage
        fi
        qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
    done
fi

kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to install recommended Flatpaks for gaming?"
if [ $? -eq 0 ]; then
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for recommended gaming Flatpaks to be installed..." 7 | cut -d" " -f1)
    # AntiMicroX for configuring controller input.
    sudo ${CMD_FLATPAK_INSTALL} io.github.antimicrox.antimicrox
    cp /var/lib/flatpak/app/io.github.antimicrox.antimicrox/current/active/export/share/applications/io.github.antimicrox.antimicrox.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    # Bottles for running any Windows game or application.
    sudo ${CMD_FLATPAK_INSTALL} com.usebottles.bottles
    cp /var/lib/flatpak/app/com.usebottles.bottles/current/active/export/share/applications/com.usebottles.bottles.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
    # Discord for social gaming.
    sudo ${CMD_FLATPAK_INSTALL} com.discordapp.Discord
    cp /var/lib/flatpak/app/com.discordapp.Discord/current/active/export/share/applications/com.discordapp.Discord.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
    # Prism Launcher for playing Minecraft.
    sudo ${CMD_FLATPAK_INSTALL} org.prismlauncher.PrismLauncher
    cp /var/lib/flatpak/app/org.prismlauncher.PrismLauncher/current/active/export/share/applications/org.prismlauncher.PrismLauncher.desktop /home/${USER}/Desktop/
    sed -i s'/Exec=\/usr\/bin\/flatpak/Exec=\/usr\/bin\/gamemoderun\ \/usr\/bin\/flatpak/'g /home/${USER}/Desktop/org.prismlauncher.PrismLauncher.desktop
    crudini --set /home/${USER}/Desktop/org.prismlauncher.PrismLauncher.desktop "Desktop Entry" Name "Prism Launcher - GameMode"
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 4
    # Protontricks for managing dependencies in Proton.
    sudo ${CMD_FLATPAK_INSTALL} com.github.Matoking.protontricks
    ## Add a wrapper script so that the Flatpak can be used normally via the CLI.
    echo '#!/bin/bash
flatpak run com.github.Matoking.protontricks $@
' | sudo tee /usr/local/bin/protontricks
    sudo chmod +x /usr/local/bin/protontricks
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 5
    # ProtonUp-Qt for managing GE-Proton versions.
    cp /var/lib/flatpak/app/net.davidotek.pupgui2/current/active/export/share/applications/net.davidotek.pupgui2.desktop /home/${USER}/Desktop/
    sudo ${CMD_FLATPAK_INSTALL} net.davidotek.pupgui2
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 6
    # OBS Studio for screen recording and live streaming.
    sudo ${CMD_FLATPAK_INSTALL} com.obsproject.Studio
    cp /var/lib/flatpak/app/com.obsproject.Studio/current/active/export/share/applications/com.obsproject.Studio.desktop /home/${USER}/Desktop/
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
else
    for gamepkg in $(kdialog --title "winesapOS First-Time Setup" --separate-output --checklist "Select gaming packages to install:" \
                 io.github.antimicrox.antimicrox:flatpak "AntiMicroX" off \
                 com.usebottles.bottles:flatpak "Bottles" off \
                 com.discordapp.Discord:flatpak "Discord" off \
                 emudeck:other "EmuDeck" off \
                 gamemode:pkg "GameMode (64-bit)" off \
                 lib32-gamemode:pkg "GameMode (32-bit)" off \
                 gamescope:pkg "Gamescope" off \
                 game-devices-udev:pkg "games-devices-udev (extra controller support)" off \
                 goverlay:pkg "GOverlay" off \
                 heroic-games-launcher-bin:pkg "Heroic Games Launcher" off \
                 ludusavi:pkg "Ludusavi" off \
                 lutris:pkg "Lutris" off \
                 mangohud:pkg "MangoHUD (64-bit)" off \
                 lib32-mangohud:pkg "MangoHUD (32-bit)" off \
                 com.obsproject.Studio:flatpak "Open Broadcaster Software (OBS) Studio." off \
                 org.prismlauncher.PrismLauncher:flatpak "Prism Launcher" off \
                 com.github.Matoking.protontricks:flatpak "Protontricks" off \
                 net.davidotek.pupgui2:flatpak "ProtonUp-Qt" off \
                 steam:other "Steam" off \
                 wine-staging:pkg "Wine Staging" off \
                 zerotier-one:pkg "ZeroTier One VPN (CLI)" off \
                 zerotier-gui-git:pkg "ZeroTier One VPN (GUI)" off)
        do;
        kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for ${gamepkg} to be installed..." 2 | cut -d" " -f1)
        qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
        echo ${gamepkg} | grep -P ":flatpak$"
        if [ $? -eq 0 ]; then
            sudo ${CMD_FLATPAK_INSTALL} $(echo "${gamepkg}" | cut -d: -f1)
        fi
        echo ${gamepkg} | grep -P ":pkg$"
        if [ $? -eq 0 ]; then
            ${CMD_YAY_INSTALL} $(echo "${gamepkg}" | cut -d: -f1)
        fi
        echo ${gamepkg} | grep -P "^emudeck:other$"
        if [ $? -eq 0 ]; then
            EMUDECK_GITHUB_URL="https://api.github.com/repos/EmuDeck/emudeck-electron/releases/latest"
            EMUDECK_URL="$(curl -s ${EMUDECK_GITHUB_URL} | grep -E 'browser_download_url.*AppImage' | cut -d '"' -f 4)"
            wget "${EMUDECK_URL}" -O /home/${USER}/Desktop/EmuDeck.AppImage
            chmod +x /home/${USER}/Desktop/EmuDeck.AppImage
        fi

        echo ${gamepkg} | grep -P "^steam:other$"
        if [ $? -eq 0 ]; then
            winesapos_distro_autodetect=$(grep -P "^ID=" /etc/os-release | cut -d= -f2)
            if [[ "${winesapos_distro_autodetect}" == "manjaro" ]]; then
                sudo pacman -S --noconfirm steam-manjaro steam-native
            else
                sudo pacman -S --noconfirm steam steam-native-runtime
            fi
        fi
        qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
    done
fi

# Fix permissions.
sudo chown 1000:1000 /home/${USER}/Desktop/*.desktop
chmod +x /home/${USER}/Desktop/*.desktop

answer_install_ge="false"
kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to install the GloriousEggroll variants of Proton (for Steam) and Wine (for Lutris)?"
if [ $? -eq 0 ]; then
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for GE-Proton to be installed..." 2 | cut -d" " -f1)
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    answer_install_ge="true"
    # GE-Proton.
    mkdir -p /home/${USER}/.local/share/Steam/compatibilitytools.d/
    PROTON_GE_VERSION="GE-Proton7-55"
    curl https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_GE_VERSION}/${PROTON_GE_VERSION}.tar.gz --location --output /home/${USER}/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz
    tar -x -v -f /home/${USER}/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz --directory /home/${USER}/.local/share/Steam/compatibilitytools.d/
    rm -f /home/${USER}/.local/share/Steam/compatibilitytools.d/${PROTON_GE_VERSION}.tar.gz
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

    # Wine-GE.
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Wine-GE to be installed..." 2 | cut -d" " -f1)
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    export WINE_GE_VER="GE-Proton8-17"
    mkdir -p /home/${USER}/.local/share/lutris/runners/wine/
    curl https://github.com/GloriousEggroll/wine-ge-custom/releases/download/${WINE_GE_VER}/wine-lutris-${WINE_GE_VER}-x86_64.tar.xz --location --output /home/${USER}/.local/share/lutris/runners/wine/wine-lutris-${WINE_GE_VER}-x86_64.tar.xz
    tar -x -v -f /home/${USER}/.local/share/lutris/runners/wine/wine-lutris-${WINE_GE_VER}-x86_64.tar.xz -C ${WINESAPOS_INSTALL_DIR}/home/${USER}/.local/share/lutris/runners/wine/
    rm -f /home/${USER}/.local/share/lutris/runners/wine/*.tar.xz
    chown -R 1000:1000 /home/${USER}
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
fi

# This package contains proprietary firmware that we cannot ship
# which is why it is installed as part of the first-time setup.
kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to install Xbox controller support?"
if [ $? -eq 0 ]; then
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Xbox controller drivers to be installed..." 2 | cut -d" " -f1)
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    ${CMD_YAY_INSTALL} xone-dkms-git
    sudo touch /etc/modules-load.d/winesapos-controllers.conf
    echo -e "xone-wired\nxone-dongle\nxone-gip\nxone-gip-gamepad\nxone-gip-headset\nxone-gip-chatpad\nxone-gip-guitar" | sudo tee -a /etc/modules-load.d/winesapos-controllers.conf
    for i in xone-wired xone-dongle xone-gip xone-gip-gamepad xone-gip-headset xone-gip-chatpad xone-gip-guitar;
        do sudo modprobe --verbose ${i}
    done
    sudo git clone https://github.com/medusalix/xpad-noone /usr/src/xpad-noone-1.0
    for kernel in $(ls -1 /usr/lib/modules/ | grep -P "^[0-9]+"); do
        sudo dkms install -m xpad-noone -v 1.0 -k ${kernel}
    done
    echo -e "\nxpad-noone\n" | sudo tee -a /etc/modules-load.d/winesapos-controllers.conf
    echo -e "\nblacklist xpad\n" | sudo tee -a /etc/modprobe.d/winesapos.conf
    sudo rmmod xpad
    sudo modprobe xpad-noone
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
fi

kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to enable the ZeroTier VPN service?"
if [ $? -eq 0 ]; then
    # ZeroTier GUI will fail to launch with a false-positive error if the service is not running.
    sudo systemctl enable --now zerotier-one
fi

kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to install support for the Bcachefs file system?"
if [ $? -eq 0 ]; then
    kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for Bcachefs support to be installed..." 4 | cut -d" " -f1)
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
    ${CMD_YAY_INSTALL} linux-bcachefs-git
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 2
    ${CMD_YAY_INSTALL} linux-bcachefs-git-headers
    qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 3
    ${CMD_YAY_INSTALL} bcachefs-tools-git
    qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close
fi

if [[ "$(sudo cat /etc/winesapos/IMAGE_TYPE)" != "secure" ]]; then
    kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change your password?"
    if [ $? -eq 0 ]; then
        # Disable debug logging as to not leak password in the log file.
        set +x
        winesap_password=$(kdialog --title "winesapOS First-Time Setup" --password "Enter your new password:")
        echo "${USER}:${winesap_password}" | sudo chpasswd
        # Re-enable debug logging.
        set -x
    fi
fi

kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change the root password?"
if [ $? -eq 0 ]; then
    set +x
    root_password=$(kdialog --title "winesapOS First-Time Setup" --password "Enter the new root password:")
    echo "root:${root_password}" | sudo chpasswd
    set -x
fi

if [[ "$(sudo cat /etc/winesapos/IMAGE_TYPE)" == "secure" ]]; then
    kdialog --title "winesapOS First-Time Setup" --yesno "Do you want to change the LUKS storage encryption password?"
    if [ $? -eq 0 ]; then
        # This should always be "/dev/mapper/cryptroot" on the secure image.
        root_partition=$(mount | grep 'on \/ ' | awk '{print $1}')
        # Example output: "mmcblk0p5", "nvme0n1p5", "sda5"
        root_partition_shortname=$(lsblk -o name,label | grep winesapos-luks | awk '{print $1}' | grep -o -P '[a-z]+.*')
        set +x
        luks_password=$(kdialog --title "winesapOS First-Time Setup" --password "Enter the new LUKS storage encryption password:")
        echo -e "password\n${luks_password}\n${luks_password}\n" | cryptsetup luksChangeKey /dev/${root_partition_shortname}
        set -x
    fi
fi

# Remove the Flatpak directory for the user to avoid errors.
# This directory will automatically get re-generated when a 'flatpak' command is ran.
# https://github.com/LukeShortCloud/winesapOS/issues/516
rm -r -f /home/${USER}/.local/share/flatpak

kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the new drivers to be enabled on boot..." 2 | cut -d" " -f1)
qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1
# Regenerate the initramfs to load all of the new drivers.
sudo mkinitcpio -P
qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

# Regenerate the GRUB configuration to load the new Btrfs snapshots.
# This allows users to easily revert back to a fresh installation of winesapOS.
sudo grub-mkconfig -o /boot/grub/grub.cfg

# Delete the shortcut symlink so this will not auto-start again during the next login.
rm -f ~/.config/autostart/winesapos-setup.desktop

echo "Running first-time setup tests..."
kdialog_dbus=$(kdialog --title "winesapOS First-Time Setup" --progressbar "Please wait for the first-time setup tests to finish..." 2 | cut -d" " -f1)
qdbus ${kdialog_dbus} /ProgressDialog Set org.kde.kdialog.ProgressDialog value 1

if [[ "${answer_install_ge}" == "true" ]]; then
    echo "Testing that GE Proton has been installed..."
    echo -n "\tChecking that GE Proton is installed..."
    ls -1 /home/${USER}/.local/share/Steam/compatibilitytools.d/ | grep -v -P ".tar.gz$" | grep -q -P "^GE-Proton.*"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi

    echo -n "\tChecking that the GE Proton tarball has been removed..."
    ls -1 /home/${USER}/.local/share/Steam/compatibilitytools.d/ | grep -q -P ".tar.gz$"
    if [ $? -eq 1 ]; then
        echo PASS
    else
        echo FAIL
    fi
    echo -n "Testing that Wine GE is installed..."
    ls -1 /home/${USER}/.local/share/lutris/runners/wine/ | grep -q -P "^lutris-GE-Proton.*"
    if [ $? -eq 0 ]; then
        echo PASS
    else
        echo FAIL
    fi
    echo "Testing that GE Proton has been installed complete."
fi
echo "Running first-time setup tests complete."
qdbus ${kdialog_dbus} /ProgressDialog org.kde.kdialog.ProgressDialog.close

kdialog --title "winesapOS First-Time Setup" --msgbox "Please reboot to load new changes."
echo "End time: $(date --iso-8601=seconds)"
