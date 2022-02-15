# winesapOS

***Game with Linux anywhere, no installation required!***

winesapOS makes it easy to setup Linux and play games off an external drive.

This project provides an opinionated installation of Linux. It can be used on a flash drive, SD card, HDD, SSD, or any other storage device. Both internal and external devices are supported. The [release images](https://github.com/LukeShortCloud/winesapOS/releases) are based on Arch Linux and the KDE Plasma desktop environment. Software for various games launchers are pre-installed. Additional drivers are installed to support Macs with Intel processors.

**TABLE OF CONTENTS**

* [winesapOS](#winesapos)
   * [macOS Limitations](#macos-limitations)
   * [Features](#features)
   * [Usage](#usage)
      * [Requirements](#requirements)
      * [Setup](#setup)
          * [Secure Image](#secure-image)
              * [Differences](#differences)
          * [Mac Boot](#mac-boot)
      * [Upgrades](#upgrades)
   * [Tips](#tips)
      * [Getting Started](#getting-started)
      * [Btrfs Backups](#btrfs-backups)
      * [Steam](#steam)
      * [Wireless Keyboard and Mouse](#wireless-keyboard-and-mouse)
      * [VPN (ZeroTier)](#vpn-zerotier)
   * [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)
   * [History](#history)
   * [License](#license)

## macOS Limitations

These are reasons why macOS is inferior compared to Linux when it comes to gaming.

- No 32-bit support. The latest version is now 64-bit only. As of November 2021, there are [1,263 full PC games](https://www.pcgamingwiki.com/wiki/List_of_OS_X_64-bit_games) (i.e., not apps) on macOS that are available as 64-bit. That number is only [2% of the 59,368 games available on Steam](https://store.steampowered.com/search/?category1=998).
- As of November 2021, [83% of reported Steam games run on Linux](https://www.protondb.com/).
- Macs in 2020 have started the move from Intel to Arm-based processors, further lowering the amount of full games it supports natively to almost zero.
- The Apple M1 Arm-based processor has limited graphics capabilities and that are [comparable to integrated graphics offered by AMD and Intel](https://arstechnica.com/gadgets/2020/11/hands-on-with-the-apple-m1-a-seriously-fast-x86-competitor/). These Macs are not designed to be gaming computers.
    - Intel x86_64 games played through the Rosetta 2 compatibility layer have over a [20% performance penalty](https://www.macrumors.com/2020/11/15/m1-chip-emulating-x86-benchmark/).
- Steam Play's Proton is only [supported on Linux](https://github.com/ValveSoftware/Proton/wiki/Requirements) ([not macOS](https://github.com/ValveSoftware/Proton/issues/1344)).
- Old and incomplete implementation of OpenGL.
- No native Vulkan support.
    - MoltenVK is [incomplete due to missing functionality in Apple's Metal API](https://github.com/KhronosGroup/MoltenVK/issues/203).
- Linux has better gaming support because it supports 32-bit applications, DirectX (via Wine with WineD3D, DXVK, and/or Vkd3d), OpenGL, and Vulkan.
- [CrossOver Mac](https://www.codeweavers.com/crossover), a commercial Wine product, is one of the few ways to run games on macOS but has some limitations.
    - It costs money and usually requires a new license yearly.
    - 32-bit Windows application support on 64-bit only macOS versions is still buggy.
    - It is always based on a old stable Wine version that is at least one year behind upstream Wine version.
    - DXVK (DirectX 9-11), via a modified version of MoltenVK, has limited support.
        - MoltenVK does not expose all of the features in Vulkan required by DXVK.
        - MoltenVK only exposes 64-bit Vulkan support. This means that DirectX 11 games that use 32-bit libraries will not work via DXVK.
    - Vkd3d (DirectX 12) will not be supported until at least [2023](https://www.codeweavers.com/blog/cjsilver/2021/12/22/were-getting-there-crossover-support-for-directx-12).
    - Vulkan is not supported.
    - Linux has [kernel-level optimizations](https://www.phoronix.com/scan.php?page=news_item&px=FUTEX2-Bits-In-Locking-Core) for Wine.

## Features

- **Any computer with an AMD or Intel processor can run winesapOS.**
- **All Intel Macs are supported.** Linux works on most Macs out-of-the-box these days. Drivers are pre-installed for newer hardware where native Linux support is missing.
    - [Linux on Mac compatibility guide](https://github.com/Dunedan/mbp-2016-linux).
    - [snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) provides a sound driver for newer Macs with Cirrus sound board chips.
    - [macbook12-spi-driver](https://github.com/roadrunner2/macbook12-spi-driver) provides the Touch Bar driver for newer MacBook Pros.
    - [mbp2018-bridge-drv](https://github.com/MCMrARM/mbp2018-bridge-drv) provides the MacBook Bridge/T2 driver for MacBooks from >= 2018. This allows the keyboard, sound, and touchpad hardware to function properly.
    - WiFi is **NOT** fully supported.
        - Workarounds do exist for WiFi on the [2016-2017 MacBook Pros](https://gist.github.com/roadrunner2/1289542a748d9a104e7baec6a92f9cd7#gistcomment-3080934). However, speeds are reported as being slower.
- **Portability.** The flash drive is bootable on both BIOS and UEFI systems.
- **Persistent storage.** Unlike traditional Linux live media, all storage is persistent and kept upon reboots.
    - Upon the first boot, the root partition is expanded to utilize all available space.
- **Supportability.** Linux is easy to troubleshoot remotely.
    - Access:
        - [Chrome Remote Desktop](https://remotedesktop.google.com/) via [Google Chrome](https://www.google.com/chrome/) can be used to provide remote access similar to Windows RDP.
        - SSH can be accessed via clients on the same [ZeroTier VPN](https://www.zerotier.com/) network.
        - [tmate](https://tmate.io/) makes sharing SSH sessions without VPN connections easy.
    - Tools:
        - [ClamAV](https://www.clamav.net/) is an open source anti-virus scanner.
        - [QDirStat](https://github.com/shundhammer/qdirstat) provides a graphical user interface to view storage space usage.
- **Usability.** Software for typical day-to-day use is provided.
    - [Cheese](https://wiki.gnome.org/Apps/Cheese) for a webcam software.
    - [LibreOffice](https://www.libreoffice.org/) provides an office suite.
    - [Shutter](https://shutter-project.org/) for a screenshot utility.
- **Gaming support** out-of-the-box.
    - [Lutris](https://lutris.net/), [Steam](https://store.steampowered.com/), and [Wine Staging](https://wiki.winehq.org/Wine-Staging) are all installed.
    - [Proton GE](https://github.com/GloriousEggroll/proton-ge-custom) is installed along with the [ge-install-manager](https://github.com/toazd/ge-install-manager) package manager for it.
    - Open source OpenGL and Vulkan drivers are installed for AMD and Intel graphics.
    - [GameMode](https://github.com/FeralInteractive/gamemode) is available to be used to speed up games.
    - ZeroTier VPN can be used to play LAN-only games online with friends.
- **Minimize writes** to the flash drive to improve its longevity.
    - Root file system is mounted with the options `noatime` and `nodiratime` to not write the access times for files and directories.
    - Temporary directories with heavy writes (`/tmp/`, `/var/log/`, and `/var/tmp/`) are mounted as RAM-only file systems.
    - [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) is configured to use volatile (RAM-only) storage for all system logs.
    - Swappiness level is set to 10% (down from the default of 60%).
- **Full backups** via Btrfs.
    - [Snapper](https://github.com/openSUSE/snapper) takes 12 monthly and 1 annual snapshots.
    - Snapper takes a backup whenever the `pacman` package manager is used.
    - [grub-btrfs](https://github.com/Antynea/grub-btrfs) automatically generates a GRUB menu entry for all of the Btrfs backups.
- **No automatic operating system updates.** Updates should always be intentional and planned.
- **Most file systems supported.** Access any storage device, anywhere.
    - APFS
    - Btrfs
    - ext2, ext3, and ext4
    - exFAT
    - FAT12, FAT16, and FAT32
    - HFS and HFS+
    - NTFS
    - ZFS
- **Battery optimizations.**
    - The [auto-cpufreq](https://github.com/AdnanHodzic/auto-cpufreq) service provides automatic power management.
- **Fully automated installation.**

## Usage

### Requirements

Minimum:

- Processor = Dual-core AMD or Intel processor.
- RAM = 4 GiB.
- Graphics = AMD or Intel integrated graphics.
- Storage = 32 GB USB 3.2 Gen 1 (originally called USB 3.0) flash drive.

Recommended:

- Processor = Quad-core AMD or Intel processor.
- RAM = 16 GiB.
- Graphics = AMD discrete graphics card.
- Storage = 512 GB external USB 3.2 Gen 2 (originally called USB 3.1) SSD.

### Setup

1. Download the latest [release](https://github.com/LukeShortCloud/winesapOS/releases) image archive files:
    - Performance (recommended):
        - `winesapos-performance-<VERSION>.img.zip`
        - `winesapos-performance-<VERSION>.img.z01`
        - `winesapos-performance-<VERSION>.img.z02`
    - Secure (for advanced users only):
        - `winesapos-secure-<VERSION>.img.zip`
        - `winesapos-secure-<VERSION>.img.z01`
        - `winesapos-secure-<VERSION>.img.z02`
2. Extract the `winesapos-<VERSION>.img.zip` archive. This will automatically extract all of the other `zip` file parts.
    - Linux: `7z x winesapos-<VERSION>.img.zip`
    - macOS: Use [Keka](https://www.keka.io/).
    - Windows: Use [PeaZip](https://peazip.github.io/).
3. Use [balenaEtcher](https://www.balena.io/etcher/) to flash the image to an external storage device. **WARNING:** This will delete any existing data on that storage device.

Default accounts have a password set that mirror the username:

- winesapOS (major version >= 3)

| Username | Password |
| --- | --- |
| winesap | winesap |
| root | root |

- Mac Linux Gaming Stick (major version < 3)

| Username | Password |
| --- | --- |
| stick | stick |
| root | root |

#### Secure Image

If using the secure image, the default LUKS encryption key is `password` which should be changed after the first boot. Do not do this before the first boot as the default password is used to unlock the partition for it be resized to fill up the entire storage device. Change the LUKS encryption key for the fifth partition.

```
$ sudo cryptsetup luksChangeKey /dev/<DEVICE>5
```

The user account passwords for ``winesap`` (or ``stick`` on older versions) and ``root`` are set to expire immediately. Upon first login, you will be prompted to enter a new password.

##### Differences

These are the main differences between the performance secure images. The performance is focused on speed and ease-of-use. The secure image is recommended for advanced Linux users.

| Feature | Performance | Secure |
| --- | --- | --- |
| CPU Mitigations | No | Yes |
| Encryption | No | Yes (LUKS) |
| Firewall | No | Yes (Firewalld) |
| Linux Kernel Updates | No | Yes |
| Passwords Require Reset | No | Yes |

#### Mac Boot

Boot the Mac into the flash drive by pressing and releasing the power button. Then hold down the `OPTION` key (or the `ALT` key on a Windows keyboard) to access the Mac bootloader. Select the "EFI Boot" device.

**IMPORTANT** Any [Mac with an Apple T2 Security Chip](https://support.apple.com/en-us/HT208862), which are all Macs made in and after 2018, needs to [allow booting from external storage](https://support.apple.com/en-us/HT208198):

1. Turn on the Mac and immediately hold both the `COMMAND` and `r` keys to enter recovery mode.
2. Utilities > Startup Security Utility
    - Secure Boot = No Security (Does not enforce any requirements on the bootable OS.)
    - External Boot = Allow booting from external media (Does not restrict the ability to boot from any devices.)

### Upgrades

Upgrades are supported between all minor releases via an upgrade script. **USE AT YOUR OWN RISK!** For example, it is supported to go from 2.0.0 to 2.1.0 but not from 2.Y.Z to 3.Y.Z. This will make major changes to the operating system and could lead to data loss. Where it makes sense, features are backported from newer versions of winesapOS. This script is completely optional.

```
$ curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/2.2.0/scripts/upgrade-arch-linux.sh | sudo zsh
```

## Tips

### Getting Started

- Test booting up the flash drive first before buying speakers, a Bluetooth adapter, a WiFi adapter, and/or other hardware. Depending on the Mac, the built-in hardware may work out-of-the-box.
- Temporarily allow the `brcmfmac` and `brcmutil` drivers to see if the built-in WiFi will work. Remove the relevant entries from `/etc/modprobe.d/winesapos.conf` and then use `modprobe` to manually load the drivers.
- Plug additional hardware into a USB hub. Connect the USB hub to the computer before booting.
- Do NOT move the USB hub after plugging it in and booting up Linux. It can easily disconnect leading to a corrupt file system.
- Consider buying an external SSD instead of a flash drive for a longer life-span, more storage, and faster speeds.
- Avoid using Flatpak and Snap packages. These use a lot of additional space compared to native system packages. Programs packaged this way are also slower.
- Delete old Btrfs backups when the flash drive is running low on storage space.

    ```
    $ sudo snapper list
    $ sudo snapper delete <SNAPSHOT_NUMBER>
    ```

- Enable Proton for all Windows games. This will allow them to run in Linux. For more information about Proton, [read this starter guide](https://www.gamingonlinux.com/2019/07/a-simple-guide-to-steam-play-valves-technology-for-playing-windows-games-on-linux). Check the compatibility rating for games on Steam by using [ProtonDB](https://www.protondb.com/).

    ```
    Settings > Steam Play > Enable Steam Play for Support Titles > Use this tool instead of game-specific selections from Steam > Compatibility tool: > (select the latest "Proton" version available) > OK
    ```

### Btrfs Backups

Both the root `/` and `/home` directory have automatic backups/snapshots configured by Snapper. A new backup will be taken every month for 12 months. Separately, a new backup will be taken once every year. The root directory will also have a backup taken whenever `pacman` is used to install or remove a package.

During boot, GRUB will have a "Arch Linux snapshots" section that will allow booting from a root directory snapshot. This will not appear on first boot because no backups have been taken yet. After a backup has been taken, the GRUB configuration file needs to be regenerated to scan for the new backups.

Manually rebuild the GRUB configuration file to load the latest snapshots:

```
$ sudo grub-mkconfig -o /boot/grub/grub.cfg
```

View the available backups:

```
$ sudo snapper -c root list
$ sudo snapper -c home list
```

Manually create a new backup:

```
$ sudo snapper -c <CONFIG> create
```

Manually delete a backup:

```
$ sudo snapper -c <CONFIG> delete <BACKUP_NUMBER>
```

### Steam

Launch and prefer `steam-runtime` over `steam-native`. It bundles all of the libraries required for Steam to work. In case that has issues, `steam-native` is provided as an alternative for testing purposes. It will use the system libraries instead.

### Wireless Keyboard and Mouse

Some wireless keyboards and mice in Linux have random lag. This can be worked around by [forcing the polling frequency to be 125 Hz](https://askubuntu.com/questions/1130869/keyboard-and-mouse-stuttering-on-ubuntu-18-04-with-a-new-laptop/1130870#1130870).

Temporary fix:

```
$ echo 1 | sudo tee /sys/module/usbhid/parameters/kbpoll
$ echo 1 | sudo tee /sys/module/usbhid/parameters/mousepoll
```

Permanent fix:

```
$ sudo vim /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet udev.log_priority=3 usbhid.kbpoll=1 usbhid.mousepoll=1"
$ sudo grub-mkconfig -o /boot/grub/grub.cfg
```

According to [here](https://utcc.utoronto.ca/~cks/space/blog/linux/USBMousePollingRate), these are all of the possible values that can be tested.

* 0 = Use the default frequency reported by the mouse.
* 1 = 125 Hz.
* 2 = 500 Hz.

### VPN (ZeroTier)

A VPN is required for LAN gaming online. Hamachi is reported to no longer work on newer versions of [Arch Linux](https://aur.archlinux.org/packages/logmein-hamachi/) and [Ubuntu](https://community.logmein.com/t5/LogMeIn-Hamachi-Discussions/Hamachi-randomly-disconnects-on-Ubuntu-20-04/td-p/222430). Instead, use the free and open source ZeroTier VPN service.

**Host**

1. Only one person needs to create a [ZeroTier account](https://my.zerotier.com/).
2. They must then create a [ZeroTier network](https://www.stratospherix.com/support/setupvpn_01.php).
    1. Log into [ZeroTier Central](https://my.zerotier.com/).
    2. Select "[Networks](https://my.zerotier.com/network)".
    3. Select "Create A Network".
    4. Select the "Network ID" or "Name" of the new network to modify the settings.
        - Either (1) set the "Access Control" to "Public" or (2) use this settings page to manually authorize connected clients to be able to communicate on the network.
        - Take note of the "Network ID". Send this string to your friends who will connect to the VPN.

**Clients**

1. Start the ZeroTier VPN service.

    ```
    $ sudo systemctl enable --now zerotier-one
    ```

2. Connect to the ZeroTier network.

    ```
    $ sudo zerotier-cli join <NETWORK_ID>
    ```

## Frequently Asked Questions (FAQ)

- **What is the relevance of the word "winesap" in winesapOS?**
    - It is a type of apple which signifies how we develop on Macs and ship drivers for them. It also has the word "wine" in it which is the [name of the project](https://www.winehq.org/) used to enable Windows gaming on Linux.
- **Is this the Mac Linux Gaming Stick project?**
    - Yes. Version 1 and 2 of the project were called Mac Linux Gaming Stick. In version 3, we rebranded to winesapOS.
- **What makes this different than adding persistent storage to a live CD with [Universal USB Installer or YUMI](https://www.pendrivelinux.com/)?**
    - Having persistent storage work via these hacky methods can be hit-or-miss depending on the distribution. winesapOS was built from the ground-up to have persistent storage. It also features automatic backups, various gaming tools, has support for Macs, and more.
- **Are Arm Macs supported?**
    - No. In general, Linux support for them are still a work-in-progress.
- **Is winesapOS a Linux distribution?**
    - No. The project takes an existing Arch Linux distribution and does an opinionated installation of it.
- **Do I have to install winesapOS?**
    - No. No installation is required. Flash a [release image](https://github.com/LukeShortCloud/winesapOS/releases) to a drive and then boot from it. Everything is already installed and configured.
- **Can anyone build winesapOS?**
    - Yes. Refer to the [DEVELOPER.md](https://github.com/LukeShortCloud/winesapOS/blob/main/DEVELOPER.md) documentation.

## History

| Release Version/Tag | Project Name | Operating System | Desktop Environment | Release Images |
| ------------------- | ------------ | ---------------- | ------------------- | -------------- |
| 3.0.0 | winesapOS | Steam OS 3.0 | KDE Plasma | Performance and Secure |
| 3.0.0-alpha.0 | winesapOS | Arch Linux | KDE Plasma | Performance and Secure |
| 2.2.0 | Mac Linux Gaming Stick | Manjaro | Cinnamon | Performance and Secure |
| 2.0.0 | Mac Linux Gaming Stick | Manjaro | Cinnamon | Performance |
| 1.0.0 | Mac Linux Gaming Stick | Ubuntu 20.04 | Cinnamon | None |

## License

GPLv3
