# winesapOS <img src="https://user-images.githubusercontent.com/10150374/158224898-bdb4ad3a-ad09-478c-a09d-d313feeb8713.png" width=15% height=15%>

***Game with Linux anywhere, no installation required!***

![winesapOS_3_Desktop_Screenshot 720p](https://user-images.githubusercontent.com/10150374/157773891-3823ffb7-8ea9-4528-9988-563da174cd5a.jpg)

winesapOS makes it easy to setup Linux and play games off an internal or portable external drive.

This project provides an opinionated installation of Linux. It can be used on a flash drive, SD card, HDD, SSD, NVMe, or any other storage device. Both internal and external devices are fully supported. The [release images](https://github.com/LukeShortCloud/winesapOS/releases) are based on SteamOS 3 and the KDE Plasma desktop environment to align with what Valve's [Steam Deck](https://store.steampowered.com/steamdeck/) uses. Software for various games launchers are pre-installed. Additional drivers are installed to support Macs with Intel processors.

**TABLE OF CONTENTS**

* [winesapOS](#winesapos)
   * [macOS Limitations](#macos-limitations)
   * [Features](#features)
       * [General](#general)
       * [Mac Support](#mac-support)
       * [Comparison with SteamOS](#comparison-with-steamos)
   * [Usage](#usage)
      * [Requirements](#requirements)
      * [Setup](#setup)
          * [Secure Image](#secure-image)
              * [Differences](#differences)
          * [Mac Boot](#mac-boot)
      * [Upgrades](#upgrades)
   * [Tips](#tips)
      * [Getting Started](#getting-started)
      * [No Sound (Muted Audio)](#no-sound-muted-audio)
      * [Btrfs Backups](#btrfs-backups)
      * [Steam](#steam)
      * [VPN (ZeroTier)](#vpn-zerotier)
   * [Troubleshooting](#troubleshooting)
       * [Release Image Zip Files](#release-image-zip-files)
       * [Root File System Resizing](#root-file-system-resizing)
       * [Some Package Updates are Ignored](#some-package-updates-are-ignored)
       * [Pamac Shows Ignored Packages](#pamac-shows-ignored-packages)
       * [Available Storage Space is Incorrect](#available-storage-space-is-incorrect)
       * [Two or More Set Ups of winesapOS Cause an Unbootable System](#two-or-more-set-ups-of-winesapos-cause-an-unbootable-system)
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
    - Vulkan support via MoltenVK is incomplete due to missing functionality in Apple's Metal API.
    - DXVK (DirectX 9-11), via a modified version of MoltenVK, has limited support.
        - MoltenVK does not expose all of the features in Vulkan required by DXVK.
        - MoltenVK only exposes 64-bit Vulkan support. This means that DirectX 11 games that use 32-bit libraries will not work via DXVK.
    - Vkd3d (DirectX 12) will not be supported until at least [2023](https://www.codeweavers.com/blog/cjsilver/2021/12/22/were-getting-there-crossover-support-for-directx-12).
    - Linux has [kernel-level optimizations](https://www.phoronix.com/scan.php?page=news_item&px=FUTEX2-Bits-In-Locking-Core) for Wine.

## Features

### General

- **Any computer with an AMD or Intel processor can run winesapOS.**
- **Portability.** The drive bootable on both BIOS and UEFI systems.
- **Persistent storage.** Unlike traditional Linux live media, all storage is persistent and kept upon reboots.
    - Upon the first boot, the root partition is expanded to utilize all available space.
- **Supportability.** Linux is easy to troubleshoot remotely.
    - Access:
        - [Chrome Remote Desktop](https://remotedesktop.google.com/) via [Google Chrome](https://www.google.com/chrome/) can be used to provide remote access similar to Windows RDP.
        - SSH can be accessed via clients on the same [ZeroTier VPN](https://www.zerotier.com/) network.
        - [tmate](https://tmate.io/) makes sharing SSH sessions without VPN connections easy.
    - Tools:
        - [ClamAV](https://www.clamav.net/), and the GUI front-end [Clamtk](https://github.com/dave-theunsub/clamtk), is an open source anti-virus scanner.
        - [QDirStat](https://github.com/shundhammer/qdirstat) provides a graphical user interface to view storage space usage.
- **Usability.** Software for typical day-to-day use is provided.
    - [BalenaEtcher](https://www.balena.io/etcher/) for an image flashing utility.
    - [Blueman](https://github.com/blueman-project/blueman) for a Bluetooth pairing client.
    - [Bottles](https://usebottles.com/) for installing any Windows program.
    - [Discord](https://discord.com/) for a gaming chat client.
    - [Dolphin](https://apps.kde.org/dolphin/) (KDE Plasma) or [Nemo](https://github.com/linuxmint/nemo) (Cinnamon) = A file manager.
    - [Cheese](https://wiki.gnome.org/Apps/Cheese) for a webcam software.
    - [Firefox ESR](https://support.mozilla.org/en-US/kb/switch-to-firefox-extended-support-release-esr) for a stable web browser.
    - [Firewall](https://firewalld.org/) (secure image) provides a GUI for managing firewalld.
    - [Google Chrome](https://www.google.com/chrome/) for a newer web browser.
    - [Gwenview](https://apps.kde.org/gwenview/) (KDE Plasma) or [Pix](https://community.linuxmint.com/software/view/pix) (Cinnamon) for an image gallery application.
    - [KeePassXC](https://keepassxc.org/) for a cross-platform password manager.
    - [LibreOffice](https://www.libreoffice.org/) provides an office suite.
    - [Open Broadcaster Software (OBS) Studio](https://obsproject.com/) for a recording and streaming utility.
    - [PeaZip](https://peazip.github.io/) for an archive/compression utility.
    - [Shutter](https://shutter-project.org/) for a screenshot utility.
    - [Terminator](https://terminator-gtk3.readthedocs.io/en/latest/) for a terminal emulator.
    - [Transmission](https://transmissionbt.com/) for a torrent client.
    - [VeraCrypt](https://www.veracrypt.fr/en/Home.html) for a cross-platform encryption utility.
    - [VLC](https://www.videolan.org/) for a media player.
    - [ZeroTier GUI](https://github.com/tralph3/ZeroTier-GUI) for a VPN utility for online LAN gaming.
- **Gaming support** out-of-the-box.
    - Game launchers:
        - [Steam](https://store.steampowered.com/).
        - [Heroic Games Launcher](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher) for Epic Games Store games.
        - [MultiMC](https://multimc.org/) for vanilla and modded Minecraft: Java Edition.
        - [Lutris](https://lutris.net/) for all other games.
    - Wine:
        - [Wine GE](https://github.com/GloriousEggroll/wine-ge-custom) for running Windows applications and games without a game launcher.
        - [Proton GE](https://github.com/GloriousEggroll/proton-ge-custom) is installed along with the ProtonUp-Qt package manager for it. This provides better Windows games compatibility in Steam.
    - [GameMode](https://github.com/FeralInteractive/gamemode) is available to be used to speed up games.
    - [Gamescope](https://github.com/Plagman/gamescope) for helping play older games with frame rate or resolution issues.
    - [MangoHUD](https://github.com/flightlessmango/MangoHud) for benchmarking OpenGL and Vulkan games.
    - [GOverlay](https://github.com/benjamimgois/goverlay) is a GUI for managing Vulkan overlays including MangoHUD, ReplaySorcery, and vkBasalt.
    - [Ludusavi](https://github.com/mtkennerly/ludusavi) is a game save files manager.
    - [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) for managing Steam Play compatibility tools.
    - ZeroTier VPN can be used to play LAN-only games online with friends.
    - Open source OpenGL and Vulkan drivers are installed for AMD and Intel graphics.
- **Steam Deck look and feel**.
    - Bootloader uses the [Steam Big Picture mode GRUB theme](https://github.com/LegendaryBibo/Steam-Big-Picture-Grub-Theme) by [LegendaryBibo](https://github.com/LegendaryBibo).
    - Desktop Steam client runs with the windowed Steam Deck UI.
    - KDE Plasma desktop environment uses Valve's Vapor theme.
- **Minimize writes** to the drive to improve its longevity.
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
    - XFS
    - ZFS
- **Battery optimizations.**
    - The [auto-cpufreq](https://github.com/AdnanHodzic/auto-cpufreq) service provides automatic power management.
- **Fully automated installation.**

### Mac Support

**All Intel Macs are supported.** Linux works on most Macs out-of-the-box these days. Drivers are pre-installed for newer hardware where native Linux support is missing.

| Hardware | Supported | Third-Party Driver(s) |
| -------- | --------- | --------- |
| Keyboard | Yes | [mbp2018-bridge-drv](https://github.com/MCMrARM/mbp2018-bridge-drv) |
| Mouse | Yes | [mbp2018-bridge-drv](https://github.com/MCMrARM/mbp2018-bridge-drv) |
| NVMe | Yes | [mbp2018-bridge-drv](https://github.com/MCMrARM/mbp2018-bridge-drv) |
| Sound | Yes | [mbp2018-bridge-drv](https://github.com/MCMrARM/mbp2018-bridge-drv), [snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro), and [snd-hda-codec-cs8409](https://github.com/egorenar/snd-hda-codec-cs8409) |
| Touch Bar | Yes | [mbp2018-bridge-drv](https://github.com/MCMrARM/mbp2018-bridge-drv) and [macbook12-spi-driver](https://github.com/roadrunner2/macbook12-spi-driver) |
| Bluetooth | Yes | None |
| WiFi | Partial | None |

The [mbp2018-bridge-drv](https://github.com/MCMrARM/mbp2018-bridge-drv) driver provides support for the Apple T2 security chip found on newer Macs. Without this, no hardware would work on Linux.

Although we do not provide any additional drivers for wider WiFi support on Macs, the built-in Linux kernel drivers do support it for some devices.

For more information about Linux support on Macs, refer to the [Linux on MacBook Pro compatibility guide](https://github.com/Dunedan/mbp-2016-linux).

### Comparison with SteamOS

| Features | SteamOS 3 | winesapOS 3 |
| --- | --- | --- |
| SteamOS packages | Yes | Yes |
| Graphics drivers | AMD | AMD, Intel, and NVIDIA |
| Read-only file system | Yes | No |
| Encrypted file system | No | Yes (secure image) |
| File system backup type | A/B partitions | Btrfs snapshots |
| Number of possible file system backups | 1 | Unlimited |
| Package managers (CLI) | pacman, yay, flatpak | pacman, yay, flatpak, snap |
| Package manager (GUI) | Discover | Pamac |
| Update type | Image-based | Package manager |
| Number of installed packages | Small | Large |
| Game launchers | Steam | Steam, Heroic Games Launcher, MultiMC, and Lutris |
| Linux kernels | Neptune (5.13) | Neptune (5.13) and Linux LTS (5.15) |
| Additional Mac drivers | No | Yes |
| Desktop environment | Plasma | Plasma |
| Desktop theme | Vapor | Vapor |
| AMD FSR | Global | Per-game |
| Gamescope | Global | Per-game |
| Proton | Official | Official and GE-Proton |
| Game controller support* | Large | Small |
| exFAT flash drive storage | No | Yes (16 GB) |

*A future minor release of winesapOS 3 is planned to expand controller compatibility.

## Usage

### Requirements

Minimum:

- Processor = Dual-core AMD or Intel processor.
- RAM = 4 GiB.
- Graphics = AMD, Intel, or NVIDIA graphics device.
- Storage = 32 GB USB 3.2 Gen 1 (USB 3.0) flash drive.

Recommended:

- Processor = Quad-core AMD or Intel processor.
- RAM = 16 GiB.
- Graphics = AMD discrete graphics card.
- Storage
    - Internal = 512 GB NVMe SSD.
    - External = 512 GB USB 3.2 Gen 2 (USB 3.1) SSD.

### Setup

1. Download the latest [release](https://github.com/LukeShortCloud/winesapOS/releases) image archive files. These zip files and the extracted image will be large. In a future release, we will provide a minimal image that is significantly smaller.
    - Performance (recommended) = Requires 40 GiB of free space to download and extract.
        - `winesapos-performance-<VERSION>.img.zip`
        - `winesapos-performance-<VERSION>.img.z01`
        - `winesapos-performance-<VERSION>.img.z02`
        - `winesapos-performance-<VERSION>.img.z03`
        - `winesapos-performance-<VERSION>.img.z04`
    - Secure (for advanced users only) = Requires 50 GiB of free space to download and extract.
        - `winesapos-secure-<VERSION>.img.zip`
        - `winesapos-secure-<VERSION>.img.z01`
        - `winesapos-secure-<VERSION>.img.z02`
        - `winesapos-secure-<VERSION>.img.z03`
        - `winesapos-secure-<VERSION>.img.z04`
        - `winesapos-secure-<VERSION>.img.z05`
        - `winesapos-secure-<VERSION>.img.z06`
2. Extract the `winesapos-<VERSION>.img.zip` archive. This will automatically extract all of the other `zip` file parts.
    - Linux:
        - GUI: Use [PeaZip](https://peazip.github.io/).
        - CLI: `7z x winesapos-<VERSION>.img.zip`
    - macOS: Use [PeaZip](https://peazip.github.io/) or [Keka](https://www.keka.io/).
    - Windows: Use [PeaZip](https://peazip.github.io/).
3. Use [balenaEtcher](https://www.balena.io/etcher/) to flash the image to an internal or external storage device. **WARNING:** This will delete any existing data on that storage device.

Default accounts have a password set that mirror the username:

- winesapOS (major version >= 3)

| Username | Password |
| --- | --- |
| winesap | winesap |
| root | root |

- Mac Linux Gaming Stick (major version <= 2)

| Username | Password |
| --- | --- |
| stick | stick |
| root | root |

Upon first login, the "winesapOS First-Time Setup" wizard will launch. It will help setup graphics drivers, the locale, and time zone. The desktop shortcut is located at `/home/winesap/.winesapos/winesapos-setup.desktop` and can be manually ran again.

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

Boot the Mac into an external drive by pressing and releasing the power button. Then hold down the `OPTION` key (or the `ALT` key on a Windows keyboard) to access the Mac bootloader. Select the "EFI Boot" device.

**IMPORTANT** Any [Mac with an Apple T2 Security Chip](https://support.apple.com/en-us/HT208862), which are all Macs made in and after 2018, needs to [allow booting from external storage](https://support.apple.com/en-us/HT208198):

1. Turn on the Mac and immediately hold both the `COMMAND` and `r` keys to enter recovery mode.
2. Utilities > Startup Security Utility
    - Secure Boot = No Security (Does not enforce any requirements on the bootable OS.)
    - External Boot = Allow booting from external media (Does not restrict the ability to boot from any devices.)

### Upgrades

Upgrades are supported between all minor releases via an upgrade script. **USE AT YOUR OWN RISK!** For example, it is supported to go from 2.0.0 to 2.1.0 but not from 2.2.0 to 3.0.0. This will make major changes to the operating system and could lead to data loss. Where it makes sense, features are backported from newer versions of winesapOS. This script is completely optional. Users will continue to get regular system upgrades from SteamOS.

- GUI = Launch the "winesapOS Upgrade" desktop shortcut.
- CLI = Launch the winesapOS upgrade script from the stable branch.

    ```
    curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/scripts/winesapos-upgrade.sh | sudo zsh
    ```

## Tips

### Getting Started

- Test booting up the drive first before buying speakers, a Bluetooth adapter, a WiFi adapter, and/or other hardware. Depending on the Mac, the built-in hardware may work out-of-the-box.
- Temporarily allow the `brcmfmac` and `brcmutil` drivers to see if the built-in WiFi will work. Remove the relevant entries from `/etc/modprobe.d/winesapos.conf` and then use `modprobe` to manually load the drivers.
- Plug additional hardware into a USB hub. Connect the USB hub to the computer before booting.
- Do NOT move the USB hub after plugging it in and booting up Linux. It can easily disconnect leading to a corrupt file system.
- Consider buying an SSD instead of a flash drive for a longer life-span, more storage, and faster speeds.
- Avoid using Flatpak and Snap packages. These use a lot of additional space compared to native system packages. Programs packaged this way are also slower.
- Delete old Btrfs backups when the drive is running low on storage space.

    ```
    $ sudo snapper list
    $ sudo snapper delete <SNAPSHOT_NUMBER>
    ```

- Enable Proton for all Windows games. This will allow them to run in Linux. For more information about Proton, [read this starter guide](https://www.gamingonlinux.com/2019/07/a-simple-guide-to-steam-play-valves-technology-for-playing-windows-games-on-linux). Check the compatibility rating for games on Steam by using [ProtonDB](https://www.protondb.com/).

    ```
    Settings > Steam Play > Enable Steam Play for Support Titles > Use this tool instead of game-specific selections from Steam > Compatibility tool: > (select the latest "Proton" version available) > OK
    ```

### No Sound (Muted Audio)

By default, all sound is muted on boot because on newer Macs the experimental sound driver is extremely loud. This means that any sound volume changes will be reset on the next boot. Here is how the mute configuration can be disabled to allow the sound volume to be saved:

-  winesapOS (major version >= 3)
    - Disable and stop the user (not system) ``mute`` service.
    ```
    $ systemctl --user disable --now mute.service
    ```
- Mac Linux Gaming Stick (major version <= 2)
    - Remove or delete the PulseAudio configuration.
    ```
    $ vim /home/stick/.config/pulse
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

## Troubleshooting

### Release Image Zip Files

**Challenge: the release image fails to be extracted from the zip files.**

**Solutions:**

1. **Verify the integrity of the downloaded zip files.**

    - Linux:

        ```
        sha512sum --check winesapos-<IMAGE_TYPE>-<VERSION>_sha512sum.txt
        ```

    - Windows (open Command Prompt as Administrator):

        ```
        C:\Windows\system32>CertUtil.exe -hashfile C:\Users\<USER>\Downloads\<FILE> SHA512
        ```

2. **Not all zip files were downloaded.** This includes the files ending in `.zip` and `.z<NUMBER>`.
3. **Not enough free space.** Ensure you have 40 GiB (performance image) or 50 GiB (secure image) of free space before downloading the zip files.
4. **PeaZip sometimes fails to extract to the current directory.** Try extracting to a different directory.
5. **Use a different archive utility.**

    - PeaZip uses the command `7z` for extracting multiple zip archives. Use it manually from the CLI to see more information to help with troubleshooting.

        ```
        7z x winesapos-<VERSION>.img.zip
        ```

### Root File System Resizing

**Challenge: the root file system does not resize itself to use all available space on the storage device.**

**Solution:**

1. Re-enable the resize service, reboot, and then view the service log. Open up a [GitHub Issue](https://github.com/LukeShortCloud/winesapOS/issues) with the full log output.

    ```
    sudo systemctl enable winesapos-resize-root-file-system
    sudo reboot
    ```

    ```
    sudo journalctl --unit winesapos-resize-root-file-system
    ```

### Some Package Updates are Ignored

**Challenge: Pacman has packages listed in its  `IgnorePkg` configuration.**

**Solutions:**

1. The performance image prevents updates to Linux kernels updates to prevent breaking third-party kernel modules.

    ```
    sudo pacman -S -y
    sudo pacman -S core/linux-lts core/linux-lts-headers kernel-lts/linux-lts510 kernel-lts/linux-lts510-headers jupiter/linux-neptune jupiter/linux-neptune-headers core/grub
    ```

2. The secure image only prevents updates to packages that SteamOS provides conflicting packages to. GRUB and the upstream Linux kernels from SteamOS that can cause an unbootable system. These can be manually upgraded by specifying the Arch Linux repository along with the package name.

    ```
    sudo pacman -S -y
    sudo pacman -S core/grub core/linux-lts core/linux-lts-headers
    ```

3. Selecting "Intel" graphics drivers during the first-time setup will configure Pacman to ignore packages that SteamOS provides conflicting packages to. SteamOS does not provide OpenGL graphics drivers for Intel so the Arch Linux drivers are installed instead.

    ```
    sudo pacman -S -y
    sudo pacman -S --noconfirm \
          extra/mesa \
          multilib/lib32-mesa \
          extra/xf86-video-intel \
          extra/vulkan-intel \
          multilib/lib32-vulkan-intel \
          community/intel-media-driver \
          community/intel-compute-runtime
    ```

### Pamac Shows Ignored Packages

**Challenge: in "Add/Remove Software" (the Pamac package manager) packages that are ignored are showing updates available.**

**Solution:**

1. **This is [by design](https://gitlab.manjaro.org/applications/pamac/-/issues/882#note_17262).** These packages are not selected for update by default (even if it looks like it). Pamac is letting the user know that there are updates available. The user has the option to select them for update but it is not recommended. As described in the Troubleshooting section [Some Package Updates are Ignored](#some-package-updates-are-ignored), updating certain packages that winesapOS ignores can lead to an unusable system.

### Available Storage Space is Incorrect

**Challenge: the amount of reported free space seems too small or large.**

**Solutions:**

1. Btrfs is used as the root file system on winesapOS. The most reliable way to view the amount of storage in-use on Btrfs is with this command.

    ```
    sudo btrfs filesystem df /
    ```

2. Snapper is used to take Btrfs snapshots/backups (1) every time Pacman installs, upgrades, or removes a package and (2) every month. Refer to the [Btrfs Backups](#btrfs-backups) section for more information on how to manage those snapshots.

### Two or More Set Ups of winesapOS Cause an Unbootable System

**Challenge: winesapOS uses labels for file system mounts which confuses the system if more than one label is found.**

**Solution:**

1. **Change the file system label of at least the root file system** on one of the winesapOS drives. It is recommended to change all of the labels on that same drive. **This can cause an unbootable system.** Manually review the contents of `/etc/fstab` to ensure it is correct.

    ```
    lsblk -o name,label
    export DEVICE=vda
    sudo -E exfatlabel /dev/${DEVICE}2 wos-drive0
    sudo -E fatlabel /dev/${DEVICE}3 WOS-EFI0
    sudo sed -i s'/LABEL=WOS-EFI/LABEL=WOS-EFI0/'g /etc/fstab
    sudo -E e2label /dev/${DEVICE}4 winesapos-boot0
    sudo sed -i s'/LABEL=winesapos-boot/LABEL=winesapos-boot0/'g /etc/fstab
    sudo btrfs filesystem label / winesapos-root0
    sudo btrfs filesystem show /
    sudo sed -i s'/LABEL=winesapos-root/LABEL=winesapos-root0/'g /etc/fstab
    lsblk -o name,label
    ```

## Frequently Asked Questions (FAQ)

- **Is this the Mac Linux Gaming Stick project?**
    - Yes. Version 1 and 2 of the project were called Mac Linux Gaming Stick. In version 3, we rebranded to winesapOS.
- **How do you pronounce winesapOS?**
    - `wine`-`sap`-`o`-`s`.
- **What is the relevance of the word "winesap" in winesapOS?**
    - It is a type of apple which signifies how we develop on Macs and ship drivers for them. It also has the word "wine" in it which is the [name of the project](https://www.winehq.org/) used to enable Windows gaming on Linux.
- **What makes this different than adding persistent storage to a live CD with [Universal USB Installer or YUMI](https://www.pendrivelinux.com/)?**
    - Having persistent storage work via these hacky methods can be hit-or-miss depending on the distribution. winesapOS was built from the ground-up to have persistent storage. It also features automatic backups, various gaming tools, has support for Macs, and more.
- **Are Arm Macs supported?**
    - No. In general, Linux support for them are still a work-in-progress.
- **Is winesapOS a Linux distribution?**
    - No. The project takes an existing Arch Linux distribution and does an opinionated installation of it.
- **Do I have to install winesapOS?**
    - No. No installation is required. Flash a [release image](https://github.com/LukeShortCloud/winesapOS/releases) to a drive and then boot from it. Everything is already installed and configured.
- **What if winesapOS was abandoned?**
    - We have no intentions on ever abandoning winesapOS. Even if that happened, since this is an opinionated installation of an Arch Linux distribution, it will continue to get normal operating system updates.
- **Can anyone build winesapOS?**
    - Yes. Refer to the [DEVELOPER.md](https://github.com/LukeShortCloud/winesapOS/blob/main/DEVELOPER.md) documentation.
- **Can winesapOS be built with a different Linux distribution?**
    - Yes. We support Arch Linux, Manjaro, and SteamOS as build targets. As of winesapOS 3, SteamOS 3 is the default target that is used for our releases.
- **Is winesapOS affiliated with Valve?**
    - No. We are an independent project that is using SteamOS 3 packages and source code.

## History

| Release Version/Tag | Project Name | Operating System | Desktop Environment | Release Images |
| ------------------- | ------------ | ---------------- | ------------------- | -------------- |
| 3.0.0-beta.0 | winesapOS | SteamOS 3 | KDE Plasma | Performance and Secure |
| 3.0.0-alpha.0 | winesapOS | Arch Linux | KDE Plasma | Performance and Secure |
| 2.2.0 | Mac Linux Gaming Stick | Manjaro | Cinnamon | Performance and Secure |
| 2.0.0 | Mac Linux Gaming Stick | Manjaro | Cinnamon | Performance |
| 1.0.0 | Mac Linux Gaming Stick | Ubuntu 20.04 | Cinnamon | None |

## License

GPLv3
