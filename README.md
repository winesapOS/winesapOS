# Mac Linux Gaming Stick

Linux gaming, on a stick, designed for Mac enthusiasts. This is an opinonated take on creating a portable USB flash drive with Linux installed to enable gaming on a Mac (or any computer) via Steam and Proton/Wine.

**TABLE OF CONTENTS**

* [Mac Linux Gaming Stick](#mac-linux-gaming-stick)
   * [Why?](#why)
   * [Goals](#goals)
   * [Target Hardware](#target-hardware)
   * [Planning](#planning)
   * [Setup](#setup)
      * [Linux Installation](#linux-installation)
         * [Ubuntu 20.04](#ubuntu-2004)
      * [Legacy BIOS Boot](#legacy-bios-boot)
      * [Optimize the File Systems](#optimize-the-file-systems)
      * [BtrFS Backups](#btrfs-backups)
         * [Automatic](#automatic)
         * [Manual](#manual)
      * [WiFi Driver (88x2bu)](#wifi-driver-88x2bu)
      * [Packages](#packages)
      * [VPN (ZeroTier)](#vpn-zerotier)
      * [SSH](#ssh)
      * [Wine Staging](#wine-staging)
      * [Proton GE](#proton-ge)
      * [Linux Kernel](#linux-kernel)
         * [Hardware Enablement (5.4)](#hardware-enablement-54)
         * [Mainline (5.8)](#mainline-58)
      * [Google Chrome](#google-chrome)
      * [Lutris](#lutris)
      * [Wayland](#wayland)
      * [FreeOffice](#freeoffice)
      * [Mac Boot](#mac-boot)
   * [License](#license)

## Why?

mac OS limitations:

- No 32-bit support. The latest version is now 64-bit only. As of August 2020, there are [less than 70 full PC games](https://www.macgamerhq.com/opinion/32-bit-mac-games/) (i.e., not apps) on mac OS that are available as 64-bit.
- As of August 2020, [77% of Steam games run on Linux](https://www.protondb.com/).
- Steam Play's Proton is only [supported on Linux](https://github.com/ValveSoftware/Proton/wiki/Requirements) ([not mac OS](https://github.com/ValveSoftware/Proton/issues/1344)).
- Old and incomplete implementation of OpenGL.
- No native Vulkan support.
    - MoltenVK is [incomplete due to missing functionality in Apple's Metal API](https://github.com/KhronosGroup/MoltenVK/issues/203).
- Linux has better gaming support because it supports 32-bit applications, DirectX (via Wine with WineD3D, DXVK, and/or Vkd3d), OpenGL, and Vulkan.

## Goals

Goals:

- Portability. The flash drive should be bootable on both BIOS and UEFI systems.
- Gaming support out-of-the-box.
- Minimze writes to the flash drive to improve its longevity.
- Full backups via BtrFS and Snapper.
- Automatic operating system updates are disabled. Updates should always be intentional and planned.
- Battery optimizations.
- As much reproducible automation as possible via Ansible.
    - Any manual steps will be documented in this README file.

Not planned to support:

- Built-in sound.
- Built-in WiFi and/or Bluetooth.

It is easier and more reliable to buy additional hardware and use a USB-C hub than to rely on hacky Linux drivers for Mac. Workarounds do exist for [sound](https://github.com/davidjo/snd_hda_macbookpro) and [WiFi](https://gist.github.com/roadrunner2/1289542a748d9a104e7baec6a92f9cd7#gistcomment-3080934).

## Target Hardware

Mac:

- 2015-2017 MacBook.
- 2016-2017 MacBook Pro.

This guide should work for older models of Macs as well. Compatibility may vary with the latest Mac hardware.

Suggested hardware to buy:

- USB-C hub with USB-A ports, a 3.5mm audio port, and USB-C power delivery.
    - $US 35 = 10 in 1 USB-C HUB to HDMI+VGA+RJ45+USB3.0x3+SD/TF Card Reader+Audio+[USB-C ]P[ower]D[elivery]
- USB flash drive with a fast read speed.
    - $US 20 = Samsung FIT Plus USB 3.1 Flash Drive 128GB B07D7PDLXC
        - 300 MB/s read and 60 MB/s write.
        - 119 GB of usable space.
- WiFi USB and Bluetooth (2-in-1) USB adapter.
    - $US 15 = EZCast 1300Mbps Dual Band Wireless Adapter EZC-5300BS (RTL8822B) UPC 4712899900373
        - Requires the `88x2bu` Linux driver.
- USB speakers.
    - $US 15 = LIELONGREN USB Computer Speaker B088CSDZQM

## Planning

- Test with Ubuntu 20.04 and build automation using Ansible.
    - Install Linux onto a USB flash drive.
    - Optimize the file systems to decrease writes which will increse the longevity of the flash drive.
    - Automatic BtrFS backups.
    - Setup and configure the system for gaming.
    - Optimize Linux for maximum battery usage on a laptop.
    - Boot the flash drive on a Mac.
    - Switch to Linux kernel 5.8.

## Setup

### Linux Installation

It is recommended to use a UEFI virtual machine with USB passthrough to setup the USB flash drive. This will avoid ruining the bootloader and/or storage devices on the actual computer.

virt-manager:

```
File > New Virtual Machine > Local install media (ISO image or CDROM) > Forward > Choose ISO or CDROM install media > Browse... > ubuntu-20.04.1-desktop-amd64.iso > Forward > Forward (keep default CPU and RAM settings) > uncheck "Enable storage for this virtual machine" > Forward > check "Customize configuration before installation" > Finish > Add Hardware > USB Host Device > (select the device, in my case it was "004:004 Silicion Motion, Inc. - Taiwan (formerly Feiya Technology Corp.) Flash Drive") > Finish > Boot Options > (check the "USB" option to allow it to be bootable to test the installation when it is done) > Apply > Begin Installation
```

The elementary OS and Ubuntu installers are extremely limited when it comes to custom partitions. It is not possible to specify a BIOS or GPT partition table, customize BtrFS subvolumes, or set partition flags. Instead, use the `parted` command to format the flash drive. DO AT YOUR OWN RISK. DO NOT USE THE WRONG DEVICE.

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
(parted) quit
```

Next, select and download a Linux distribution to install. These are recommended for gaming and having a similar feel to mac OS:

- [Manjaro GNOME](https://manjaro.org/downloads/official/gnome/)
- [Ubuntu 20.04](https://ubuntu.com/download/desktop)
    - [elementary OS 6](https://elementary.io/)
    - [Pop!\_OS 20.04](https://pop.system76.com/)

#### Ubuntu 20.04

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

Also configure the root and home file systems to use new mount options that will lower the amount of writes and evenly spread the wear on the flash drive: `noatime,nodiratime,ssd_spread` (ssd_spread is for BtrFS only).

```
$ sudo vim /etc/fstab
UUID=<UUID>    /        btrfs    defaults,subvol=@,noatime,nodiratime,ssd_spread        0    1
UUID=<UUID>    /home    btrfs    defaults,subvol=@home,noatime,nodiratime,ssd_spread    0    2
```

### BtrFS Backups

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

Install and configure `grub-btrfs`. This will add a new GRUB menu entry that shows all of the available BtrFS snapshots.

```
$ git clone https://github.com/Antynea/grub-btrfs.git
$ cd grub-btrfs/
$ sudo make install
$ sudo vim /etc/default/grub-btrfs/config
GRUB_BTRFS_SUBMENUNAME="Buttery Backups"
```

Install the `apt-btrfs-snapshot` package. This will automatically take a BtrFS snapshot of the root `/` file system whenever `apt` makes a change to the system.

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

### Proton GE

Both the stable and Media Foundation versions of Proton Glorious Eggroll (GE) are installed by the ``linux_stick`` Ansible role. These provide lots of additional patches ontop of Proton (including Wine Staging patches) to ensure that Windows games have the highest possibility of working on Linux.

### Linux Kernel

#### Hardware Enablement (5.4)

The Hardware Enablement kernel provided by Ubuntu 20.04.1 is 5.4. Newer versions of the kernel and display drivers should be installed.

```
$ sudo apt-get install --install-recommends linux-generic-hwe-20.04 linux-headers-generic-hwe-20.04 xserver-xorg-hwe-20.04
```

This error may occur when doing future upgrades:

```
The following packages have been kept back:
  linux-generic-hwe-20.04 linux-headers-generic-hwe-20.04
  linux-image-generic-hwe-20.04
0 upgraded, 0 newly installed, 0 to remove and 3 not upgraded.
```

Force the update of thse packages:

```
$ sudo apt-get --with-new-pkgs upgrade
```

#### Mainline (5.8)

For the best compatibility with hardware, a newer kernel is required. It is possible to manually [download and install the latest mainline Linux kernel](https://www.how2shout.com/linux/install-linux-5-8-kernel-on-ubuntu-20-04-lts/).

```
$ cd ~/Downloads/
$ curl -LO https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.8/amd64/linux-image-unsigned-5.8.8-050808-generic_5.8.8-050808.202009091435_amd64.deb
$ curl -LO https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.8/amd64/linux-modules-5.8.8-050808-generic_5.8.8-050808.202009091435_amd64.deb
$ curl -LO https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.8/amd64/linux-headers-5.8.8-050808-generic_5.8.8-050808.202009091435_amd64.deb
$ curl -LO https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.8.8/amd64/linux-headers-5.8.8-050808_5.8.8-050808.202009091435_all.deb
$ sudo dpkg -i ~/Downloads/linux-*.deb
```

The `rtl88x2bu` WiFi driver [requires a patch](https://github.com/cilynx/rtl88x2bu/issues/72#issuecomment-670595246) to work with Linux kernel 5.8.

```
$ git clone https://github.com/cilynx/rtl88x2bu.git
$ cd rtl88x2bu
$ curl -LO https://github.com/cilynx/rtl88x2bu/pull/58.patch
$ git apply 58.patch
$ VER=$(sed -n 's/\PACKAGE_VERSION="\(.*\)"/\1/p' dkms.conf)
$ sudo dkms remove rtl88x2bu/${VER} --all
$ sudo rsync -rvhP ./ /usr/src/rtl88x2bu-${VER}
$ sudo dkms add -m rtl88x2bu -v ${VER}
$ sudo dkms build -m rtl88x2bu -v ${VER}
```

Install the `88x2bu` kernel module for [every Linux kernel that is installed](https://askubuntu.com/questions/53364/command-to-rebuild-all-dkms-modules-for-all-installed-kernels/174017#174017).

```
$ sudo su -
# dkms status | sed s/,//g | awk '{print "-m",$1,"-v",$2}' | while read line; do ls /var/lib/initramfs-tools | xargs -n 1 dkms install $line -k; done
# modprobe 88x2bu
```

### Google Chrome

Google Chrome is installed by the ``linux_stick`` Ansible role. It is useful for remote troubleshooting via the use of the [Chrome Remote Desktop](https://remotedesktop.google.com/).

### Lutris

Lutris is installed by the ``linux_stick`` Ansible role. Lutris helps to install and configure non-Steam games. It also installs other useful dependencies including GameMode.

### Wayland

Wayland is disabled by the ``linux_stick`` Ansible role. Xorg provides better framerates and stability for gaming.

### FreeOffice

FreeOffice is installed by the ``linux_stick`` Ansible role. It provides a complete office suite of tools that are very familiar to Microsoft Office users.

### Mac Boot

Boot the Mac into the flash drive by pressing and releasing the power button. Then hold down the "Option" key (or the "Alt" key on a Windows keyboard) to access the Mac bootloader. Select the "EFI Boot" device.

## License

GPLv3
