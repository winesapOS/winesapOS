# winesapOS <img src="https://user-images.githubusercontent.com/10150374/158224898-bdb4ad3a-ad09-478c-a09d-d313feeb8713.png" width=15% height=15%>

***Game with Linux anywhere, no installation required!***

- ![Image build status for Arch Linux](https://github.com/winesapOS/winesapOS/actions/workflows/image-arch-linux.yml/badge.svg)
- ![Image build status for Manjaro](https://github.com/winesapOS/winesapOS/actions/workflows/image-manjaro.yml/badge.svg)
- ![Testing repository build status](https://github.com/winesapOS/winesapOS/actions/workflows/repo-testing.yml/badge.svg)

Performance image type:

![winesapOS performance image type desktop screenshot](winesapos-desktop-performance.jpg)

Minimal image type:

![winesapOS minimal image type desktop screenshot](winesapos-desktop-minimal.jpg)

winesapOS makes it easy to setup Linux and play games off an internal or portable external drive.

Why use winesapOS?

- Portable. Useful for gaming or recovery purposes while traveling.
- Enhanced hardware support for Apple Macs with Intel processors, ASUS laptops, ASUS ROG Ally handhelds, AYANEO handhelds, Framework computers, Microsoft Surface laptops, and Valve Steam Deck handhelds.
- Upgrades are fully automated and supported for minor and major versions.
- All of the features of winesapOS are listed [here](#features).

Release images can be downloaded [here](https://github.com/winesapOS/winesapOS/releases).

Project goals:

- **Readability.** Anyone can learn how to install and maintain Arch Linux.
- **Upstream.** Stay as vanilla and upstream as possible.
- **Portability.** Be the most portable and modern x86_64 operating system.

Want to help support our work? Report any bugs or feature requests to our [GitHub Issues](https://github.com/winesapOS/winesapOS/issues). For developers, our [CONTRIBUTING.md](CONTRIBUTING.md) guide provides all of the information you need to get started as a winesapOS contributor. If you are a Go developer, we need the most help with the [archupgrade-go](https://github.com/winesapOS/archupgrade-go) project.

**TABLE OF CONTENTS**

* [winesapOS](#winesapos)
   * [macOS Limitations](#macos-limitations)
   * [Features](#features)
       * [General](#general)
       * [Additional Hardware Support](#additional-hardware-support)
           * [Apple Intel Macs](#apple-intel-macs)
           * [ASUS Laptops](#asus-laptops)
           * [ASUS ROG Ally Handhelds](#asus-rog-ally-handhelds)
           * [AYANEO Handhelds](#ayaneo-handhelds)
           * [Framework Computers](#framework-computers)
           * [Lenovo Legion Go](#lenovo-legion-go)
           * [Microsoft Surface Laptops](#microsoft-surface-laptops)
           * [OneXPlayer Handhelds](#onexplayer-handhelds)
           * [Valve Steam Decks](#valve-steam-decks)
       * [Community Collaboration](#community-collaboration)
       * [winesapOS Repository](#winesapos-repository)
       * [Comparison with SteamOS](#comparison-with-steamos)
   * [Usage](#usage)
      * [Getting Started](#getting-started)
          * [Hardware Requirements](#hardware-requirements)
          * [Image Types](#image-types)
              * [Secure Image](#secure-image)
          * [Release Builds](#release-builds)
          * [Custom Builds](#custom-builds)
          * [Docker or Podman Container](#docker-or-podman-container)
          * [Windows Subsystem for Linux](#windows-subsystem-for-linux)
          * [Passwords](#passwords)
          * [Mac Boot](#mac-boot)
          * [Windows Boot](#windows-boot)
          * [Ventoy](#ventoy)
          * [Dual-Boot](#dual-boot)
              * [macOS Dual-Boot Preparation Guide](#macos-dual-boot-preparation-guide)
              * [Windows Dual-Boot Preparation Guide](#windows-dual-boot-preparation-guide)
              * [winesapOS Dual-Boot Install Guide](#winesapos-dual-boot-install-guide)
      * [First-Time Setup](#first-time-setup)
      * [Upgrades](#upgrades)
          * [Minor Upgrades](#minor-upgrades)
          * [Major Upgrades](#major-upgrades)
      * [Uninstall](#uninstall)
      * [Convert to winesapOS](#convert-to-winesapos)
   * [Tips](#tips)
      * [Windows Games on Steam](#windows-games-on-steam)
      * [Steam Deck Game Mode](#steam-deck-game-mode)
      * [No Sound (Muted Audio)](#no-sound-muted-audio)
      * [Btrfs Backups](#btrfs-backups)
      * [VPN (ZeroTier)](#vpn-zerotier)
   * [Troubleshooting](#troubleshooting)
       * [Release Image Zip Files](#release-image-zip-files)
       * [winesapOS Not Booting](#winesapos-not-booting)
       * [Access Boot Menu](#access-boot-menu)
       * [Root File System Resizing](#root-file-system-resizing)
       * [Read-Only File System](#read-only-file-system)
       * [Wi-Fi or Bluetooth Not Working](#wi-fi-or-bluetooth-not-working)
       * [Available Storage Space is Incorrect](#available-storage-space-is-incorrect)
       * [First-Time Setup Log Files](#first-time-setup-log-files)
       * [Two or More Set Ups of winesapOS Cause an Unbootable System](#two-or-more-set-ups-of-winesapos-cause-an-unbootable-system)
       * [Snapshot Recovery](#snapshot-recovery)
       * [Reinstalling winesapOS](#reinstalling-winesapos)
       * [Bad Performance on Battery](#bad-performance-on-battery)
   * [Frequently Asked Questions (FAQ)](#frequently-asked-questions-faq)
   * [Contributors](#contributors)
   * [User Surveys](#user-surveys)
   * [History](#history)
   * [License](#license)

## macOS Limitations

These are reasons why macOS is inferior compared to Linux when it comes to gaming.

- Old and incomplete implementations of [OpenGL 4.1 and OpenCL 1.2](https://support.apple.com/en-us/101525).
    - On Apple Silicon, OpenGL is only provided by the slow [Metal for WebGL translation layer](https://github.com/KhronosGroup/MoltenVK/issues/203#issuecomment-1525594425).
- Linux has [kernel-level optimizations](https://www.phoronix.com/news/Linux-6.14-Char-Misc-NTSYNC) for Wine.
- [CrossOver Mac](https://www.codeweavers.com/crossover), a commercial Wine product, is one of the few ways to run games on macOS. It costs money and requires a new license yearly (or a very expensive lifetime license).
    - The community fork of Wine from CrossOver [lacks](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/issues/3372#issuecomment-1966481427) support for some game launchers, codecs, and translation layers.

## Features

### General

- **Any computer with an AMD or Intel processor can run winesapOS.**
- **Portability.**
    - A drive is bootable on both BIOS and UEFI systems.
    - Lots of [boot optimizations](https://rootpages.lukeshort.cloud/storage/bootloaders.html#usb-installation-with-both-legacy-bios-and-uefi-support) are made to make winesapOS more portable than most live Linux distributions.
    - Applications are installed using Flatpaks, a universal package manager for Linux, where possible.
- **Persistent storage.** Unlike traditional Linux live media, all storage is persistent and kept upon reboots.
    - Upon the first boot, the root partition is expanded to utilize all available space.
- **Supportability.** Linux is easy to troubleshoot remotely.
    - Access:
        - SSH can be accessed via clients on the same [ZeroTier VPN](https://www.zerotier.com/) network.
        - [tmate](https://tmate.io/) makes sharing SSH sessions without VPN connections easy.
    - Tools:
        - [ClamAV](https://www.clamav.net/), and the GUI front-end [Clamtk](https://github.com/dave-theunsub/clamtk), is an open source anti-virus scanner.
        - [QDirStat](https://github.com/shundhammer/qdirstat) provides a graphical user interface to view storage space usage.
- **Usability.** Software for typical day-to-day use is provided.
    - [AppImagePool](https://github.com/prateekmedia/appimagepool) for a GUI AppImage package manager.
    - [balenaEtcher](https://www.balena.io/etcher/) for an image flashing utility.
    - [bauh](https://github.com/vinifmor/bauh) for a GUI AUR and Snap package manager.
    - [Blueman](https://github.com/blueman-project/blueman) for a Bluetooth pairing client.
    - [Bottles](https://usebottles.com/) for installing any Windows program.
    - [Calibre](https://calibre-ebook.com/) for managing ebooks.
    - [Cheese](https://wiki.gnome.org/Apps/Cheese) for a webcam software.
    - [CoolerControl](https://gitlab.com/coolercontrol/coolercontrol) for managing computer fans.
    - [Discord](https://discord.com/) for a gaming chat client.
    - [Discover](https://apps.kde.org/discover/) for a GUI Flatpak package manager.
    - [Distrobox](https://github.com/89luca89/distrobox) for managing containers.
    - [Dolphin](https://apps.kde.org/dolphin/) (KDE Plasma), [Nemo](https://github.com/linuxmint/nemo) (Cinnamon), [cosmic-files](https://github.com/pop-os/cosmic-files) (COSMIC), or [Nautilus](https://wiki.gnome.org/action/show/Apps/Files?action=show&redirect=Apps%2FNautilus) (GNOME) for a file manager.
    - [FileZilla](https://filezilla-project.org/) for a FTP client.
    - [Firefox ESR](https://support.mozilla.org/en-US/kb/switch-to-firefox-extended-support-release-esr) for a stable web browser.
    - [Firewall](https://firewalld.org/) (secure image) provides a GUI for managing firewalld.
    - [Flatseal](https://github.com/tchx84/Flatseal) for managing Flatpaks.
    - [Google Chrome](https://www.google.com/chrome/) for a newer web browser.
    - [GParted](https://gparted.org/) for managing storage partitions.
    - [Gwenview](https://apps.kde.org/gwenview/) (KDE Plasma), [Pix](https://community.linuxmint.com/software/view/pix) (Cinnamon), [cosmic-files](https://github.com/pop-os/cosmic-files) (COSMIC), or [Eye of GNOME](https://wiki.gnome.org/Apps/EyeOfGnome) (GNOME) for an image gallery application.
    - [KeePassXC](https://keepassxc.org/) for a cross-platform password manager.
    - [LibreOffice](https://www.libreoffice.org/) provides an office suite.
    - [Modem Manager GUI](https://sourceforge.net/projects/modem-manager-gui/) for using cellular modems.
    - [Open Broadcaster Software (OBS) Studio](https://obsproject.com/) for a recording and streaming utility.
    - [PeaZip](https://peazip.github.io/) for an archive/compression utility.
    - [qBittorrent](https://www.qbittorrent.org/) for a torrent client.
    - [Spectacle](https://apps.kde.org/spectacle/) for a screenshot utility.
    - [usbmuxd](https://github.com/libimobiledevice/usbmuxd) with backported patches to properly support iPhone file transfers and Internet tethering on T2 Macs.
    - [Waydroid](https://waydro.id/) for Android app and gaming support.
    - [VeraCrypt](https://www.veracrypt.fr/en/Home.html) for a cross-platform encryption utility.
    - [VLC](https://www.videolan.org/) for a media player.
    - [ZeroTier GUI](https://github.com/tralph3/ZeroTier-GUI) for a VPN utility for online LAN gaming.
- **Distro-agnostic package managers** for installing a large variety of software.
    - [Flatpak](https://flatpak.org/)
    - [Homebrew](https://brew.sh/)
    - [Nix](https://nixos.org/)
    - [Snap](https://snapcraft.io/)
- **Gaming support** out-of-the-box.
    - Game launchers:
        - [Steam](https://store.steampowered.com/).
        - [Heroic Games Launcher](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher) for Epic Games Store games.
        - [Lutris](https://lutris.net/) for all other games.
        - [Open Gamepad UI](https://github.com/ShadowBlip/OpenGamepadUI) for an open source video game console experience.
        - [Prism Launcher](https://prismlauncher.org/) for vanilla and modded Minecraft: Java Edition.
        - [Bottles](https://usebottles.com/) for all Windows programs.
        - [EmuDeck](https://www.emudeck.com/) for video game console emulators.
        - [NVIDIA GeForce Now](https://www.nvidia.com/en-us/geforce-now/) for streaming games from NVIDIA servers.
        - [Xbox Cloud Gaming](https://www.xbox.com/en-US/cloud-gaming) for streaming Xbox games.
    - Wine:
        - [Proton](https://github.com/ValveSoftware/Proton) is installed along with Steam for playing Windows games on Linux.
        - [GE-Proton](https://github.com/GloriousEggroll/proton-ge-custom) is installed along with the ProtonUp-Qt package manager for it. This provides better Windows games compatibility.
        - [Proton-Sarek (async)](https://github.com/pythonlover02/Proton-Sarek) = A GE-Proton fork optimized for legacy graphics cards.
        - [umu-launcher](https://github.com/Open-Wine-Components/umu-launcher) for running non-Steam games with Proton.
    - [Chiaki](https://github.com/streetpea/chiaki-ng) for PS4 and PS5 game streaming.
    - [DOSBox](https://www.dosbox.com/) for running 16-bit DOS and Windows (via Wine) applications.
    - [GameMode](https://github.com/FeralInteractive/gamemode) is available to be used to speed up games.
    - [Gamescope](https://github.com/Plagman/gamescope) for helping play older games with frame rate or resolution issues.
    - [GOverlay](https://github.com/benjamimgois/goverlay) is a GUI for managing Vulkan overlays including MangoHud and vkBasalt.
    - [Ludusavi](https://github.com/mtkennerly/ludusavi) is a game save files manager.
    - [MangoHud](https://github.com/flightlessmango/MangoHud) for benchmarking OpenGL and Vulkan games.
    - [Moonlight](https://github.com/moonlight-stream/moonlight-qt) and [Sunshine](https://github.com/LizardByte/Sunshine) for game streaming.
    - [Nexus Mods app](https://github.com/Nexus-Mods/NexusMods.App) for managing mods.
    - [NonSteamLaunchers](https://github.com/moraroy/NonSteamLaunchers-On-Steam-Deck) to manage other game launchers.
    - [Playtron GameLAB](https://www.playtron.one/contribute) to remotely manage Playtron GameOS devices.
    - [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) for managing Steam Play compatibility tools.
    - [ZeroTier VPN](https://www.zerotier.com/) can be used to play LAN-only games online with friends.
    - Open source OpenGL and Vulkan drivers are installed for AMD, Intel, NVIDIA, VirtualBox, and VMware graphics.
- **Controller support** for most controllers.
    - All official PlayStation and Xbox controllers are supported.
    - All generic DirectInput and XInput controllers are supported.
    - [AntiMicroX](https://github.com/AntiMicroX/antimicrox) is provided for configuring controller input for non-Steam games.
    - [game-devices-udev](https://codeberg.org/fabiscafe/game-devices-udev) is provided for more controller support.
    - [OpenRazer](https://openrazer.github.io/) and [Polychromatic](https://polychromatic.app/) are provided for Razer accessories.
    - [Oversteer](https://github.com/berarma/oversteer) is provided for managing racing wheels and related accessories.
- **Steam Deck look and feel**.
    - [Gamescope Session](https://github.com/ChimeraOS/gamescope-session) is provided to replicate the "Game Mode" from the Steam Deck.
    - KDE Plasma desktop environment is used.
- **Minimize writes** to the drive to improve its longevity.
    - Root file system is mounted with the options `noatime` and `nodiratime` to not write the access times for files and directories.
    - Temporary directories with heavy writes (`/tmp/`, `/var/log/`, and `/var/tmp/`) are mounted as RAM-only file systems.
    - [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) is configured to use volatile (RAM-only) storage for all system logs.
    - zram with lz4 compression is used for swap to maximize performance and avoid writing data to a swap file on the storage device.
        - Alternatively, a swap file can be used instead for hibernation support.
        - For a swap file, the swappiness level is set to 0.5% (down from the default of 30%) as recommended by CryoByte33's [CryoUtilities](https://github.com/CryoByte33/steam-deck-utilities).
    - Writes are heavily cached in RAM for faster performance.
    - Commit file system writes every 600 seconds (10 minutes) to minimize wear and tear.
    - libeatmydata is used for Firefox ESR and Google Chrome to improve performance and minimize writes.
        - Despite the name, all data (including bookmarks, history, signed-in profiles, etc.) are kept after exiting the application.
- **Full backups** via Btrfs.
    - [Snapper](https://github.com/openSUSE/snapper) takes 6 monthly snapshots of the `/home/` directory.
    - [snap-pac](https://github.com/wesbarnett/snap-pac) takes a snapshot whenever the `pacman` package manager is used.
    - [grub-btrfs](https://github.com/Antynea/grub-btrfs) automatically generates a GRUB menu entry for all of the Btrfs backups.
- **No automatic operating system updates.** Updates should always be intentional and planned.
- **Most file systems supported.** Access any storage device, anywhere.
    - APFS
    - Bcachefs
    - Boot File System (BFS)
    - Btrfs
    - CephFS
    - CIFS/SMB
    - eCryptFS
    - EROFS
    - ext2, ext3, and ext4
    - exFAT
    - F2FS
    - FAT12, FAT16, and FAT32
    - GFS2
    - GlusterFS
    - HFS and HFS+
    - JFS
    - MinIO
    - MINIX file system
    - MooseFS
    - NFS
    - NILFS2
    - NTFS
    - OverlayFS
    - ReiserFS = Only works with Linux LTS.
    - SquashFS
    - SSDFS
    - SSHFS
    - UDF
    - Virtiofs
    - XFS
    - ZFS = Only works with Linux LTS.
- **Battery optimizations.**
    - The [auto-cpufreq](https://github.com/AdnanHodzic/auto-cpufreq) service provides automatic power management.
- **Fully automated installation.**

### Additional Hardware Support

#### Apple Intel Macs

**All Intel Macs are supported.** Linux works on most Macs out-of-the-box these days. Drivers are pre-installed for newer hardware where native Linux support is missing.

For installation onto an internal drive, winesapOS must be installed as a [dual-boot](#dual-boot) alongside macOS. It will not work as the only installed operating system on an Intel Mac.

| Hardware | Supported | Third-Party Driver(s) |
| -------- | --------- | --------- |
| Keyboard | Yes | [linux-t2 patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |
| Touchpad | Yes | [linux-t2 patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |
| NVMe | Yes | [linux-t2 patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |
| Sound | Yes | [linux-t2 patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) and [apple-t2-audio-config](https://github.com/kekrby/t2-better-audio) |
| Fans | Yes | [mbpfan](https://github.com/linux-on-mac/mbpfan) |
| Bluetooth | Yes | [linux-t2 patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) and [apple-bcm-firmware](https://github.com/NoaHimesaka1873/apple-bcm-firmware) |
| Wi-Fi | Yes | [broadcom-wl](https://github.com/antoineco/broadcom-wl) and [apple-bcm-firmware](https://github.com/NoaHimesaka1873/apple-bcm-firmware) |
| Fingerprint scanner | No | |
| Touch Bar | Yes | [linux-t2 patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |

Notes about Bluetooth and Wi-Fi support if it is not working out-of-the-box:

-  Macs with the Apple T2 Security Chip (>= 2017)
    - Follow the t2linux [wiki](https://wiki.t2linux.org/guides/wifi-bluetooth/) for instructions on how to copy firmware files from macOS to Linux.
-  Macs without the Apple T2 Security Chip (< 2017)
    -  During the winesapOS First-Time Setup, select "Yes" when asked "Do you want to install the Broadcom proprietary Wi-Fi driver?"

#### ASUS Laptops

| Hardware | Supported | Third-Party Driver(s) |
| -------- | --------- | --------- |
| Keyboard | Yes | [asusctl](https://gitlab.com/asus-linux/asusctl) |
| Touchpad | Yes | |
| NVMe | Yes | |
| Sound | Yes | |
| Fans | Yes | [asusctl](https://gitlab.com/asus-linux/asusctl) |
| Bluetooth | Yes | |
| Wi-Fi | Yes | |
| Fingerprint scanner | No | |

#### ASUS ROG Ally Handhelds

We provide support for both the original ASUS ROG Ally and the newer ASUS ROG Ally X.

| Hardware | Supported | Third-Party Driver(s) |
| -------- | --------- | --------- |
| Controller | Yes | |
| NVMe | Yes | |
| Sound | Yes | |
| Fans | Yes | [linux-nobara patches](https://github.com/Nobara-Project/rpm-sources/blob/41/baseos/kernel/6.12.8/ROG-ALLY-NCT6775-PLATFORM.patch) |
| Bluetooth | Yes | |
| Wi-Fi | Yes | |
| Fingerprint scanner | No | |

#### AYANEO Handhelds

| Hardware | Supported | Third-Party Driver(s) |
| -------- | --------- | --------- |
| Controller | Yes | [ayaneo-platform-dkms-git](https://github.com/ShadowBlip/ayaneo-platform) and [ayaled-updated](https://github.com/luluco250/ayaled) |
| NVMe | Yes | |
| Sound | Yes | [aw87559-firmware](https://aur.archlinux.org/packages/aw87559-firmware) |
| Fans | Yes | |
| Bluetooth | Yes | |
| Wi-Fi | Yes | |
| Fingerprint scanner | No | |

#### Framework Computers

All [Framework](https://frame.work/) computers are fully supported.

| Hardware | Supported | Notes |
| -------- | --------- | --------- |
| Keyboard | Yes |  |
| Touchpad | Yes | Quirk added to disable when the keyboard is in-use |
| NVMe | Yes | Power saving mode enabled for deep sleep support  |
| Sound | Yes | [framework-dsp](https://github.com/cab404/framework-dsp) used for improved audio quality |
| Fans | Yes | |
| Bluetooth | Yes | |
| Wi-Fi | Yes | Region is automatically set to enable Wi-Fi >= 5 |
| Fingerprint scanner | Yes | |
| LED matrix | Yes | [inputmodule-control](https://github.com/FrameworkComputer/inputmodule-rs/blob/main/ledmatrix/README.md) used for managing LED matrixes |

For the Framework Laptop 16, audio support for Linux needs to be enabled in the BIOS.

- (Boot into the BIOS by pressing "F2" when turning the device on) > Setup Utility > Advanced > Linux Audio Compatibility: Linux > (Save and exit by pressing "F10")

#### Lenovo Legion Go

As of winesapOS 4.3.0, all drivers are now upstream. No third-party drivers are needed.

#### Microsoft Surface Laptops

| Hardware | Supported | Third-Party Driver(s) |
| -------- | --------- | --------- |
| Keyboard | Yes | [linux-surface pathces](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |
| Touchpad | Yes | |
| NVMe | Yes | |
| Sound | Yes | [linux-surface patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |
| Fans | Yes | [linux-surface patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |
| Bluetooth | Yes | [linux-surface patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |
| Wi-Fi | Yes | [linux-surface patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |
| Fingerprint scanner | No | |
| Touchscreen | Yes | [IPTSD](https://github.com/linux-surface/iptsd), [libwacom-surface](https://github.com/linux-surface/libwacom), and [linux-surface patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) |

#### OneXPlayer Handhelds

As of winesapOS 4.3.0, all drivers are now upstream. No third-party drivers are needed.

#### Valve Steam Decks

Both the Steam Deck LCD and OLED models are fully supported.

| Hardware | Supported | Third-Party Driver(s) |
| -------- | --------- | --------- |
| Controller | Yes | |
| Touchpad | Yes | |
| NVMe | Yes | |
| Sound | Yes | [linux-nobara patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) and [linux-firmware-valve](https://aur.archlinux.org/packages/linux-firmware-valve) |
| Fans | Yes | |
| Bluetooth | Yes | [linux-nobara patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) and [linux-firmware-valve](https://aur.archlinux.org/packages/linux-firmware-valve) |
| Wi-Fi | Yes | [linux-nobara patches](https://github.com/Nobara-Project/rpm-sources/tree/main/baseos/kernel) and [linux-firmware-valve](https://aur.archlinux.org/packages/linux-firmware-valve) |
| Touchscreen | Yes | |

### Community Collaboration

We are actively working alongside these operating system projects to help provide wider Linux gaming support to the masses:

- [Batocera](https://batocera.org/)
- [ChimeraOS](https://chimeraos.org/)
- [Garuda Linux](https://garudalinux.org/)
- [SteamOS: Edge](https://gitlab.com/edgedev1/steamos-edge) (Originally GuestSneezeOS, then Jupiter Linux.)
- [Nobara](https://nobaraproject.org/)
- [Playtron GameOS](https://www.playtron.one/)
- [Universal Blue](https://universal-blue.org/)

### winesapOS Repository

As of winesapOS 3.1.0, we now provide our own repository with some AUR packages pre-built. This repository works on Arch Linux and Manjaro. It is enabled on winesapOS by default. Depending on what distribution you are on, here is how it can be enabled:

-  Arch Linux and Manjaro:
    ```
    sudo sed -i s'/\[core]/[winesapos]\nServer = https:\/\/winesapos.lukeshort.cloud\/repo\/$repo\/$arch\n\n[core]/'g /etc/pacman.conf
    sudo pacman -S -y -y
    ```

Enable the GPG key to be used by importing it and then locally signing the key to trust it.

```
sudo pacman-key --recv-keys 1805E886BECCCEA99EDF55F081CA29E4A4B01239
sudo pacman-key --init
sudo pacman-key --lsign-key 1805E886BECCCEA99EDF55F081CA29E4A4B01239
```

### Comparison with SteamOS

| Features | SteamOS 3 | winesapOS 4 |
| --- | --- | --- |
| SteamOS repositories | Yes | No |
| Arch Linux packages | Old | New |
| Boot compatibility | UEFI | UEFI and legacy BIOS |
| Graphics drivers | AMD | AMD, Intel, NVIDIA, Parallels, VirtualBox, and VMware |
| Audio server | PipeWire | PipeWire |
| Read-only file system | Yes | No |
| Encrypted file system | No | Yes (secure image) |
| File system backup type | A/B partitions | Btrfs snapshots |
| Number of possible file system backups | 1 | Unlimited |
| Package managers (CLI) | flatpak and nix | pacman, paru/yay/AUR, flatpak, homebrew, nix, and snap |
| Preferred package manager (CLI) | flatpak | flatpak |
| Package managers (GUI) | Discover (flatpak) | Discover (flatpak), bauh (pacman, paru/yay/AUR, flatpak, and snap), and AppImagePool (AppImage) |
| Update type | Image-based | Package manager |
| Number of installed packages | Small | Small (minimal image) or Large (performance and secure images) |
| Game launchers | Steam | Steam, Heroic Games Launcher, Lutris, NVIDIA GeForce Now, Open Gamepad UI, Prism Launcher, and Xbox Cloud Gaming |
| Linux kernels | Neptune (6.5) | Linux LTS (6.12) and Linux Nobara (Latest) |
| Additional Apple Intel Mac drivers | No | Yes |
| Additional ASUS laptop drivers | No | Yes |
| Additional ASUS ROG Ally handheld drivers | Yes | Yes |
| Additional AYANEO handheld drivers | No | Yes |
| Additional Framework Computer drivers | No | Yes |
| Additional Microsoft Surface laptop drivers | No | Yes |
| Desktop environment | KDE Plasma 5 | KDE Plasma 6 |
| Desktop theme | Vapor | Breeze |
| AMD FSR | Global | Global |
| Gamescope | Global | Global |
| Wine | Proton | Proton, GE-Proton, and Proton-Sarek |
| Game controller support | Medium | Large |
| exFAT cross-platform storage | No | Yes (16 GiB on the performance and secure images) |

winesapOS 3 was the first Linux distribution to be based on SteamOS 3. Historically, here are the first forks of SteamOS 3:

| Distro | First Preview | First Public Release |
| --- | --- | --- |
| [winesapOS](https://github.com/winesapOS/winesapOS) | [2022-03-06](https://github.com/winesapOS/winesapOS/commit/2488cf702084d414ec5319a55cfbee1b86e2b05b) | [2022-03-10](https://github.com/winesapOS/winesapOS/tree/3.0.0-beta.0) |
| [SteamOS for PS4](https://wololo.net/2022/03/28/release-steamos-3-0-for-ps4-unofficial/) | [2022-03-09](https://twitter.com/NazkyYT/status/1501670690453438471?cxt=HHwWjoC-oa3igNcpAAAA) | [2022-03-25](https://twitter.com/NazkyYT/status/1507284235765182465?cxt=HHwWgsCjhdnB-eopAAAA) |
| [HoloISO](https://github.com/HoloISO/holoiso) | [2022-04-21](https://github.com/HoloISO/holoiso/commit/b04bccfb78567c9958f376659703b58e87ecd359) | [2022-05-01](https://github.com/HoloISO/holoiso/releases/tag/beta0) |

## Usage

### Getting Started

#### Hardware Requirements

Minimum:

- Processor = Single-core AMD or Intel processor.
- RAM = 2 GiB.
- Graphics = AMD, Intel, or NVIDIA, Parallels Desktop, VirtualBox, or VMware Fusion/Workstation virtual graphics device.
- Storage
    - Minimal image = 16 GB USB 3.2 Gen 1 (USB 3.0) flash drive.
    - Performance image = 64 GB USB 3.2 Gen 1 (USB 3.0) flash drive.

Recommended:

- Processor = Quad-core AMD or Intel processor.
- RAM = 8 GiB.
- Graphics = AMD discrete graphics card.
- Storage
    - Internal = 512 GB NVMe SSD.
    - External = 512 GB USB 3.2 Gen 2 (USB 3.1) SSD.

**Important note about external storage!**

One of the founding goals of winesapOS was for it to be portable. However, most flash drives and SD/TF cards are too slow to run an operating system on and provide a good experience. For the best experience, use one of these [recommended flash drives](https://www.tomshardware.com/best-picks/best-flash-drives), an external USB-C >= 3.1 SSD, or a USB-C >= 3.2 docking station or hub that includes a M.2 NVMe drive slot. SSD and NVMe drives have a longer life-span, more storage, and faster speeds compared to traditional flash storage.

#### Image Types

winesapOS provides 3 different image types to meet the diverse needs of our users:

- **Minimal** = A small variant of the performance image.
- **Performance** =  Everything but the kitchen sink, speed, and ease-of-use.
- **Secure** = Locked down and recommended for advanced Linux users only.
    - There are no release builds for the secure image. Use a [custom build](#custom-builds) to generate a unique LUKS container encryption key.

| Feature | Minimal | Performance | Secure |
| ------- | ------- | ----------- | ------ |
| CPU Mitigations | No | No | Yes |
| Encryption | No | No | Yes (LUKS) |
| Firewall | No | No | Yes (Firewalld) |
| `root` Password Requires Reset | No | No | Yes |
| 16 GiB exFAT Cross-Platform Storage | No | Yes | Yes |
| Pre-built release image | Yes | Yes | No |

The minimal root file system archive (`winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar.zst`) is the extracted files from the minimal image. It can be used for containers or installing winesapOS in a [Docker or Podman container](#docker-or-podman-container), [dual-boot](#dual-boot), or [WSL 2](#windows-subsystem-for-linux) scenario.

##### Secure Image

If using the secure image, the default LUKS encryption key is `password` which should be changed after the first boot. Do not do this before the first boot as the default password is used to unlock the partition for it be resized to fill up the entire storage device. Change the LUKS encryption key for the fifth partition.

```
$ sudo cryptsetup luksChangeKey /dev/<DEVICE>5
```

The user account password for `winesap` and `root` are the same as the username. The `root` user are set to expire immediately. Upon first login, you will be prompted to enter a new password. Here is how to change it:

1. Enter the default password of ``winesap``.
2. The prompt will say "Changing password for winesap." Enter the default password of ``winesap`` again.
3. The prompt will now say "New password". Enter a new password.
4. The prompt will finally say "Retype new password". Enter the new password again. The password has been updated and the KDE Plasma desktop will now load.

The `root` user account is locked until the password is changed. It is recommended to change this immediately to allow for recovery to work.

```
$ sudo passwd root
```

#### Release Builds

0. Refer to the [Mac Boot](#mac-boot) and [Windows Boot](#windows-boot) guides to avoid common issues.
1. Download the latest release from [here](https://github.com/winesapOS/winesapOS/releases).
    - External drive
        - Download one the of the release images and then continue on with this guide.
            - Performance (recommended) = Requires 31 GiB of free space to download and extract.
            - Minimal (for users low on storage space or who want control over what is installed) = Requires 13 GiB of free space to download and extract.
    - Internal drive
        - Entire drive (PCs only, does not work on Macs)
            - Use winesapOS to install winesapOS. Start with the minimal image and follow through the next steps (2 and 3) to extract and flash the image to an external drive. Then boot into the storage device and download the image you want to setup. Follow steps 2 and 3 again to flash the image onto an internal storage device.
                - For balenaEtcher, when you "Select target" there is an option to "Show hidden" storage devices. It will let you flash an image to any drive except the one it is physically running on.
        - Dual-boot (PCs and Intel Macs)
            - Refer to the [Dual-Boot](#dual-boot) guide.
    - If you want even more control over the how the image is built, consider doing a [custom build](#custom-builds) instead.
2. Extract the `winesapos-<VERSION>-<TYPE>.img.zip` archive.
3. Use the image...
    1. on a PC or Mac.
        - Flash the image to an internal or external storage device. **WARNING:** This will delete any existing data on that storage device.
            - On Linux, macOS, and Windows, use either [balenaEtcher](https://www.balena.io/etcher/) or [USBImager](https://bztsrc.gitlab.io/usbimager/) to flash the image.
            - On Linux and macOS, the `dd` CLI utility can be used to flash the image.
    2. with GNOME Boxes on Linux.
        - Resize the winesapOS image to at least 32 GiB.
            ```
            $ qemu-img resize winesapos*.img +24G
            ```
        - GNOME Boxes > + > Install from File > (select the winesapOS image file) > Open > Operating System: Arch Linux, Memory: 4.0 GiB > Create
    3. with Parallels Desktop on macOS (Intel only).
        - Convert the raw image to the VDI format. Then convert the VDI image to HDD.
            - Using the qemu-img and prl_convert CLI:
                ```
                qemu-img convert -f raw -O vdi winesapos-<VERSION>-<TYPE>.img winesapos-<VERSION>-<TYPE>.vdi
                prl_convert winesapos-<VERSION>-<TYPE>.vdi --allow-no-os --stand-alone-disk --dst=winesapos-<VERSION>-<TYPE>.hdd
                ```
        - Parallels Desktop > Install Windows or another OS from a DVD or image file > Image File > select a file... > (select the winesapOS HDD file) > Continue > Please select your operating system: > More Linux > Other Linux > OK > Name: winesapOS > Create
    4. with Virtual Machine Manager on Linux.
        - Resize the winesapOS image to at least 32 GiB.
            ```
            $ qemu-img resize winesapos*.img +24G
            ```
        - Move the winesapOS image to `/var/lib/libvirt/images/`.
        - Virtual Machine Manager > File > New Virtual Machine > Import existing disk image > Forward > Browse local > (select the winesapOS image) > Open > Choose the operating system you are installing: Arch Linux (archlinux) > Forward > (if asked to fix permissions, select "Yes"), Memory: 4096, CPUs: 2 > Forward > Name: winesapOS, Customize configuration before install: yes > Finish > Overview > Firmware: "UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.fd" > Apply > Begin Installation
    5. with VirtualBox.
        - Convert the raw image to the VDI format.
            - Using the VirtualBox CLI:
                ```
                VBoxManage convertfromraw --format VDI winesapos-<VERSION>-<TYPE>.img winesapos-<VERSION>-<TYPE>.vdi
                ```
            - Using the qemu-img CLI:
                ```
                qemu-img convert -f raw -O vdi winesapos-<VERSION>-<TYPE>.img winesapos-<VERSION>-<TYPE>.vdi
                ```
            - Using [StarWind V2V Converter](https://www.starwindsoftware.com/starwind-v2v-converter) on Windows.
        - Virtual Box > New > Name: winesapOS, Type: Linux, Version: Arch Linux (64-bit) > Next > Base Memory: 4096 MB, Processors: 2, Enable EFI: Yes > Next > Use an Existing Virtual Hard Disk File > Add > Choose > Next > Finish > File > Tools > Virtual Media Manager > Size: (increase to at least 32 GB) > Apply > OK > winesapOS > Settings > General > Advanced > Shared Clipboard: Bidirectional, Drag'n'Drop: Bidirectional > OK > winesapOS > Settings > Display > Screen > Video Memory: 128 MB, Graphics Controller: VMSVGA, Extended Features: Enable 3D Acceleration
        - **NOTICE:** VirtualBox 3D acceleration for Linux guests does not fully work. This issue is not specific to winesapOS. Consider using VMware Fusion or VMware Workstation instead.

    6. with VMware Fusion on macOS (Intel only).
        - Convert the raw image to the VMDK format.
            - Using the VirtualBox CLI:
                ```
                VBoxManage convertfromraw --format VMDK winesapos-<VERSION>-<TYPE>.img winesapos-<VERSION>-<TYPE>.vmdk
                ```
            - Using the qemu-img CLI:
                ```
                qemu-img convert -f raw -O vmdk winesapos-<VERSION>-<TYPE>.img winesapos-<VERSION>-<TYPE>.vmdk
                ```
            - Using [StarWind V2V Converter](https://www.starwindsoftware.com/starwind-v2v-converter) on Windows.
        - VMware Fusion > Virtual Machine Library > + > New... > Create a custom virtual machine > Continue > Linux > Other Linux 5.x kernel 64-bit > Continue > Specify the boot firmware: UEFI > Continue > Use an existing virtual disk > Continue > Custom Settings > Hard Disk (SCSI) > Disk size: (increase to at least 64 GB) > Apply > Show All > Processors & Memory > Processors: 2 processor cores > Memory: 4096 MB > Show All > Display > Accelerate 3D Graphics: Yes > Shared graphics memory: (set this to the highest possible value)
    7. with VMware Workstation on Linux or Windows.
        - Convert the raw image to the VMDK format.
        - VMware Workstation > Create a New Virtual Machine > Custom (advanced) > Next > Hardware compatibility: (select the latest version) > Next > I will install the operating system later. > Next > Guest Operating System: 2. Linux > Version: Other Linux 5.x kernel 64-bit > Next > Name: winesapOS > Next > Number of processors: 2 > Next > Memory for this virtual machine: 4096 MB > Next > Use network address translation (NAT) > Next > SCSI controller: LSI Logic (Recommended) > Next > Virtual Disk Type: SCSI (Recommended) > Next > Use an existing virtual disk > Next > File name: (select the winesapOS VMDK file) > Keep Existing Format > Customize Hardware... > Hard Disk (SCSI) > Expand Disk... > Maximum disk size (GB): (increase to at least 64 GB) > Expand > OK > Display > Accelerate 3D graphics: Yes > Graphics Memory: (set this to the highest possible value) > Close > Finish > Close

Default accounts have a password set that mirror the username:

| Username | Password |
| --- | --- |
| winesap | winesap |
| root | root |

Upon first login, the "winesapOS First-Time Setup" wizard will launch. It will help set up graphics drivers, the locale, time zone, and more. It is highly recommended to complete this on the first boot. Then reboot before using winesapOS to provide the best experience.

If using the recommended defaults of the first-time setup and after rebooting, press the enter/return key (the bottom-right key on the virtual keyboard) on the login screen for passwordless login.

#### Custom Builds

Instead of using a release build which is already made, advanced users may want to create a custom build. This only requires 1 GiB of free space to download the live Arch Linux environment. It also allows using environment variables to configure the build differently than the default release builds.

1.  [Download](https://archlinux.org/download/) and setup the latest Arch Linux ISO onto a flash drive that has at least 1 GB of storage.

    1a.  We also support building winesapOS with Manjaro even though we do not provide release images for it. [Download](https://manjaro.org/download/) either the Plasma, Cinnamon, or GNOME desktop edition of Manjaro.

2.  Boot into the flash drive.
3.  Update the known packages cache and install git.

    ```
    pacman -S -y
    pacman -S git
    ```

4.  Clone the [stable](https://github.com/winesapOS/winesapOS/tree/stable) branch and go to the "scripts" directory.

    ```
    git clone --branch stable https://github.com/winesapos/winesapos.git
    cd ./winesapos/scripts/
    ```

5.  Configure [environment variables](https://github.com/winesapOS/winesapOS/blob/stable/CONTRIBUTING.md#environment-variables-for-installation) to customize the build. At the very least, allow the build to work on bare-metal and define what ``/dev/<DEVICE>`` block device to install to. ***BE CAREFUL AS THIS WILL DELETE ALL EXISTING DATA ON THAT DEVICE!***

    ```
    export WINESAPOS_BUILD_IN_VM_ONLY=false
    lsblk
    export WINESAPOS_DEVICE=<DEVICE>
    ```

6.  By default, the performance image will be built. Alternatively, source the environment variables to configure the build to make the minimal or secure image instead.

    ```
    . ./env/winesapos-env-minimal.sh
    ```

    ```
    . ./env/winesapos-env-secure.sh
    ```

7.  Run the build.

    ```
    sudo -E bash ./winesapos-install.sh
    ```

8.  Check for any test failures (there should be no output from this command).

    ```
    grep -P 'FAIL$' /winesapos/etc/winesapos/winesapos-install.log
    ```

For more detailed information on the build process, we recommend reading the entire [CONTRIBUTING.md](CONTRIBUTING.md) guide.

#### Docker or Podman Container

Configure the winesapOS version to download and the container engine to use.

```
export WINESAPOS_VERSION="4.1.0"
#export WINESAPOS_CONTAINER_ENGINE="docker"
export WINESAPOS_CONTAINER_ENGINE="podman"
```

Download, decompress, and then import the root file system. Most container engines [only support Gzip](https://github.com/containers/podman/issues/18193) compression (not Zstandard).

```
curl -LO https://winesapos.lukeshort.cloud/repo/iso/winesapos-${WINESAPOS_VERSION}/winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar.zst
zstd --decompress winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar.zst
${WINESAPOS_CONTAINER_ENGINE} import winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar winesapos:${WINESAPOS_VERSION}
```

Verify that the container image was imported.

```
${WINESAPOS_CONTAINER_ENGINE} images | grep winesapos
# Example output: winesapos                        4.1.0     23b9bb5f1c26   26 seconds ago   8.79GB
```

#### Windows Subsystem for Linux

As of winesapOS 4.1.0, it is supported to be ran as a virtual machine on Windows >= 10 using WSL 2.

- [Install](https://learn.microsoft.com/en-us/windows/wsl/install) WSL 2.
- Download the [winesapos-wsl.ps1](https://raw.githubusercontent.com/winesapOS/winesapOS/stable/scripts/winesapos-wsl.ps1) script.
- Open PowerShell and navigate to the downloaded location.
- Allow and run the PowerShell script.

    ```
    PS C:\Users\user\Downloads> powershell -ExecutionPolicy Bypass -File .\winesapos-wsl.ps1
    ```

- Verify that a new "winesapOS" virtual machine appears.

    ```
    PS C:\Users\user\Downloads> wsl --list
    ```

- Enter the virtual machine.

    ```
    PS C:\Users\user\Downloads> wsl --distribution winesapOS
    ```

- Verify that it is winesapOS.

    ```
    cat /usr/lib/os-release-winesapos
    ```

#### Passwords

| Username | Password |
| -------- | -------- |
| root | root |
| winesap | winesap |

On the secure image, the LUKS encryption key is `password`. The password for LUKS and the `root` account should be changed immediately.

```
$ sudo cryptsetup luksChangeKey /dev/<DEVICE>5
$ sudo passwd root
```

#### Mac Boot

Boot the Mac into an external drive by pressing and releasing the power button. Then hold down the `OPTION` key (or the `ALT` key on a Windows keyboard) to access the Mac bootloader. Select the "EFI Boot" device.

**IMPORTANT** Any [Mac with an Apple T2 Security Chip](https://support.apple.com/en-us/HT208862), which are all Macs made in and after 2018, needs to [allow booting from external storage](https://support.apple.com/en-us/HT208198):

1. Turn on the Mac and immediately hold both the `COMMAND` and `r` keys to enter recovery mode.
2. Utilities > Startup Security Utility
    - Secure Boot = No Security (Does not enforce any requirements on the bootable OS.)
    - External Boot = Allow booting from external media (Does not restrict the ability to boot from any devices.)

#### Windows Boot

1. Secure Boot is not supported.
    - If using Windows and BitLocker is enabled then disable it first.
    - Then disable Secure Boot in the BIOS.
2. Disable fast startup and hibernation as these cause issues with booting Linux.
    - Long-term solution:
        - Control Panel > Hardware and Sound > Power Options > Change what the power buttons do > Change settings that are currently unavailable > (uncheck "Turn on fast startup (recommended)" and "Hibernate") > Save changes
    - Short-term solution:
        -  Fully shutdown Windows by holding the "SHIFT" key while selecting "Shut down", selecting to "Reboot", or by running the command ``shutdown /s /f /t 0``.
3. Configure Windows to use [UTC](https://wiki.archlinux.org/title/System_time#UTC_in_Microsoft_Windows) for the hardware clock.

#### Ventoy

As of winesapOS 4.2.0, [Ventoy](https://www.ventoy.net/en/index.html) is supported. It only works with UEFI boot (not legacy BIOS boot). The winesapOS resize root file system script currently does not work with Ventoy so this is most useful for recovery and troubleshooting purposes.

0. Install Ventoy v1.0.98 or newer onto an external drive.
1. Rename the image to `winesapos.vtoy`.
2. Copy the image to the Ventoy drive.

#### Dual-Boot

It is recommended to follow the [getting started](#getting-started) guide to install winesapOS onto its own internal drive if also using Linux or Windows. Then use the motherboard BIOS to change the boot device. For macOS, the only way to install it to the internal drive is via dual-boot.

However, it is possible to install winesapOS onto the same drive as Linux or Windows. That is what this guide will cover in more detail.

Only UEFI is supported for dual-boot installations of winesapOS. For legacy BIOS boot, [create and flash](#getting-started) a normal portable [release](https://github.com/winesapOS/winesapOS/releases) image such as the minimal or performance. Those all support both legacy BIOS boot and UEFI.

Install (if necessary) macOS or Windows first. Then proceed with installing winesapOS onto the same drive.

##### macOS Dual-Boot Preparation Guide

Only Intel Macs are supported.

1. As of Mac OS X 10.11 El Capitan, System Integrity Protection (SIP) was added for additional boot security. It needs to be disabled for rEFInd support.
    - Enter macOS Recovery mode.
        - Shutdown the Mac.
        - Press the power button. Then hold the `command` and `r` keys until the Apple logo appears. Then let go of those two keys.
    - Utilities > Terminal
    - Run the command `csrutil disable` to disable SIP.
2. Follow the [Mac Boot](#mac-boot) guide.
    - Reboot when done.
        - (Select the Apple logo in the top-left) > Restart
3. Install rEFInd. This is an alternative UEFI boot manager that has better compatibility with Linux.
    - [Download](https://sourceforge.net/projects/refind/) and extract `refind-bin-<VERSION>.zip`.
    - Open the Terminal app, navigate to the extracted folder, and then run `./refind-install`.
4. SIP can optionally be re-enabled now that rEFInd is installed.
5. Create free storage space for winesapOS.
    - Disk Utility > (select the primary drive) > Partition > + > Add Partition > Name: winesapOS, Format: ExFAT, Size: (enter the amount of space to use for winesapOS) > Apply > Partition > Continue > Done

##### Windows Dual-Boot Preparation Guide

1. Follow the [Windows Boot](#windows-boot) guide.
2. Create free storage space for winesapOS.
    - Disk Management (diskmgmt.msc) > (right-click on the "(C:)" partition) > Shrink Volume... > Enter the amount of space to shrink in MB: (enter the amount of space to use for winesapOS) > Shrink

##### winesapOS Dual-Boot Install Guide

**Semi-automated steps:**

1. Follow the winesapOS [getting started](#getting-started) guide to get the minimal image onto an external drive.
2. Boot into winesapOS that is on the external drive.
3. Use GParted to partition the free storage space. The labels are suffixed with the number zero "0" (not the letter "O").
    - For macOS:
        - (Right-click on the "exfat" partition) > Delete
        - (Right-click on the "unallocated" space) > New > New size (MiB): 1000, File system: fat32, Label: WOS-EFI0 > Add
    - Then for macOS and Windows:
        - (Right-click on the "unallocated" space) > New > New size (MiB): 1000, File system: ext4, Label: winesapos-boot0 > Add
        - (Right-click on the "unallocated" space) > New > File system: btrfs, Label: winesapos-root0 > Add
    - (Select the green check mark to "Apply All Operations") > Apply > Close
4. Run the "winesapOS Dual-Boot Installer (Beta)" desktop shortcut.
5. Turn off the computer, unplug the winesapOS external drive, and then turn on the computer.
6. Allow booting the original operating system again.

    - macOS
        - Hold `command` while booting up. Once booted into macOS, run `./refind-mkdefault` (requires Xcode to be installed).
    - Windows
        - Add Windows to the GRUB boot menu.
            ```
            # Enable os-prober. It is disabled by default.
            sudo crudini --ini-options=nospace --set /etc/default/grub "" GRUB_DISABLE_OS_PROBER false
            sudo grub-mkconfig -o /boot/grub/grub.cfg
            ```

**Manual steps:**

1. Follow the winesapOS [getting started](#getting-started) guide to get the minimal image onto an external drive.
    - This includes installer tools needed to install winesapOS onto an internal drive.
    - It also includes an exFAT partition that is accessible from any operating system.
2. Download the latest `winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar.zst` [release](https://github.com/winesapOS/winesapOS/releases).
    - Copy it to the `wos-drive`.
3. Boot into winesapOS that is on the external drive.
4. Use GParted to partition the free storage space. The labels are suffixed with the number zero "0" (not the letter "O").
    - For macOS:
        - (Right-click on the "exfat" partition) > Delete
        - (Right-click on the "unallocated" space) > New > New size (MiB): 1000, File system: fat32, Label: WOS-EFI0 > Add
    - Then for macOS and Windows:
        - (Right-click on the "unallocated" space) > New > New size (MiB): 1000, File system: ext4, Label: winesapos-boot0 > Add
        - (Right-click on the "unallocated" space) > New > File system: btrfs, Label: winesapos-root0 > Add
    - (Select the green check mark to "Apply All Operations") > Apply > Close
5. Mount the new partitions with winesapOS optimizations and features.
    ```
    # View hints about each partition.
    $ lsblk
    $ sudo mount -t btrfs -o subvol=/,compress-force=zstd:1,discard,noatime,nodiratime -L winesapos-root0 /mnt
    $ sudo btrfs subvolume create /mnt/.snapshots
    $ sudo btrfs subvolume create /mnt/home
    $ sudo mount -t btrfs -o subvol=/home,compress-force=zstd:1,discard,noatime,nodiratime -L winesapos-root0 /mnt/home
    $ sudo btrfs subvolume create /mnt/home/.snapshots
    $ sudo btrfs subvolume create /mnt/swap
    $ sudo mount -t btrfs -o subvol=/swap,compress-force=zstd:1,discard,noatime,nodiratime -L winesapos-root0 /mnt/swap
    $ sudo mkdir /mnt/boot
    $ sudo mount --label winesapos-boot0 /mnt/boot
    $ sudo mkdir /mnt/boot/efi
    # Mount the FAT32 EFI partition.
    # On macOS, use the newly created EFI partition.
    # On Windows, use the existing EFI partition. This is usually the first partition and 100 MiB in size.
    $ sudo mount /dev/<DEVICE>1 /mnt/boot/efi
    ```
6. Extract the winesapOS root file system archive.
    - Select the "wos-drive" drive in the Dolphin file manager to automatically mount it.
    - Extract the archive.
        ```
        $ sudo tar --extract --keep-old-files --verbose --file /run/media/winesap/wos-drive/winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar.zst --directory /mnt/
        ```
7. Configure the bootloader.
    ```
    $ grep -v -P "winesapos|WOS" /mnt/etc/fstab | sudo tee /mnt/etc/fstab
    $ genfstab -L /mnt | sudo tee -a /mnt/etc/fstab
    $ sudo mount --rbind /dev /mnt/dev
    $ sudo mount --rbind /sys /mnt/sys
    $ sudo mount -t proc /proc /mnt/proc
    $ sudo chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=winesapOS
    $ sudo chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    $ sudo chroot /mnt mkinitcpio -P
    $ sudo sync
    ```
8. Turn off the computer, unplug the winesapOS external drive, and then turn on the computer.
9. Allow booting the original operating system again.

    - macOS
        - Hold `command` while booting up. Once booted into macOS, run `./refind-mkdefault` (requires Xcode to be installed).
    - Windows
        - Add Windows to the GRUB boot menu.
            ```
            # Enable os-prober. It is disabled by default.
            $ sudo crudini --ini-options=nospace --set /etc/default/grub "" GRUB_DISABLE_OS_PROBER false
            $ sudo grub-mkconfig -o /boot/grub/grub.cfg
            ```

### First-Time Setup

After logging in for the first time as the `winesap` user, the first-time setup for winesapOS will appear. Users have the option to manually select their choices or go with the recommended defaults below.

| Setup | Recommended Default |
| --- | --- |
| Broadcom proprietary Wi-Fi driver | Automatic |
| Rotate screen | No |
| Older version of winesapOS | Stop and prompt user |
| Pacman mirror region | Automatic (GeoIP) |
| Graphics driver | Mesa |
| Swap method | zram |
| Time zone | Automatic (GeoIP) |
| Recommended productivity apps | Yes |
| Recommended gaming apps | Yes |
| Passwordless login\* | Yes (minimal and performance) and No (secure) |
| Hide GRUB boot menu | Yes |
| Upgrade firmware | Yes |
| Change user password | Yes |
| Change root password | Yes |
| Locale | Ask |

\*Press the enter/return key (the bottom-right key on the virtual keyboard) on the login screen for passwordless login.

### Upgrades

#### Minor Upgrades

Upgrades are supported and recommended between all minor releases of winesapOS. For example, it is supported to go from 3.0.0 to 3.2.1.

Where it makes sense, features are backported from newer versions of winesapOS. Bug and security fixes are also included to fix problems either with winesapOS itself or with upstream changes in Arch Linux. Even if a user never upgrades winesapOS, users will continue to get regular system upgrades from Arch Linux.

Before upgrading, please read the full [UPGRADE.md](https://github.com/winesapOS/winesapOS/blob/stable/UPGRADES.md) notes. This showcases what updates will happen automatically and what updates may need to be manually applied.

Development builds do not support upgrades. Here are the releases that we do support upgrades on:

| Release | Upgrades Supported |
| ------- | ------------------ |
| Stable | Yes |
| Release Candidate (RC) | Yes |
| Beta | No |
| Alpha | No |

Here is how to upgrade winesapOS. Do **NOT** use "Applications (bauh)" for upgrades, only for package installations.

- GUI = Launch the "winesapOS Upgrade" desktop shortcut.
- CLI = Launch the winesapOS upgrade script from the stable branch.

    ```
    curl https://raw.githubusercontent.com/winesapOS/winesapOS/stable/scripts/winesapos-upgrade.sh | sudo -E bash
    ```

#### Major Upgrades

- Open `Terminator`.
- Run a major upgrade of winesapOS.
    - Mac Linux Gaming Stick 2 to winesapOS 4:
        ```
        echo stick > /tmp/winesapos_user_name.txt
        export WINESAPOS_UPGRADE_FILES=false
        export WINESAPOS_UPGRADE_VERSION_CHECK=false
        curl https://raw.githubusercontent.com/winesapOS/winesapOS/stable/scripts/winesapos-upgrade.sh | sudo -E bash
        ```
    - winesapOS 3 to winesapOS 4:
        - GUI = Launch the "winesapOS Upgrade" desktop shortcut.
        - CLI:
            ```
            curl https://raw.githubusercontent.com/winesapOS/winesapOS/stable/scripts/winesapos-upgrade.sh | sudo -E bash
            ```

### Uninstall

If desired, it is possible to remove winesapOS specific files and configuration and switch back to upstream Arch Linux using an uninstall script. It will not remove anything that is related to improved hardware compatibility.

```
curl https://raw.githubusercontent.com/winesapOS/winesapOS/stable/scripts/winesapos-uninstall.sh | sudo -E bash
```

### Convert to winesapOS

It is possible to get an experience similar to winesapOS but on a different Linux distribution by installing applications that winesapOS provides.

What this conversion script does:

- For Arch Linux and Manjaro only:
    - Add winesapOS and Chaotic AUR repositories.
    - Install all AUR packages from winesapOS.
- For all Linux distributions:
    - Install all Flatpak packages from winesapOS.

What it does NOT do:

- Install all system packages from winesapOS (coming soon).
- Install support for specific computer hardware.
- Install desktop environments or tiling window managers.
- Modify the bootloader.

Run this script to convert to winesapOS:

```
curl https://raw.githubusercontent.com/winesapOS/winesapOS/stable/scripts/winesapos-convert.sh | bash
```

## Tips

### Windows Games on Steam

Enable Proton on Steam to allow installing Windows games on Linux. For more information about Proton, [read this starter guide](https://www.gamingonlinux.com/2019/07/a-simple-guide-to-steam-play-valves-technology-for-playing-windows-games-on-linux). Check the compatibility rating for games on Steam by using [ProtonDB](https://www.protondb.com/).

```
Settings > Steam Play > Enable Steam Play for Support Titles > Use this tool instead of game-specific selections from Steam > Compatibility tool: > (select the latest "Proton" version available) > OK
```

### Steam Deck Game Mode

On the SDDM login screen for the "winesap" user, the "Session" drop-down menu in the top-left can be used to change the session from "Plasma (Wayland)" to "Steam Big Picture (Wayland)". This provides the same experience as having a Steam Deck in "Game Mode" by launching Steam with Gamescope Session.

Switch from Game Mode to Desktop Mode:

- In Steam, select the "Power" menu and then select "Switch to Desktop".
- On the SDDM login page, use the top-left drop-down to select the desired session.
- Tap the password field to open the virtual keyboard.
- Press the enter key in the bottom-right of the virtual keyboard to login.

Known issues:

- A user must first login to the KDE Plasma desktop environment session and go through the winesapOS first-time setup. This will automatically download the Steam client bootstrap files required for the new Big Picture mode. Otherwise, install `steam` and then run "Steam (Runtime)" at least once to download the required files.
- Using this on devices that are not "Powered by SteamOS" certified will have varied results.
    - For example, configuring TDP for other devices will not work.
- NVIDIA support is still a work-in-progress. Mesa does not work yet. The NVIDIA open kernel module works but it is extremely slow.

Alternatively, Steam can be launched from KDE Plasma using the "Steam (Runtime)" desktop shortcut. Then it can be changed to be in the new Big Picture Mode.

There is also a session for Open Gamepad UI as an open source alternative front-end. Select the "OpenGamepadUI (Wayland)" session on the SDDM login screen. It has plugins for Steam, Lutris, and more.

### No Sound (Muted Audio)

When Mac hardware is detected, all sound is muted on boot because, on newer Macs, the experimental sound driver is extremely loud. This means that any volume changes will be reset on the next boot. Disable and stop the user (not system) mute service to allow the sound volume to be saved:

```
systemctl --user disable --now winesapos-mute.service
```

### Btrfs Backups

Snapper creates 6 monthly snapshots of the `/home` directory. snap-pac creates a snapshot of the root `/` directory before and after using `pacman`. Both the root and home configurations are set to only use a maximum of 50 GiB each.

During boot, GRUB will have a "winesapOS snapshots" section that will allow booting from a root directory snapshot. This will not appear on first boot because no backups have been taken yet. After a backup has been taken, the GRUB configuration file needs to be regenerated to scan for the new backups.

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

### VPN (ZeroTier)

A VPN is required for LAN gaming online. Use the free and open source ZeroTier VPN service for this.

**Host**

1. Only one person needs to create a [ZeroTier account](https://my.zerotier.com/).
2. They must then create a [ZeroTier network](https://clover.coex.tech/en/zerotier_vpn.html).
    1. Login to [ZeroTier Central](https://my.zerotier.com/).
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

**Challenge: the release image fails to be extracted from the zip file.**

**Solutions:**

1. **Verify the integrity of the downloaded zip files.**

    - Linux:

        ```
        sha512sum --check winesapos-<VERSION>-<TYPE>.sha512sum.txt
        ```

    - Windows (open Command Prompt as Administrator):

        ```
        C:\Windows\system32>CertUtil.exe -hashfile C:\Users\<USER>\Downloads\winesapos-<VERSION>-<TYPE>.sha512sum.txt SHA512
        ```

2. **Not enough free space.** Ensure you have 13 GiB (minimal image) or 31 GiB (performance image) of free space before downloading the zip files.
3. **If using PeaZip, it sometimes fails to extract to the current directory.** Try extracting to a different directory.

### winesapOS Not Booting

There are many different reasons why winesapOS may not be booting.

- Refer to the [Mac Boot](#mac-boot) and [Windows Boot](#windows-boot) guides to avoid common issues.
- USB mode.
    - If using a USB Type-C cable, try flipping it upside down (180 degrees).
        - If using a USB Type-C to Type-A adapter, only one of the USB Type-C sides is full speed so orientation does matter.
    - If using an external drive, set the USB mode to xHCI instead of DRD in the BIOS.
    - The USB cable or port may be loose. Try a different cable and port.
- SATA mode.
    - If using an internal drive, set the SATA mode to AHCI instead of RAID in the BIOS.
        - Some NVMe drives use a SATA (not PCIe) connector and also need this setting change.
- Legacy BIOS boot.
    - Older motherboards that do not support GPT partition layouts will not be able to boot winesapOS.
    - Manually converting winesapOS from GPT to MBR and re-installing the GRUB boot loader does not fix this issue.

### Access Boot Menu

If the recommended defaults of the first-time setup are used, then the GRUB boot menu will be hidden. It can still be accessed by using these keyboard shortcuts:

- UEFI = `SHIFT` + `F1`
- Legacy BIOS boot = `ESC[APE]` + `F1`

### Root File System Resizing

**Challenge: the root file system does not resize itself to use all available space on the storage device.**

**Solution:**

1. Re-enable the resize service, reboot, and then view the service log. Open up a [GitHub Issue](https://github.com/winesapOS/winesapOS/issues) with the full log output.

    ```
    sudo systemctl enable winesapos-resize-root-file-system
    sudo reboot
    ```

    ```
    sudo journalctl --unit winesapos-resize-root-file-system
    ```

### Read-Only File System

If using an external USB drive, it is possible to get errors about a `Read-only file system`. This is a hardware issue and indicates that the USB drive has been disconnected even if only for a fraction of a second. Short-term, reboot winesapOS to fix these errors. Long-term, try using a different USB port and/or drive and make sure that the drive does not move while in use. For the best experience, we recommend using an internal drive.

### Wi-Fi or Bluetooth Not Working

**Challenge: If Wi-Fi or Bluetooth is not working and Windows is installed, it could be from fast startup being enabled and/or Windows hibernating.**

**Solutions:**

- Macs
    - Refer to the [Apple Intel Macs](#apple-intel-macs) guide to install the correct driver and/or firmware.
- Windows
    - Refer to the [Windows Boot](#windows-boot) guide to disable fast startup and hibernation.

### Available Storage Space is Incorrect

**Challenge: the amount of reported free space seems too small or large.**

**Solutions:**

1. Btrfs is used as the root file system on winesapOS. The most reliable way to view the amount of storage in-use on Btrfs is with this command.

    ```
    sudo btrfs filesystem df /
    ```

2. Snapper is used to take Btrfs snapshots (1) every time Pacman installs, upgrades, or removes a package and (2) every month. Refer to the [Btrfs Backups](#btrfs-backups) section for more information on how to manage those snapshots.

### First-Time Setup Log Files

If the first-time setup fails or needs debugging, the last log file can be found and copied to the desktop by running these two commands:

```
$ sudo cp "/etc/winesapos/$(sudo ls -1 /etc/winesapos/ | grep setup | tail -n 1)" /home/winesap/Desktop/
$ sudo chown winesap:winesap "/home/winesap/Desktop/$(ls -1 ~/Desktop/ | grep setup_)"
```

### Two or More Set Ups of winesapOS Cause an Unbootable System

**Challenge: winesapOS uses labels for file system mounts which confuses the system if more than one label is found.**

**Solution:**

1. **Change the file system label of at least the root file system** on one of the winesapOS drives. It is recommended to change all of the labels on that same drive. **This can cause an unbootable system.** Manually review the contents of `/etc/fstab` to ensure it is correct.

    ```
    # Labels can be changed on mounted file systems.
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

    ```
    # GRUB needs to be updated with the new /etc/fstab information.
    sudo chroot <MOUNTED_ROOT_AND_BOOT_DIRECTORY> grub-mkconfig -o /boot/grub/grub.cfg
    ```

### Snapshot Recovery

**Challenges:**

1. winesapOS upgrade fails.
2. Old files need to be recovered.

**Solution:**

1. At the GRUB boot menu select "winesapOS snapshots" and then the desired backup to load. The filesystem will be read-only by default. It can be set to enable writes with this command:

    ```
    $ sudo btrfs property set -ts /.snapshots/<BTRFS_SNAPSHOT_ID> ro false
    ```

For more advanced recovery using ``overlayfs`` on-top of a read-only filesystem, refer to this [grub-btrfs GitHub issue](https://github.com/Antynea/grub-btrfs/issues/92).

### Reinstalling winesapOS

Reinstalling winesapOS on-top of an existing winesapOS installation of the same exact version and image type can cause issues. This is because the partitions are perfectly aligned which leads to overlapping data. Even wiping the partition table is not enough. For the best results, it is recommended to completely wipe at least the first 25 GiB of the storage device. **WARNING:** This will delete any existing data on that storage device.

```
dd if=/dev/zero of=/dev/<DEVICE> bs=1M count=25000
```

### Bad Performance on Battery

When using a portable device such as a laptop or gaming handheld, the operating system goes into a battery saver mode by default. This can be disabled to get maximum performance.

```
sudo systemctl disable --now auto-cpufreq
```

## Frequently Asked Questions (FAQ)

- **Is this the Mac Linux Gaming Stick project?**
    - Yes. Version 1 and 2 of the project were called Mac Linux Gaming Stick. In version 3, we rebranded to winesapOS.
- **How do you pronounce winesapOS?**
    - `wine`-`sap`-`o`-`s`.
- **What is the relevance of the word "winesap" in winesapOS?**
    - It is a type of apple which signifies how we were originally developing for Intel Macs. It also has the word "wine" in it which is the [name](https://www.winehq.org/) of the project used to enable Windows gaming on Linux.
- **What makes this different than adding persistent storage to a live CD with [Universal USB Installer or YUMI](https://www.pendrivelinux.com/)?**
    - Having persistent storage work via these hacky methods can be hit-or-miss depending on the distribution. winesapOS was built from the ground-up to have persistent storage. It also features automatic backups, various gaming tools, has support for Macs, and more.
- **Are Arm Macs supported?**
    - No. We recommend using [Asahi Linux](https://asahilinux.org/) (Arch Linux), [Fedora Asahi Remix](https://asahilinux.org/fedora/), or [Ubuntu Asahi](https://ubuntuasahi.org/) instead.
- **Is legacy PC hardware support?**
    - No. If your PC is too old and winesapOS does not boot on it, we recommend to use the Slackware variant of [Slax](https://www.slax.org/) instead.
- **Is winesapOS a Linux distribution?**
    - Yes. We provide customized packages, a package repository, various optimizations, and our own upgrade process. winesapOS is based on Arch Linux with optional support for Manjaro.
- **Do I have to install winesapOS?**
    - No. No installation is required. Flash a [release image](https://github.com/winesapOS/winesapOS/releases) to a drive and then boot from it. Everything is already installed and configured.
- **What if winesapOS was abandoned?**
    - We have no intentions on ever abandoning winesapOS. Even if that happened, since this is an opinionated installation of an Arch Linux distribution, it will continue to get normal operating system updates. The [uninstall](#uninstall) script can also be used to switch back to upstream Arch Linux.
- **Can anyone build winesapOS?**
    - Yes. Refer to the [CONTRIBUTING.md](CONTRIBUTING.md) documentation.
- **Can winesapOS be built with a different Linux distribution?**
    - Yes. We support Arch Linux and Manjaro as build targets. As of winesapOS 4, Arch Linux is the default target that is used for our releases.
- **Is winesapOS affiliated with Valve?**
    - No. We are an independent project.

## Contributors

Here are community contributors who have helped the winesapOS project.

**Founder:**

- [LukeShortCloud](https://github.com/LukeShortCloud)

**Code:**

- [Mohamed A. Said](https://github.com/SrcEngGuy)
- [mtkennerly](https://github.com/mtkennerly)
- [ohaiibuzzle](https://github.com/ohaiibuzzle)
- [soredake](https://github.com/soredake)
- [Thijzer](https://github.com/Thijzer)
- [wallentx](https://github.com/wallentx)

**Financial:**

- Mark Dougherty
- Mike Artz
- [Playtron](https://www.playtron.one/)

## User Surveys

These are anonymous surveys done with Linux gaming community members. Most, but not all, are winesapOS users.

----

Favorite (non-Valve) handheld PC brand:

* AYANEO = 50%
* GPD = 33.3%
* ONEXPlayer = 0%
* Other = 16.7%

6 votes.

There were no comments about what the "Other" brand is so that is unknown.

https://twitter.com/LukeShortCloud/status/1649078025634598912

----

Favorite desktop environments:

- GNOME = 40%
- Plasma by KDE = 40%
- Xfce = 4%
- Other = 16%

25 votes.

"Other" included specific mentions from the community about Cinnamon (for its similarity to Windows) and Sway (for its tiling features).

https://twitter.com/LukeShortCloud/status/1659279345926516737

## History

| Release Version/Tag | Project Name | Operating System | Desktop Environment | Release Images |
| ------------------- | ------------ | ---------------- | ------------------- | -------------- |
| 4.2.0 | winesapOS | Arch Linux | KDE Plasma | Performance, Minimal, and Minimal Root File System |
| 4.1.0 | winesapOS | Arch Linux | KDE Plasma | Performance, Secure, Minimal, and Minimal Root File System |
| 4.0.0 | winesapOS | Arch Linux | KDE Plasma | Performance, Secure, and Minimal |
| 3.2.0 | winesapOS | SteamOS 3 | KDE Plasma | Performance, Secure, and Minimal |
| 3.0.0 | winesapOS | SteamOS 3 | KDE Plasma | Performance and Secure |
| 2.2.0 | Mac Linux Gaming Stick | Manjaro | Cinnamon | Performance and Secure |
| 2.0.0 | Mac Linux Gaming Stick | Manjaro | Cinnamon | Performance |
| 1.0.0 | Mac Linux Gaming Stick | Ubuntu 20.04 | Cinnamon | None |

## License

[GPLv3](LICENSE)
