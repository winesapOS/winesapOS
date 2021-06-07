# Mac Linux Gaming Stick

Linux gaming, on a stick (flash drive or external SSD), designed for Mac enthusiasts.

This is an opinionated take on creating a portable USB drive with Linux installed to enable gaming on any computer via Steam and Proton/Wine. This project is tailored towards Macs by providing relevant third-party drivers.

**TABLE OF CONTENTS**

* [Mac Linux Gaming Stick](#mac-linux-gaming-stick)
   * [macOS Limitations](#macos-limitations)
   * [Features](#features)
   * [Setup](#setup)
      * [Wireless Keyboard and Mouse](#wireless-keyboard-and-mouse)
      * [VPN (ZeroTier)](#vpn-zerotier)
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
    - DXVK, via a modified version of MoltenVK, has limited support.
        - MoltenVK does not expose all of the features in Vulkan required by DXVK.
        - MoltenVK only exposes 64-bit Vulkan support. This means that DirectX 11 games that use 32-bit libraries will not work via DXVK.
    - Vulkan is not supported.
    - Linux has kernel-level optimizations for Wine.

## Features

- **Any AMD or Intel computer can run mac-linux-gaming-stick.** This project is not limited to Macs.
- **All Intel Macs are supported.** Linux works on most Macs out-of-the-box these days. Drivers are pre-installed for newer hardware where native Linux support is missing.
    - [Linux on Mac compatiblity guide](https://github.com/Dunedan/mbp-2016-linux).
    - [snd_hda_macbookpro](https://github.com/davidjo/snd_hda_macbookpro) provides a sound driver for newer Macs with Cirrus sound board chips.
    - [macbook12-spi-driver](https://github.com/roadrunner2/macbook12-spi-driver) provides the Touch Bar driver for newer MacBook Pros.
    - [mbp2018-bridge-drv](https://github.com/MCMrARM/mbp2018-bridge-drv) provides the MacBook Bridge/T2 driver for MacBooks from >= 2018. This allows the keyboard, sound, and touchpad hardware to function properly.
- **Portability.** The flash drive should be bootable on both BIOS and UEFI systems.
- **Persistent storage.** Unlike traditional Linux live media, all storage will be persistent and kept upon reboots.
    - Upon the first boot, the root partition will be expanded to utilize all available space.
- **Supportability.** Linux will be easy to troubleshoot remotely.
    - Access:
        - [Chrome Remote Desktop](https://remotedesktop.google.com/) via [Google Chrome](https://www.google.com/chrome/) can be used to provide remote access similar to Windows RDP.
        - SSH can be accessed via clients on the same [ZeroTier VPN](https://www.zerotier.com/) network.
        - [tmate](https://tmate.io/) makes sharing SSH sessions without VPN connections easy.
    - Tools:
        - [ClamAV](https://www.clamav.net/) is an open source anti-virus scanner.
        - [QDirStat](https://github.com/shundhammer/qdirstat) provides a graphical user interface to view storage space usage.
- **Gaming support** out-of-the-box.
    - [Lutris](https://lutris.net/), [Steam](https://store.steampowered.com/), and [Wine Staging](https://wiki.winehq.org/Wine-Staging) are all installed.
    - Open source OpenGL and Vulkan drivers are installed for AMD and Intel graphics.
    - [GameMode](https://github.com/FeralInteractive/gamemode) is available to be used to speed up games.
    - ZeroTier VPN can be used to play LAN-only games online with friends.
- **Minimze writes** to the flash drive to improve its longevity.
    - Root file system is mounted with the options `noatime` and `nodiratime` to not write the access times for files and directories.
    - Temporary directories with heavy writes (`/tmp/`, `/var/log/`, and `/var/tmp/`) are mounted as RAM-only file systems.
    - [systemd-journald](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html) is configured to use volatile (RAM-only) storage for all system logs.
    - Swappiness level is set to 10% (down from the default of 60%).
- **Full backups** via Btrfs.
    - [Snapper](https://github.com/openSUSE/snapper) takes 12 monthly and 1 annual snapshots.
    - Snapper takes a backup whenever the `pacman` package manager is used.
    - [grub-btrfs](https://github.com/Antynea/grub-btrfs) automatically generates a GRUB menu entry for all of the Btrfs backups.
- **No automatic operating system updates.** Updates should always be intentional and planned.
- **Battery optimizations.**
    - The [auto-cpufreq](https://github.com/AdnanHodzic/auto-cpufreq) and [TLP](https://github.com/linrunner/TLP) services provide automatic power management.
- **Fully automated installation.**

Not planned to support:

- Built-in WiFi.

It is easier and more reliable to buy additional hardware and use a USB-C hub than to rely on hacky Linux drivers for Mac. Workarounds do exist for [WiFi](https://gist.github.com/roadrunner2/1289542a748d9a104e7baec6a92f9cd7#gistcomment-3080934) on the 2016-2017 MacBook Pros however speeds are reported as being slower.

## Setup


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

### Mac Boot

Boot the Mac into the flash drive by pressing and releasing the power button. Then hold down the "Option" key (or the "Alt" key on a Windows keyboard) to access the Mac bootloader. Select the "EFI Boot" device.

## Tips

- Test booting up the flash drive first before buying speakers, a Bluetooth adapter, a WiFi adapter, and/or other hardware. Depending on the Mac, the built-in hardware may work out-of-the-box.
- Temporarily allow the `brcmfmac` and `brcmutil` drivers to see if the built-in WiFi will work. Remove the relevant entries from `/etc/modprobe.d/mac-linux-gaming-stick.conf` and then use `modprobe` to manually load the drivers.
- Buy a Bluetooth and/or WiFi adapater that is natively supported by the Linux kernel or is at least packaged for Ubuntu. Almost every USB speaker will work on Linux.
- Consider buying an external SSD instead of a flash drive for a longer life-span, more storage, and faster speeds.
- Plug everything into the USB-C hub before connecting it to the comptuer and turning the computer on.
- Do NOT move the USB-C hub after plugging it in and booting up Linux. It can easily disconnect leading to a corrupt file system.
- Avoid using Flatpak and Snap packages. These use a lot of additional space compared to native system packages. Programs packaged this way are also slower.
- Delete old Btrfs backups when the flash drive is running low on storage space.
- Enable Proton for all Windows games. This will allow them to run in Linux. For more information about Proton, [read this starter guide](https://www.gamingonlinux.com/2019/07/a-simple-guide-to-steam-play-valves-technology-for-playing-windows-games-on-linux). Check the compatibility rating for games on Steam by using [ProtonDB](https://www.protondb.com/).

    ```
    Settings > Steam Play > Enable Steam Play for Support Titles > Use this tool instead of game-specific selections from Steam > Compatibility tool: > (select the latest "Proton" version available) > OK
    ```

## License

GPLv3
