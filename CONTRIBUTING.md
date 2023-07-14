# winesapOS Contributor Guide

* [winesapOS Contributor Guide](#winesapos-contributor-guide)
   * [Getting Started](#getting-started)
   * [Architecture](#architecture)
      * [Partitions](#partitions)
      * [Drivers](#drivers)
         * [Mac](#mac)
      * [Files](#files)
   * [Build](#build)
      * [Download the Installer](#download-the-installer)
      * [Create Virtual Machine](#create-virtual-machine)
         * [virt-install (CLI)](#virt-install-cli)
         * [virt-manager (GUI)](#virt-manager-gui)
         * [GNOME Boxes (GUI)](#gnome-boxes-gui)
      * [Environment Variables for Installation](#environment-variables-for-installation)
      * [Install winesapOS](#install-winesapos)
      * [Automated Container Build](#automated-container-build)
      * [Tests](#tests)
         * [Matrix](#matrix)
         * [Automatic](#automatic)
         * [Manual](#manual)
   * [Workflows](#workflows)
       * [Adding Applications](#adding-applications)
       * [Importing SteamOS 3 Source Code](#importing-steamos-3-source-code)
           * [Automatically](#automatically)
           * [Manually](#manually)
       * [Updating Linux Kernels](#updating-linux-kernels)
       * [Build Packages for winesapOS Repository](#build-packages-for-winesapos-repository)
           * [Environment Variables for Repository Build](#environment-variables-for-repository-build)
       * [Custom Scripts](#custom-scripts)
       * [Wayback Machine Backups](#wayback-machine-backups)
   * [Release](#release)
      * [Schedule](#schedule)
      * [Checklist](#checklist)
      * [Publishing](#publishing)

## Getting Started

There are various different ways to contribute to winesapOS:

-  Open up new [GitHub issues](https://github.com/LukeShortCloud/winesapOS/issues) for feature requests or bugs to be addressed.
-  Help [create documentation](https://github.com/LukeShortCloud/winesapOS/issues?q=is%3Aopen+is%3Aissue+label%3Adocumentation), [create new features](https://github.com/LukeShortCloud/winesapOS/issues?q=is%3Aopen+is%3Aissue+label%3Aenhancement), or [fix bugs](https://github.com/LukeShortCloud/winesapOS/issues?q=is%3Aopen+is%3Aissue+label%3Abug).
    -  Extra attention and help is needed on [these issues](https://github.com/LukeShortCloud/winesapOS/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22).
    -  For code contributions, first copy of the pre-commit script to ensure the code passes these tests:

        ```
        $ cp git/hooks/pre-commit .git/hooks/pre-commit
        ```

This guide focuses on the technical architecture and workflows for winesapOS development.

## Architecture

### Partitions

**Performance Image**

| Partition | Label | File System | Size | Description |
| --------- | ----- | ----------- | ---- |------------ |
| 1 | None | None | 2 MiB | BIOS boot backwards compatibility. |
| 2 | wos-drive | exFAT | 16 GiB | Cross-platform flash drive storage. |
| 3 | WOS-EFI | FAT32 | 500 MiB | UEFI boot firmware. |
| 4 | winesapos-boot | ext4 | 1 GiB | GRUB boot loader and Linux kernel. |
| 5 | winesapos-root | Btrfs | 100% | The root and home file systems. |

**Secure Image**

| Partition | Label | File System | Size | Description |
| --------- | ----- | ----------- | ---- |------------ |
| 1 | None | None | 2 MiB | BIOS boot backwards compatibility. |
| 2 | wos-drive | exFAT | 16 GiB | Cross-platform flash drive storage. |
| 3 | WOS-EFI | FAT32 | 500 MiB | UEFI boot firmware. |
| 4 | winesapos-boot | ext4 | 1 GiB | GRUB boot loader and Linux kernel. |
| 5 | winesapos-luks | LUKS | 100% | The encrypted root and home file systems. |
| /dev/mapper/cryptroot | winesapos-root | Btrfs | 100% | The root and home file systems. |

**Minimal Image**

| Partition | Label | File System | Size | Description |
| --------- | ----- | ----------- | ---- |------------ |
| 1 | None | None | 2 MiB | BIOS boot backwards compatibility. |
| 2 | WOS-EFI | FAT32 | 500 MiB | UEFI boot firmware. |
| 3 | winesapos-boot | ext4 | 1 GiB | GRUB boot loader and Linux kernel. |
| 4 | winesapos-root | Btrfs | 100% | The root and home file systems. |

## Drivers

### Mac

These drivers are provided for better compatibility with the lastest Macs with Intel processors:

- **apple-bce = T2 driver** required for storage, mouse, keyboard, and audio support. We provide a [git repository](https://github.com/LukeShortCloud/mbp2018-bridge-drv/tree/mac-linux-gaming-stick) that syncs up both the [t2linux](https://github.com/t2linux/apple-bce-drv) and [macrosfad](https://github.com/marcosfad/mbp2018-bridge-drv) forks. It provides the newer kernel compatibility from t2linux and also a DKMS module from macrosfad for easily installing the kernel driver.
- **macbook12-spi-driver-dkms = MacBook Pro Touch Bar driver.** The package is installed from the [AUR](https://aur.archlinux.org/packages/macbook12-spi-driver-dkms/).
- **snd_hda_macbookpro = Sound driver.** This requires the **apple-bce** driver to work on some Macs. We provide a [git repository](https://github.com/LukeShortCloud/snd_hda_macbookpro/tree/mac-linux-gaming-stick) that modifies the installation script to install for all Linux kernels found on the system instead of just the running Linux kernel.

## Files

These are a list of custom files and script that we install as part of winesapOS:

- `/etc/NetworkManager/conf.d/wifi_backend.conf` = Configures NetworkManger to use the IWD backend.
    - Source: `scripts/winesapos-install.sh`
- `/etc/modprobe.d/framework-als-deactivate.conf` = If a Framework laptop is detected, the ambient light sensor is disabled to fix input from special keys on the keyboard.
    - Source: `scripts/winesapos-setup.sh`
- `/etc/pacman.conf` = On SteamOS builds, this provides the correct order of enabled repositories. `[jupiter]` and `[holo]` come first and have package signatures disabled (Valve does not provide any). Then the Arch Linux repositories.
    - Source: `files/etc-pacman.conf_steamos`
- `/etc/snapper/configs/{root,home}` = The Snapper configuration for Btrfs backups.
    - Source: `files/etc-snapper-configs-root`
- `/etc/systemd/system/snapper-cleanup-hourly.timer` = A systemd timer for cleaning up Snapper snapshots every hour.
    - Source: `scripts/winesapos-install.sh`
- `/etc/systemd/user/winesapos-mute.service` = A user (not system) service for muting all audio. This is required for some newer Macs that have in-development hardware drivers that are extremely loud by default.
    - Source: `files/winesapos-mute.service`
- `/usr/local/bin/winesapos-mute.sh` = The script for the winesapos-mute.service.
    - Source: `scripts/winesapos-mute.sh`
- `/etc/systemd/system/pacman-mirrors.service` = On Manjaro builds, this provides a service to find and configure the fastest mirrors for Pacman. This is not needed on Arch Linux builds as it has a Reflector service that comes with a service file. It is also not needed on SteamOS builds as Valve provides a CDN for their single mirror.
    - Source: `files/pacman-mirrors.service`
- `/etc/systemd/system/winesapos-resize-root-file-system.service` = A service that runs a script to resize the root file system upon first boot.
    - Source: `winesapos-resize-root-file-system.service`
- `/etc/systemd/system/winesapos-touch-bar-usbmuxd-fix.service` = A workaround for MacBook Pros with a Touch Bar. This will allow iOS devices to connect on Linux again. This service will show an error during boot if winesapOS boots on a system that is not a Mac with a Touch Bar.
    - Source: `files/winesapos-touch-bar-usbmuxd-fix.service`
- `/etc/winesapos/graphics` = The graphics type that was selected during the setup process: amd, intel, nvidia-new, nvidia-old, virtualbox, or vmware.
    - Source: `scripts/winesapos-setup.sh`
- `/etc/winesapos/IMAGE_TYPE` = The image type that was set during the build process.
    - Source: `scripts/winesapos-install.sh`
- `/etc/winesapos/VERSION` = The version of winesapOS that is installed.
    - Source: `VERSION`
- `/usr/local/bin/winesapos-touch-bar-usbmuxd-fix.sh` = The script used for the winesapos-touch-bar-usbmuxd-fix.service.
    - Source: `files/winesapos-touch-bar-usbmuxd-fix.sh`
- `/home/winesap/.winesapos/winesapos-setup.desktop` = A desktop shortcut for the winesapOS First-Time Setup wizard.
    - Source: `files/winesapos-setup.desktop`
- `/home/winesap/.winesapos/winesapos-upgrade.desktop` = A desktop shortcut for the winesapOS Upgrade wizard.
    - Source: `files/winesapos-upgrade.desktop`
- `/usr/local/bin/winesapos-resize-root-file-system.sh` = The script used for the winesapos-resize-root-file-system.service.
    - Source: `scripts/winesapos-resize-root-file-system.sh`
- `/home/winesap/.winesapos/winesapos-setup.sh` = The script used for the winesapOS First-Time Setup wizard.
    - Source: `scripts/winesapos-setup.sh`
- `/home/winesap/.winesapos/winesapos_logo_icon.png` = The winesapOS logo as a 96x96 icon for the winesapOS First-Time Setup and winesapOS Upgrade desktop shortcuts.
    - Source: `files/winesapos_logo_icon.png`
- `/home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh` = The script used for the winesapOS Upgrade wizard. It pulls the latest upgrade script from the "stable" branch of winesapOS.
    - Source: `scripts/winesapos-upgrade-remote-stable.sh`

## Build

### Download the Installer

Depending on which Arch Linux distribution you want to build, download the related installer. Both Arch Linux and Manjaro provide ISOs for a live CD environment. The Steam Deck recovery image is a block device so it needs to be configured differently in a virtual machine before installing winesapOS.

- [Arch Linux ISO](https://archlinux.org/download/)

    - As of winesapOS 3.1.0, builds are created using the Arch Linux ISO to provide newer base system packages than SteamOS. The official SteamOS repositories and customized packages are still used as part of the build.

- [Manjaro KDE Plasma ISO](https://manjaro.org/downloads/official/kde/)
- [Steam Deck Recovery Image (for SteamOS 3)](https://store.steampowered.com/steamos/download/?ver=steamdeck&snr=) (default)

### Create Virtual Machine

A virtual machine is used to build winesapOS in a safe and isolated manner. The disks on the hypervisor will not be touched. It is assumed that QEMU/KVM will be used although other hypervisors can be used.

Requirements:

- UEFI boot
- 2 vCPUs
- 12 GB RAM
- Storage
    - Performance or secure image = 29 GiB storage (to fit on a 32 GB flash drive)
    - Minimal image = 7 GiB storage (to fit on an 8 GB flash drive)

#### virt-install (CLI)

- Create the virtual storage device.

    - Performance or secure image:

        ```
        sudo qemu-img create -f raw -o size=29G /var/lib/libvirt/images/winesapos.img
        ```

    - Minimal image:

        ```
        sudo qemu-img create -f raw -o size=7G /var/lib/libvirt/images/winesapos.img
        ```

- Create the virtual machine to use for installing winesapOS.

    - Arch Linux and Manjaro use an installer ISO image.

        ```
        sudo virt-install --name winesapos --boot uefi --vcpus 2 --memory 12288 --disk path=/var/lib/libvirt/images/winesapos.img,bus=virtio,cache=none --cdrom=/var/lib/libvirt/images/<INSTALLER_ISO>
        ```

    - SteamOS 3 uses a recovery image.

        ```
        sudo virt-install --name winesapos --boot uefi --vcpus 2 --memory 12288 --disk path=/var/lib/libvirt/images/steamdeck-recovery-1.img,bus=virtio,cache=none --disk path=/var/lib/libvirt/images/winesapos.img,bus=virtio,cache=none
        ```

#### virt-manager (GUI)

Arch Linux and Manjaro:

1. Virtual Machine Manager (virt-manager)
2. File
3. New Virtual Machine
4. Local install media (ISO image or CDROM)
5. Forward
6. Choose ISO or CDROM install media: <INSTALLER_ISO>
7. Forward
8. Memory: 12288
9. CPUs: 2
10. Forward
11. Enable storage for this virtual machine: yes
12. Create a disk image for the virtual machine:

   - Performance or secure image = 29.0 GiB
   - Minimal image = 7.0 GiB

13. Forward
14. Name: winesapOS
15. Customize configuration before install: yes
16. Finish
17. Overview
18. Firmware: UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.secboot.fd
19. Apply
20. Begin Installation

SteamOS 3:

1. Virtual Machine Manager (virt-manager)
2. File
3. New Virtual Machine
4. Import existing disk image
5. Provide the existing storage path: steamdeck-recovery-1.img
6. Choose the operating system you are installing: Arch Linux (archlinux)
7. Forward
8. Memory: 12288
9. CPUs: 2
10. Foward
11. Name: winesapOS
11. Customize configuration before install: yes
12. Finish
13. Overview
14. Firmware: UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.secboot.fd
15. Apply
16. Add Hardware
17. Storage
18. Create a disk image for the virtual machine:

   - Performance or secure image = 29.0 GiB
   - Minimal image = 7.0 GiB

19. Finish
20. Begin Installation

#### GNOME Boxes (GUI)

GNOME Boxes can be installed on any Linux distribution using Flatpak: `flatpak install org.gnome.Boxes`.

1. \+
2. Download and operating system
3. (Select the three dots to show all available operating systems)
4. (Search for and select "Arch Linux x86_64 (Live)")
5. Review and Create

   -  Memory: 12.0 GiB
   -  Storage limit:

      - Performance or secure image = 29.0 GiB
      - Minimal image = 7.0 GiB

   -  Enable EFI: Yes

6. Create

The created QCOW2 image will be stored as a file here: `~/.var/app/org.gnome.Boxes/data/gnome-boxes/images/archlinux`. The downloaded ISO is stored as a file here: `~/Downloads/archlinux-x86_64.iso`.

### Environment Variables for Installation

For specialized builds, use environment variables to modify the installation settings.

```
$ export <KEY>=<VALUE>
```

| Key | Values | Performance Value (Default) | Secure Value | Minimal Value | Description |
| --- | ------ | --------------------------- | ------------ | ------------- | ----------- |
| WINESAPOS_DEBUG_INSTALL | true or false | true | true | true | Use `set -x` for debug shell logging during the installation. |
| WINESAPOS_DEBUG_TESTS | true or false | false | false | false | Use `set -x` for debug shell logging during the tests. |
| WINESAPOS_ENABLE_TESTING_REPO | true or false | false | false | false | Use the `[winesapos-testing]` repository instead of the stable `[winesapos]` repository during the installation. |
| WINESAPOS_BUILD_IN_VM_ONLY | true or false | true | true | true | If the build should fail and exit if it is not in a virtual machine. Set to `false` for a bare-metal installation. |
| WINESAPOS_CREATE_DEVICE | true or false | false | false | false | If the build should create and use an image file instead of using an existing block device. |
| WINESAPOS_CREATE_DEVICE_SIZE | integer for GiB | (None) | (None) | (None) | Manually override the default values for the device size (13 GiB with no portable storage and 29 GiB with). |
| WINESAPOS_DEVICE | | vda | vda | vda | If WINESAPOS_CREATE=false, then use the existing `/dev/${WINESAPOS_DEVICE}` block device to install winesapOS onto. |
| WINESAPOS_ENABLE_PORTABLE_STORAGE | | true | true | false | If the 16 GiB exFAT flash drive storage should be enabled. |
| WINESAPOS_BUILD_CHROOT_ONLY | false | false | false | If partitioning and GRUB should be skipped for a chroot installation. |
| WINESAPOS_INSTALL_DIR | | /winesapos | /winesapos | /winesapos | The chroot directory where winesapOS will be installed into. |
| WINESAPOS_DISTRO | arch, manjaro, or steamos | steamos | steamos | steamos | The Linux distribution to install with. |
| WINESAPOS_HTTP_PROXY | | | (None) | (None) | (None) | The HTTP, HTTPS, FTP, and Rsync proxy to use for the build. |
| WINESAPOS_HTTP_PROXY_CA | | | (None) | (None) | (None) | The certificate authority file to import for the HTTPS_PROXY. |
| WINESAPOS_DE | cinnamon, gnome, or plasma | plasma | plasma | plasma | The desktop environment to install. |
| WINESAPOS_USER_NAME | | winesap | winesap | winesap | The name of the user to create. |
| WINESAPOS_ENCRYPT | true or false | false | true | false | If the root partition should be encrypted with LUKS. |
| WINESAPOS_ENCRYPT_PASSWORD | | password | password | password | The default password for the encrypted root partition. |
| WINESAPOS_LOCALE | | ``en_US.UTF-8 UTF-8`` | ``en_US.UTF-8 UTF-8`` | ``en_US.UTF-8 UTF-8`` | The locale to use for ``/etc/locale.gen``. |
| WINESAPOS_APPARMOR | true or false | false | true | false | If Apparmor should be installed and enabled. |
| WINESAPOS_PASSWD_EXPIRE | true or false | false | true | false | If the `root` and `winesap` user passwords will be forced to be changed after first login. |
| WINESAPOS_SUDO_NO_PASSWORD | true or false | true | false | true | If the user can run `sudo` without entering a password. |
| WINESAPOS_FIREWALL | true or false | false | true | false | If a firewall (`firewalld`) will be installed. |
| WINESAPOS_CPU_MITIGATIONS | true or false | false | true | false | If processor mitigations should be enabled in the Linux kernel. |
| WINESAPOS_DISABLE_KERNEL_UPDATES | true or false | true | false | true | If the Linux kernels should be excluded from being upgraded by Pacman. |
| WINESAPOS_DISABLE_KWALLET | true or false | true | false | true | If Kwallet should be enabled for securing various passwords. |
| WINESAPOS_ENABLE_KLIPPER | true or false | true | false | true | If Klipper should be disabled (as much as it can be) for storing copied text. |
| WINESAPOS_INSTALL_GAMING_TOOLS | true or false | true | true | false | Install all gaming tools and launchers. |
| WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS | true or false | true | true | false | Install all productivity tools. |
| WINESAPOS_AUTO_LOGIN | true or false | true | false | true | Set the default user to login automatically without a password. |
| WINESAPOS_IMAGE_TYPE | minimal, performance, or secure | performance | secure | minimal | The image type to set in the file ``/etc/winesapos/IMAGE_TYPE``. |
| WINESAPOS_CUSTOM_SCRIPT | | (None) | (None) | (None) | A custom script to run before the installation does a cleanup. |

### Install winesapOS

Once the virtual machine is running, a distribution of Arch Linux for winesapOS can be installed. An automated script is provided to fully install the operating system. This script will only work in a virtual machine. Clone the entire project repository. This will provide additional files and scripts that will be copied into the virtual machine image.

SteamOS 3 requires making the root file system writable, setting up Pacman keyrings for Arch Linux, and then installing the required `zsh` dependency.

```
$ sudo steamos-readonly disable
$ sudo pacman -S -y
$ sudo pacman-key --init
$ sudo pacman-key --populate archlinux
$ sudo pacman -S zsh
```

Arch Linux requires installing the required `git` dependency.

```
$ sudo pacman -S -y
$ sudo pacman -S git
```

Clone the GitHub repository:

```
$ git clone https://github.com/lukeshortcloud/winesapos.git
$ cd winesapos/scripts/
```

Before running the installation script, optionally set environment variables to configure the build. Use `sudo -E` to load the environment variables.

- Performance-focused image build:

    - Arch Linux and SteamOS 3 hybrid (default):

        ```
        # export WINESAPOS_DISTRO=steamos
        # ./winesapos-install.sh
        ```

    - Arch Linux:

        ```
        # export WINESAPOS_DISTRO=arch
        # ./winesapos-install.sh
        ```

    - Manjaro and SteamOS 3 hybrid:

        ```
        $ export WINESAPOS_DISTRO=steamos
        $ sudo -E ./winesapos-install.sh
        ```

    - Manjaro:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ sudo -E ./winesapos-install.sh
        ```

    - SteamOS 3:

        ```
        $ export WINESAPOS_DEVICE=vdb
        $ sudo -E ./winesapos-install.sh
        ```

- Security-focused image build requires first sourcing the environment variables:

    - Arch Linux and SteamOS 3 hybrid:

        ```
        # export WINESAPOS_DISTRO=steamos
        # . ./env/winesapos-env-secure.sh
        # ./winesapos-install.sh
        ```

    - Arch Linux:

        ```
        # export WINESAPOS_DISTRO=arch
        # . ./env/winesapos-env-secure.sh
        # ./winesapos-install.sh
        ```

    - Manjaro and SteamOS 3 hybrid:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ . ./env/winesapos-env-secure.sh
        $ sudo -E ./winesapos-install.sh
        ```

    - Manjaro:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ . ./env/winesapos-env-secure.sh
        $ sudo -E ./winesapos-install.sh
        ```

    - SteamOS 3:

        ```
        $ export WINESAPOS_DEVICE=vdb
        $ . ./env/winesapos-env-secure.sh
        $ sudo -E ./winesapos-install.sh
        ```

- Minimal storage-focused image build requires first sourcing the environment variables:

    - Arch Linux and SteamOS 3 hybrid:

        ```
        # export WINESAPOS_DISTRO=steamos
        # . ./env/winesapos-env-minimal.sh
        # ./winesapos-install.sh
        ```

    - Arch Linux:

        ```
        # export WINESAPOS_DISTRO=arch
        # . ./env/winesapos-env-minimal.sh
        # ./winesapos-install.sh
        ```

    - Manjaro and SteamOS 3 hybrid:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ . ./env/winesapos-env-minimal.sh
        $ sudo -E ./winesapos-install.sh
        ```

    - Manjaro:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ . ./env/winesapos-env-minimal.sh
        $ sudo -E ./winesapos-install.sh
        ```

    - SteamOS 3:

        ```
        $ export WINESAPOS_DEVICE=vdb
        $ . ./env/winesapos-env-minimal.sh
        $ sudo -E ./winesapos-install.sh
        ```

When complete, run the automated tests and then shutdown the virtual machine (do NOT restart). The image can then be cleaned up and used for manual testing on an external storage device.

### Automated Container Build

The ``.github/workflows/main.yml`` GitHub Actions workflow has the steps needed to automatically build an image using a container. These can be run manually:

```
$ sudo docker pull archlinux:latest
$ sudo docker build --pull --no-cache -t winesapos-img-builder build/.
$ sudo docker run --rm -v $(pwd):/workdir -v /dev:/dev --privileged=true winesapos-img-builder:latest /bin/zsh -x /workdir/scripts/winesapos-build.sh
```

The resulting image will be built and available here: `scripts/winesapos.img`.

### Tests

#### Matrix

These are all of the scenarioes that need to be tested and working before a release.

| OS | Performance | Secure | Plasma | Cinnamon | GNOME |
| --- | --- | --- | --- | --- | --- |
| SteamOS | x | x | x | x | x |
| Arch Linux | x | x | x | x | x |
| Manjaro | x | x | x | x | x |

#### Automatic

Run the tests to ensure that everything was setup correctly. These are automatically ran and logged as part of the install script. The tests must be run with the ZSH shell (not BASH).

```
$ sudo zsh ./winesapos-tests.sh
```

#### Manual

On the hypervisor, clean up the virtual machine image. This will ensure that the image will generated unique values for additional security and stability. The `customize` operation is disabled because the operation will set a new machine-id which is not what we want. Our image already has a blank `/etc/machine-id` file which will be automatically re-generated on first boot.

```
$ sudo virt-sysprep --operations defaults,-customize -a /var/lib/libvirt/images/winesapos.img
```

Optionally flash the image onto an external storage device for testing hardware. Otherwise, run manual tests using a virtual machine.

```
$ sudo dd if=/var/lib/libvirt/images/winesapos.img of=/dev/<DEVICE>
```

Manual tests:

- Accept every first-time setup option to install and configure the system.
- Open and use every program on the desktop.
- Package Managers
    - Discover
        - Install a Pacman package: `apache`
        - Install a Flatpak package: `org.gnome.BreakTimer`
    - bauh
        - Install a Pacman package: `nginx`
        - Install a Flatpak package: `org.gabmus.gfeeds`
        - Install an AUR package: `cmatrix-git`
        - Install a Snap package: `lxd`
    - AppImagePool
        - Install an AppImage: `GitNote`

## Workflows

### Adding Applications

If adding a new application to winesapOS, these are all of the places it needs to be updated:

- `README.md` needs to mention that application under the "Usability" or "Gaming support" sections under the "Features" header.
- `CHANGELOG.md` needs to mention that the application has has been `Add`ed, `Change`d, or `Remove`d.
- `src/winesapos-install.sh`
    - The installer creates a file at "/home/winesap/Desktop/README.txt" that lists every GUI applications.
    - The installer creates shortcut files for GUI applications.
- `src/winesapos-tests.sh` needs updated tests to at least check for the existence of the package and desktop shortcut (if applicable).

### Importing SteamOS 3 Source Code

SteamOS 3 source code is hosted in an internal GitLab repository at Valve. As a workaround, we can import the git repository from source Pacman packages and use them for building modified applications. The most notable package we need to modify is Mesa to add in Intel OpenGL driver support.

#### Automatically

Run this automated script:

```
cd scripts/repo/
./git-valve-sources.sh
```

#### Manually

- Find, download, and extract a source package from either the [holo](https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/holo/) or [jupiter](https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/jupiter/) SteamOS 3 Pacman repository.

    ```
    tar -x -v -f <PACKAGE_NAME>-<PACKAGE_VERSION>.src.tar.gz
    ```

- Notice how there is a PKGBUILD file that can be modified and uploaded to the Arch Linux User Repository (AUR).

    ```
    less <PACKAGE_NAME>/PKGBUILD
    ```

- Convert the bare git repository into a regular git repository.

    ```
    cd <PACKAGE_NAME>/archlinux-<PACKAGE_NAME>/
    mkdir .git
    mv branches ./.git/
    mv config ./.git/
    mv description ./.git/
    mv HEAD ./.git/
    mv hooks ./.git/
    mv info ./.git/
    mv objects ./.git/
    mv packed-refs ./.git/
    mv refs ./.git/
    git config --local --bool core.bare false
    git reset --hard
    ```

- Add a new remote and then push the entire git repository to it.

    ```
    git remote add winesapos git@github.com:<GIT_USER>/<GIT_REPOSITORY>.git
    git push --all winesapos
    git push --tags winesapos
    ```

    - If updating an existing repository, then pushing new tags may fail. Manually push each tag that failed.

        ```
        git push --tags winesapos
         ! [remote rejected]         <TAG> -> <TAG> (failed)
        ```
        ```
        git push winesapos <TAG>
        ```

### Updating Linux Kernels

winesapOS ships two Linux kernels:

- Linux LTS = The latest upstream Linux LTS kernel.
    - A new version of this kernel is released every year around December.
        - For Arch Linux hybrid builds, `linux-lts` is already used. For Manjaro hybrid builds, the `linux<MAJOR_VERSION><MINOR_VERSION>` package needs to be updated.
        - The Mac drivers need to build cleanly against this kernel.
- SteamOS = The Linux Neptune kernel from SteamOS 3.
    - A new version of this kernel comes out with each SteamOS 3.Y release.
        - Rebase the git repository based on the SteamOS source code first.

### Build Packages for winesapOS Repository

A container and script are provided to pre-build important AUR packages for winesapOS.

```
cd scripts/repo/
sudo docker build --pull --no-cache --tag ekultails/winesapos-build-repo:latest .
mkdir /tmp/winesapos-build-repo
chmod 777 /tmp/winesapos-build-repo
sudo docker run --name winesapos-build-repo --rm --volume /tmp/winesapos-build-repo:/output ekultails/winesapos-build-repo:latest &> /tmp/winesapos-build-repo_$(date --iso-8601=seconds).log
```

Those packages are then hosted on a Kubernetes cluster with the following requirements:

- [cert-manager](https://github.com/cert-manager/cert-manager)
- [nginxinc/kubernetes-ingress](https://github.com/nginxinc/kubernetes-ingress)
- [longhorn](https://github.com/longhorn/longhorn)

Apply all of the Kubernetes manifests to create NGINX containers on the Kubernetes cluster.

```
kubectl apply -f scripts/repo/k8s/
```

For copying new packages over, temporarily set `deployment.spec.template.spec.containers.volumeMounts[0].readOnly` to `false`.

```
kubectl --namespace winesapos-repo edit deployment deploy-winesapos-repo
```

Then copy the new files into one of the containers. A single persistent volume claim is shared among all of the containers.

```
kubectl --namespace winesapos-repo cp <PACKAGE_FILE> deploy-winesapos-repo-<UUID>:/usr/share/nginx/html/
```

#### Environment Variables for Repository Build

For specialized repository builds, use environment variables to determine what packages will be built.

```
sudo docker run --name winesapos-build-repo --rm --env WINESAPOS_REPO_BUILD_TESTING=true --env WINESAPOS_REPO_BUILD_LINUX_GIT=true --env WINESAPOS_REPO_BUILD_MESA_GIT=true --volume /tmp/winesapos-build-repo:/output ekultails/winesapos-build-repo:latest &> /tmp/winesapos-build-repo_$(date --iso-8601=seconds).log
```

| Key | Values | Default | Description |
| --- | ------ | ------- | ----------- |
| WINESAPOS_REPO_BUILD_TESTING | true or false | false | Name the Pacman repository database as "winesapos-testing" instead of "winesapos". |
| WINESAPOS_REPO_BUILD_LINUX_GIT | true or false | false | Build `linux-git`. |
| WINESAPOS_REPO_BUILD_MESA_GIT | true or false | false | Build `mesa-git` and `lib32-mesa-git`. |

### Custom Scripts

winesapOS supports running custom scripts before the installation finishes.

Specify the script to run before running `winesapos-install.sh`:

```
$ export WINESAPOS_CUSTOM_SCRIPT=/path/to/script.sh
```

Hints for writinng a custom script:

- Source the `scripts/env/winesapos-env-defaults.sh` environment variables to load useful functions.
- Use one of the provided functions to install an application:
    - `${CMD_FLATPAK_INSTALL}`
    - `${CMD_PACMAN_INSTALL}`
    - `${CMD_YAY_INSTALL}`
- Use `${WINESAPOS_INSTALL_DIR}` to reference the chroot directory used as part of the installation.

### Wayback Machine Backups

On the server that hosts the winesapOS repository, run these commands to automatically backup all of the files to the Wayback Machine (Internet Archive):

```
$ cd /data/winesapos-repo/repo/
$ find . -exec curl curl -v https://web.archive.org/save/https://winesapos.lukeshort.cloud/repo/{} ;
```

It is also possible for a community member to do a backup by downloading the a mirror of the repository to their computer first:

```
$ wget -m https://winesapos.lukeshort.cloud/repo/
$ cd winesapos.lukeshort.cloud
$ find . -name "*.html" -exec curl -v "https://web.archive.org/save/https://{}" ';'
```

## Release

### Schedule

As of winesapOS 3.3.0, every new minor 3.Y.0 release is planned to be released shortly after a new SteamOS 3.Y.0 update becomes stable.

### Checklist

These are tasks the need to happen before publishing a stable release.

- Rebase SteamOS packages in the AUR:
    - [linux-steamos](https://aur.archlinux.org/packages/linux-steamos)
    - [mesa-steamos](https://aur.archlinux.org/packages/mesa-steamos)
    - [lib32-mesa-steamos](https://aur.archlinux.org/packages/lib32-mesa-steamos)
    - [vapor-steamos-theme-kde](https://aur.archlinux.org/packages/vapor-steamos-theme-kde)
- Rebuild all AUR packages.
    - First publish them to the `[winesapos-testing]` repository and test them via a new build.
    - For the stable build and release, move these packages to the `[winesapos]` repository.
- Update the versions for these programs by changing these variables:
    - scripts/winesapos-install.sh
        - `YAY_VER`
    - scripts/winesapos-setup.sh
        - `PROTON_GE_VERSION`
        - `WINE_GE_VER`
    - scripts/repo/winesapos-build-repo.sh
        - `YAY_VER`
- Delete old git branches:

    ```
    git branch -D <BRANCH>
    git push --delete origin <BRANCH>
    ```
- Test upgrades from every old stable version to the new stable version.

### Publishing

- Add upgrade notes to the `UPGRADES.md` file.
- For a new release, update the `VERSION` file in the git repository with the new version before building an image.
- Before building an alpha of beta build, enable the `[winesapos-testing]` repository with `export WINESAPOS_ENABLE_TESTING_REPO=true`.
- After a build, make sure that no tests failed by checking the exit/return code of the installation script. That number will be automatically printed to the screen and it is the number of failed tests.
- On the hypervisor, stop the virtual machine and then sanitize the image.

    ```
    $ sudo virt-sysprep --operations defaults,-customize -a /var/lib/libvirt/images/winesapos.img
    ```

- Create a release by using the universal `zip` compression utility. Using `zip` also allows for splitting the archive into 2 GiB parts which is required for uploading a GitHub release. Do this for the build of the "performance" (default), "secure", and "minimal" images.

    ```
    $ cd /var/lib/libvirt/images/
    $ sudo mv winesapos.img winesapos-<VERSION>-[performance|secure|minimal].img
    $ sudo zip -s 1900m winesapos-<VERSION>-[performance|secure|minimal].img.zip winesapos-<VERSION>-[performance|secure|minimal].img
    $ ls -1 | grep winesapos
    winesapos-<VERSION>-[performance|secure|minimal].img
    winesapos-<VERSION>-[performance|secure|minimal].img.z01
    winesapos-<VERSION>-[performance|secure|minimal].img.z02
    winesapos-<VERSION>-[performance|secure|minimal].img.zip
    ```

- Create SHA512 checkums separately for the "performance", "secure", and "minimal" images and their related archive files. Users can then use those files to check for corruption or tampering.

    ```
    $ sha512sum winesapos-<VERSION>-[performance|secure|minimal]* > winesapos-<VERSION>-[performance|secure|minimal].sha512sum.txt
    $ sha512sum --check winesapos-<VERSION>-[performance|secure|minimal].sha512sum.txt
    ```

- Take a screenshot of the desktop for the secure image. It has all of the applications that the performance has in addition to the "Firewall" GUI provided by firewalld.
    - Set the desktop resolution to 1280x768.
    - Use [Squoosh](https://squoosh.app/) to compress the image.
    - Upload the image to a GitHub issue.
    - Update the hyperlink used in the README.md file.

- Create a git tag and push it.

    ```
    $ git tag X.Y.Z
    $ git push origin X.Y.Z
    ```
    
- Sync the stable branch with the latest tag. This is required for the upgrade script. Old versions of winesapOS will pull the latest upgrade script from the stable branch.

    ```
    $ git checkout stable
    $ git rebase X.Y.Z
    $ git push origin stable
    ```
