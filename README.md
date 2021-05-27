# Mac Linux Gaming Stick

Linux gaming, on a stick (flash drive or external SSD), designed for Mac enthusiasts.

This is an opinionated take on creating a portable USB drive with Linux installed to enable gaming on any computer via Steam and Proton/Wine. This project is tailored towards Macs by providing relevant third-party drivers.

**TABLE OF CONTENTS**

* [Mac Linux Gaming Stick](#mac-linux-gaming-stick)
   * [macOS Limitations](#macos-limitations)
   * [Project Goals](#project-goals)
   * [Setup](#setup)
      * [Linux Installation](#linux-installation)
         * [Ubuntu 20.04.2](#ubuntu-20042)
      * [Legacy BIOS Boot](#legacy-bios-boot)
      * [Touchbar](#touchbar)
      * [Optimize the File Systems](#optimize-the-file-systems)
      * [Btrfs Backups](#btrfs-backups)
         * [Automatic](#automatic)
         * [Manual](#manual)
      * [WiFi Driver (88x2bu)](#wifi-driver-88x2bu)
      * [Blacklist Drivers](#blacklist-drivers)
      * [Wireless Keyboard and Mouse](#wireless-keyboard-and-mouse)
      * [Packages](#packages)
      * [VPN (ZeroTier)](#vpn-zerotier)
      * [SSH](#ssh)
      * [Wine Staging](#wine-staging)
      * [Steam](#steam)
      * [Proton GE](#proton-ge)
      * [Linux Kernel](#linux-kernel)
         * [Hardware Enablement](#hardware-enablement)
         * [Freeze Linux Kernel Version](#freeze-linux-kernel-version)
      * [Google Chrome](#google-chrome)
      * [Lutris](#lutris)
      * [Wayland](#wayland)
      * [FreeOffice](#freeoffice)
      * [Dock](#dock)
      * [Mac Boot](#mac-boot)
   * [Tips](#tips)
   * [License](#license)

## macOS Limitations

These are reasons why macOS is inferior compared to Linux when it comes to gaming.

- No 32-bit support. The latest version is now 64-bit only. As of April 2021, there are [1079 full PC games](https://www.pcgamingwiki.com/wiki/List_of_OS_X_64-bit_games) (i.e., not apps) on macOS that are available as 64-bit. That number is only [2% of all games available on Steam](https://store.steampowered.com/search/?category1=998).
- Macs in 2020 have started the move from Intel to Arm-based processors, further lowering the amount of full games it supports natively to almost zero.
- The Apple M1 Arm-based processor has limited graphics capabilities and that are [comparable to integrated graphics offered by AMD and Intel](https://arstechnica.com/gadgets/2020/11/hands-on-with-the-apple-m1-a-seriously-fast-x86-competitor/). These Macs are not designed to be gaming computers.
    - Intel x86_64 games played through the Rosetta 2 compability layer have over a [20% performance penalty](https://www.macrumors.com/2020/11/15/m1-chip-emulating-x86-benchmark/).
- As of April 2021, [80% of reported Steam games run on Linux](https://www.protondb.com/).
- Steam Play's Proton is only [supported on Linux](https://github.com/ValveSoftware/Proton/wiki/Requirements) ([not macOS](https://github.com/ValveSoftware/Proton/issues/1344)).
- Old and incomplete implementation of OpenGL.
- No native Vulkan support.
    - MoltenVK is [incomplete due to missing functionality in Apple's Metal API](https://github.com/KhronosGroup/MoltenVK/issues/203).
- Linux has better gaming support because it supports 32-bit applications, DirectX (via Wine with WineD3D, DXVK, and/or Vkd3d), OpenGL, and Vulkan.
- [CrossOver Mac](https://www.codeweavers.com/crossover), a commercial Wine product, is one of the few ways to run games on macOS but has some limitations.
    - It costs money and usually requires a new license yearly.
    - 32-bit Windows application support on 64-bit only macOS versions is still buggy.
    - It is always based on a old stable Wine version that is at least one year behind upstream Wine version.
    - DXVK (via a modified version of MoltenVK) has limited support.
    - Vulkan is not supported yet.
    - Linux has kernel-level optimizations for Wine.

## Project Goals

- Any AMD or Intel computer can run mac-linux-gaming-stick. This project is not limited to Macs.
- All Intel Macs are supported. Linux works on most Macs out-of-the-box these days. Drivers are pre-installed for newer hardware where native Linux support is missing.
    - [Compatiblity guide](https://github.com/Dunedan/mbp-2016-linux).
- Portability. The flash drive should be bootable on both BIOS and UEFI systems.
- Supportability. Linux will be easy for me to remotely troubleshoot using tools such as `tmate` and Google's `Chrome Remote Desktop`.
- Gaming support out-of-the-box.
- Minimze writes to the flash drive to improve its longevity.
- Full backups via Btrfs.
- Automatic operating system updates are disabled. Updates should always be intentional and planned.
- Battery optimizations.
- As much reproducible automation as possible via Ansible.
    - Any manual steps will be documented in this README file.

Not planned to support:

- Built-in Bluetooth and/or WiFi.

It is easier and more reliable to buy additional hardware and use a USB-C hub than to rely on hacky Linux drivers for Mac. Workarounds do exist for [WiFi](https://gist.github.com/roadrunner2/1289542a748d9a104e7baec6a92f9cd7#gistcomment-3080934) on the 2016-2017 MacBook Pros however speeds are reported as being slower.

## Setup

### Linux Installation

It is recommended to use a UEFI virtual machine with USB passthrough to setup the USB flash drive. This will avoid ruining the bootloader and/or storage devices on the actual computer.

virt-manager:

```
File > New Virtual Machine > Local install media (ISO image or CDROM) > Forward > Choose ISO or CDROM install media > Browse... > ubuntu-20.04.2-desktop-amd64.iso > Forward > Forward (keep default CPU and RAM settings) > uncheck "Enable storage for this virtual machine" > Forward > check "Customize configuration before installation" > Finish > Add Hardware > USB Host Device > (select the device, in my case it was "004:004 Silicion Motion, Inc. - Taiwan (formerly Feiya Technology Corp.) Flash Drive") > Finish > Boot Options > (check the "USB" option to allow it to be bootable to test the installation when it is done) > Apply > Begin Installation
```

The Ubuntu installer is extremely limited when it comes to custom partitions. It is not possible to specify a BIOS or GPT partition table, customize Btrfs subvolumes, or set partition flags. Instead, use the `parted` command to format the flash drive. DO AT YOUR OWN RISK. DO NOT USE THE WRONG DEVICE.

```
$ lsblk
$ sudo dd if=/dev/zero of=/dev/<DEVICE> bs=1M count=5
$ sudo parted /dev/<DEVICE>
# GPT is required for UEFI boot.
(parted) mklabel gpt
# An empty partition is required for BIOS boot backwards compatibility.
(parted) mkpart primary 2048s 2M
# EFI partition.
(parted) mkpart primary fat32 2M 500M
(parted) set 2 boot on
(parted) set 2 esp on
# 8GB swap.
(parted) mkpart primary linux-swap 500M 8500M
(parted) set 3 swap on
# Root partition using the rest of the space.
(parted) mkpart primary btrfs 8500M 100%
(parted) print                                                       	 
Model: Samsung Flash Drive FIT (scsi)
Disk /dev/sda: 128GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End 	Size	File system 	Name 	Flags
 1  	1049kB  2097kB  1049kB              	primary
 2  	2097kB  500MB   498MB   fat32       	primary  boot, esp
 3  	500MB   8500MB  8000MB  linux-swap(v1)  primary  swap
 4  	8500MB  128GB   120GB   btrfs       	primary
(parted) quit
```

Next, download Ubuntu 20.04.2 or newer.

- [Ubuntu 20.04.2](https://ubuntu.com/download/desktop)

#### Ubuntu 20.04.2

Start the installer:

```
Install Ubuntu > (select the desired language) > Continue (select the desired Keyboard layout) > Continue > (check "Normal Installation", "Download updates while installing Ubuntu", and "Install third-party software for graphics and Wi-Fi hardware and additional media formats") > Continue > (select "Something else" for the partition Installation type) > Continue
```

Configure the partitions:

```
/dev/<DEVICE>1 > Change... > do not use the partition > OK
/dev/<DEVICE>2 > Change... > EFI System Partition > OK
/dev/<DEVICE>3 > Change... > swap area > OK
/dev/<DEVICE>4 > Change... > Use as: btrfs journaling file system, check "Format the partition:", Mount pount: / > OK
```

Finish the installation: `Install Now`

### Legacy BIOS Boot

Macs [made after 2014](https://twocanoes.com/boot-camp-boot-process/) do not support legacy BIOS boot. For older computers, it can be installed by rebooting and running the commands below. Use the same USB flash drive device. This will enable both legacy BIOS and UEFI boot.

The `bios_grub` flag must be set after the Ubuntu installation. Otherwise, the installer will mistake the first partition as the EFI boot partition and will try (and fail) to mount and use it.

```
$ sudo parted /dev/<DEVICE>
(parted) set 1 bios_grub on
(parted) quit
```

```
$ sudo grub-install --target=i386-pc /dev/<DEVICE>
```

### Touchbar

Some newer MacBook Pros include a Touchbar that does not work out-of-the-box and requires additional drivers for at least the function keys to work. Instructions on how to install these drivers are documented [here](https://github.com/roadrunner2/macbook12-spi-driver#dkms-module-debian--co). Be sure to include the Touchbar drivers in the initramfs (so it is available on boot) by using the tweaked directions below.

```
$ echo -e "\n# applespi\napplespi\nspi_pxa2xx_platform\nintel_lpss_pci\napple_ibridge\napple_ib_tb\napple_ib_als" | sudo tee -a /etc/initramfs-tools/modules
$ sudo apt install dkms
$ sudo git clone https://github.com/roadrunner2/macbook12-spi-driver.git /usr/src/applespi-0.1
$ sudo dkms install -m applespi -v 0.1
```

### Optimize the File Systems

Minimize writes to the disk by using the included `tmpfs` Ansible role. For system stability, it is recommended to not set the swappiness level to 0.

```
$ cat inventory_stick.ini
linux-stick ansible_host=<VM_IP_ADDRESS> ansible_user=<SSH_USER>
$ cat playbook_tmpfs.yaml
---
- hosts: linux-stick
  roles:
    - name: tmpfs
      vars:
        tmpfs_vm_swappiness: 10
$ ansible-playbook -i inventory_stick.ini playbook_tmpfs.yaml --become --ask-become-pass
```

Also configure the root and home file systems to use new mount options that will lower the amount of writes and evenly spread the wear on the flash drive: `noatime,nodiratime,ssd_spread` (ssd_spread is for Btrfs only).

```
$ sudo vim /etc/fstab
UUID=<UUID>    /        btrfs    defaults,subvol=@,noatime,nodiratime,ssd_spread        0    1
UUID=<UUID>    /home    btrfs    defaults,subvol=@home,noatime,nodiratime,ssd_spread    0    2
```

### Btrfs Backups

#### Automatic

The Ansible role `btrfs_backups` will fully configure `apt-btrfs-snapshot` along with `grub-btrfs`.

```
$ cat playbook_btrfs_backups.yaml
---
- hosts: linux-stick
  roles:
    - name: btrfs_backups
$ ansible-playbook -i inventory_stick.ini playbook_btrfs_backups.yaml --become --ask-become-pass
```

#### Manual

Install and configure `grub-btrfs`. This will add a new GRUB menu entry that shows all of the available Btrfs snapshots.

```
$ git clone https://github.com/Antynea/grub-btrfs.git
$ cd grub-btrfs/
$ sudo make install
$ sudo vim /etc/default/grub-btrfs/config
GRUB_BTRFS_SUBMENUNAME="Buttery Backups"
```

Install the `apt-btrfs-snapshot` package. This will automatically take a Btrfs snapshot of the root `/` file system whenever `apt` makes a change to the system.

```
$ sudo apt-get install apt-btrfs-snapshot python3-distutils
```

Verify that `apt-btrfs-snapshot` works.

```
$ sudo apt-btrfs-snapshot supported
$ sudo apt-get update && sudo apt-get upgrade
$ sudo apt-btrfs-snapshot list
```

GRUB needs to be manually updated with the latest snapshots. In the future, this will automatically be updated when the kernel is also updated (or any other package updates GRUB).

```
$ sudo grub-mkconfig -o /boot/grub/grub.cfg
```

### WiFi Driver (88x2bu)

Follow the [DKMS installation](https://github.com/cilynx/rtl88x2BU#dkms-installation) instructions for the rtl88x2bu driver. Then use `modprobe 88x2bu` to load it.

Install the `88x2bu` kernel module for [every Linux kernel that is installed](https://askubuntu.com/questions/53364/command-to-rebuild-all-dkms-modules-for-all-installed-kernels/174017#174017).

```
$ sudo su -
# dkms status | sed s/,//g | awk '{print "-m",$1,"-v",$2}' | while read line; do ls /var/lib/initramfs-tools | xargs -n 1 dkms install $line -k; done
# modprobe 88x2bu
```

### Sound Driver

The sound driver for built-in speakers is only required on newer MacBook Pros.

```
$ mkdir ~/github/
$ cd ~/github/
$ git clone https://github.com/davidjo/snd_hda_macbookpro.git
$ cd ./snd_hda_macbookpro/
$ sudo ./install.cirrus.driver.sh
$ echo "snd-hda-codec-cirrus" | sudo tee -a /etc/modules-load.d/linux-gaming-stick.conf
$ sudo modprobe snd-hda-codec-cirrus
```

### Blacklist Drivers

Some models of the 2016-2017 MacBook Pro have unreliable Bluetooth and WiFi drivers. It is recommended to blacklist (disable) those drivers: `apple_bl`, `brcmfmac`, and `brcmutil`. This is done automatically by the `linux_stick` Ansible role. In this situation, an external Bluetooth and WiFi adapter should be used for the best experience.

### Packages

Other packages and system configurations are handled by the `linux_stick` Ansible role. This will disable automatic updates, install the required drivers and packages for gaming, and setup `tlp` for power management.

```
$ cat playbook_linux_stick.yaml
---
- hosts: linux-stick
  roles:
    - name: linux_stick
$ ansible-playbook -i inventory_stick.ini playbook_linux_stick.yaml --become --ask-become-pass
```

### Wireless Keyboard and Mouse

Some wireless keyboards and mice in Linux have random lag. This can be worked around by [forcing the polling frequency to be 125 Hz](https://askubuntu.com/questions/1130869/keyboard-and-mouse-stuttering-on-ubuntu-18-04-with-a-new-laptop/1130870#1130870).

Temporary fix:

```
$ echo 1 | sudo tee /sys/module/usbhid/parameters/kbpoll
$ echo 1 | sudo tee /sys/module/usbhid/parameters/mousepoll
```

Permanent fix:

```
$ sudo grubby --update-kernels=ALL --args "usbhid.kbpoll=1 usbhid.mousepoll=1"
$ sudo update-grub
```

According to [here](https://utcc.utoronto.ca/~cks/space/blog/linux/USBMousePollingRate), these are all of the possible values that can be tested.

* 0 = Use the default frequency reported by the mouse.
* 1 = 125 Hz.
* 2 = 500 Hz.

### VPN (ZeroTier)

A VPN is required for LAN gaming online. Hamachi is reported to no longer work on newer versions of [Arch Linux](https://aur.archlinux.org/packages/logmein-hamachi/ ) and [Ubuntu](https://community.logmein.com/t5/LogMeIn-Hamachi-Discussions/Hamachi-randomly-disconnects-on-Ubuntu-20-04/td-p/222430).

Instead, use the free and open source ZeroTier. Install the client using this [provided script](https://support.paperspace.com/hc/en-us/articles/115000973693-How-to-Create-a-VPN-tunnel-with-ZeroTier-Linux-).

```
$ curl -s 'https://pgp.mit.edu/pks/lookup?op=get&search=0x1657198823E52A61' | gpg --import && if z=$(curl -s 'https://install.zerotier.com/' | gpg); then echo "$z" | sudo bash; fi
...
*** Success! You are ZeroTier address [ abcdefghij ].
```

Then optionally connect to an existing network:

```
$ sudo zerotier-cli join <NETWORK_ID>
```

### SSH

SSH keys can also be setup by using the following variables:

```
$ cat vars.yaml
---
stick_user: steve
stick_ssh_keys_setup: true
stick_ssh_keys:
  - <SSH_KEY_PUBLIC_1>
  - <SSH_KEY_PUBLIC_2>
$ ansible-playbook -i inventory_stick.ini playbook_linux_stick.yaml --become --ask-become-pass -e @vars.yaml
```
### Wine Staging

Wine Staging provides experimental patches on-top of the latest Wine development release. This can be installed by using the project [ekultails/ansible_role_wine](https://github.com/ekultails/ansible_role_wine) or manually by following the [download instructions](https://wiki.winehq.org/Download) provided by WineHQ.

```
$ cat playbook_wine.yaml
---
- hosts: stick
  roles:
    - name: wine
$ cat vars.yaml
---
use_distro_packages: false
wine_release: staging
$ ansible-playbook -i inventory_stick.ini playbook_wine.yaml --become --ask-become-pass -e @vars.yaml
```

### Steam

Steam is automatically installed via the `linux_stick` Ansible role. It can also be manually installed by running: `$ sudo apt-get install steam`. Once installed and opened, enable Proton for all Windows games. This will allow them to run in Linux. For more information about Proton, [read this starter guide](https://www.gamingonlinux.com/2019/07/a-simple-guide-to-steam-play-valves-technology-for-playing-windows-games-on-linux). Check the compatibility rating for games on Steam by using [ProtonDB](https://www.protondb.com/).

```
Settings > Steam Play > Enable Steam Play for Support Titles > Use this tool instead of game-specific selections from Steam > Compatibility tool: > (select the latest "Proton" version available) > OK
```

### Proton GE

Both the stable and Media Foundation versions of Proton Glorious Eggroll (GE) are installed by the ``linux_stick`` Ansible role. These provide lots of additional patches ontop of Proton (including Wine Staging patches) to ensure that Windows games have the highest possibility of working on Linux.

### Linux Kernel

#### Hardware Enablement

By default, Ubuntu 20.04 has the Hardware Enablement repositories enabled. This provides a newer version of the Linux kernel to improve hardware compatibility.

-  20.04.1 = 5.4
-  20.04.2 = 5.8

#### Freeze Linux Kernel Version

Some of the drivers installed via DKMS may not work when updating the Linux kernel. This is especially true when upgrading to a new major version.

Pause the kernel updates:

```
$ sudo apt-mark hold linux-image-generic linux-headers-generic
```

Allow kernel updates again in the future after verifying the new update will work:

```
$ sudo apt-mark unhold linux-image-generic linux-headers-generic
```

### Google Chrome

Google Chrome is installed by the ``linux_stick`` Ansible role. It is useful for remote troubleshooting via the use of the [Chrome Remote Desktop](https://remotedesktop.google.com/).

### Lutris

Lutris is installed by the ``linux_stick`` Ansible role. Lutris helps to install and configure non-Steam games. It also installs other useful dependencies including GameMode.

### Wayland

Wayland is disabled by the ``linux_stick`` Ansible role. Xorg provides better framerates and stability for gaming.

### FreeOffice

FreeOffice is installed by the ``linux_stick`` Ansible role. It provides a complete office suite of tools that are very familiar to Microsoft Office users.

### Dock

Re-organize the applications on the dock to be more relevant.

- "Add to Favorites"
    - Google Chrome
    - Lutris
    - Settings
- "Remove from Favorites"
    - Firefox
    - Rhythombox
    - Thunderbird Mail

Change the dock to be in a macOS position of the bottom (instead of the left): `Settings > Appearance > Dock > Position on screen > Bottom`.

### Mac Boot

Boot the Mac into the flash drive by pressing and releasing the power button. Then hold down the "Option" key (or the "Alt" key on a Windows keyboard) to access the Mac bootloader. Select the "EFI Boot" device.

## Tips

- Test booting up the flash drive first before buying speakers, a Bluetooth adapter, a WiFi adapter, and/or other hardware. Depending on the Mac, the built-in hardware may work out-of-the-box.
- Buy a Bluetooth and/or WiFi adapater that is natively supported by the Linux kernel or is at least packaged for Ubuntu. Almost every USB speaker will work on Linux.
- Consider buying an external SSD instead of a flash drive for a longer life-span, more storage, and faster speeds.
- Plug everything into the USB-C hub before connecting it to the comptuer and turning the computer on.
- Do NOT move the USB-C hub after plugging it in and booting up Linux. It can easily disconnect leading to a corrupt file system.
- Avoid using Flatpak and Snap packages. These use a lot of additional space compared to native system packages. Programs packaged this way are also slower.
- Delete old Btrfs backups when the flash drive is running low on storage space.
    - `$ sudo apt-btrfs-snapshot list` `$ sudo apt-btrfs-snapshot delete <SNAPSHOT>`

## License

GPLv3
