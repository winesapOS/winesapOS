# winesapOS Contributor Guide

* [winesapOS Contributor Guide](#winesapos-contributor-guide)
   * [Getting Started](#getting-started)
   * [Architecture](#architecture)
      * [Partitions](#partitions)
      * [Files](#files)
      * [Base Operating System](#base-operating-system)
   * [Build](#build)
      * [Container Versus Virtual Machine Builds](#container-versus-virtual-machine-builds)
      * [Download the Installer](#download-the-installer)
      * [Create Virtual Machine](#create-virtual-machine)
         * [virt-install (CLI)](#virt-install-cli)
         * [virt-manager (GUI)](#virt-manager-gui)
         * [GNOME Boxes (GUI)](#gnome-boxes-gui)
      * [Environment Variables for Installation](#environment-variables-for-installation)
      * [Install winesapOS](#install-winesapos)
      * [Automated Container Build](#automated-container-build)
      * [Tests](#tests)
         * [Automatic](#automatic)
         * [Manual](#manual)
            * [Upgrades](#upgrades)
   * [Workflows](#workflows)
       * [Adding Applications](#adding-applications)
       * [Updating Linux Kernels](#updating-linux-kernels)
       * [Build Packages for winesapOS Repository](#build-packages-for-winesapos-repository)
           * [Environment Variables for Repository Build](#environment-variables-for-repository-build)
           * [GPG Signing](#gpg-signing)
           * [Repository Automation](#repository-automation)
       * [Custom Scripts](#custom-scripts)
       * [Wayback Machine Backups](#wayback-machine-backups)
   * [Release](#release)
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

### Files

These are a list of custom files and script that we install as part of winesapOS:

- `/etc/NetworkManager/conf.d/wifi_backend.conf` = Configures NetworkManger to use the IWD backend.
    - Source: `scripts/winesapos-install.sh`
- `/etc/modules-load.d/winesapos-mac.conf` = Enable the T2 driver (apple-bce).
    - Source: `scripts/winesapos-install.sh`
- `/etc/modprobe.d/framework-als-deactivate.conf` = If a Framework laptop is detected, the ambient light sensor is disabled to fix input from special keys on the keyboard.
    - Source: `scripts/winesapos-setup.sh`
- `/etc/modprobe.d/winesapos-amd.conf` = Enable the AMDGPU driver for older graphics cards and apply various driver workarounds for known issues.
    - Source: `scripts/winesapos-install.sh`
- `/etc/modprobe.d/winesapos-mac.conf` = Enable the Touch Bar driver (apple-touchbar) and disable the Ethernet over USB drivers which T2 Macs do not support.
    - Source: `scripts/winesapos-install.sh`
    - Source: `scripts/winesapos-setup.sh`
- `/etc/snapper/configs/{root,home}` = The Snapper configuration for Btrfs backups.
    - Source: `files/etc-snapper-configs-root`
- `/etc/sysctl.d/00-winesapos.conf` = Configures a lower swappiness level and increases the open files limit.
    - Source: `scripts/winesapos-install.sh`
- `/etc/systemd/system.conf.d/20-file-limits.conf` = Configure a higher open files limit.
    - Source: `scripts/winesapos-install.sh`
- `/etc/systemd/user/winesapos-mute.service` = A user (not system) service for muting all audio. This is required for some newer Macs that have in-development hardware drivers that are extremely loud by default.
    - Source: `files/winesapos-mute.service`
- `/usr/local/bin/winesapos-mute.sh` = The script for the winesapos-mute.service.
    - Source: `scripts/winesapos-mute.sh`
- `/etc/systemd/system/pacman-mirrors.service` = On Manjaro builds, this provides a service to find and configure the fastest mirrors for Pacman. This is not needed on Arch Linux builds as it has a Reflector service that comes with a service file.
    - Source: `files/pacman-mirrors.service`
- `/etc/systemd/system/winesapos-resize-root-file-system.service` = A service that runs a script to resize the root file system upon first boot.
    - Source: `winesapos-resize-root-file-system.service`
- `/var/winesapos/graphics` = The graphics type that was selected during the setup process: amd, intel, nvidia-new, nvidia-old, virtualbox, or vmware.
    - Source: `scripts/winesapos-setup.sh`
- `/var/winesapos/IMAGE_TYPE` = The image type that was set during the build process.
    - Source: `scripts/winesapos-install.sh`
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
- `/usr/share/sddm/faces/winesap.face.icon` = The winesapOS logo as a 96x96 icon for the SDDM login screen.
    - Source: `files/winesapos_logo_icon.png`
- `/home/winesap/.winesapos/winesapos-upgrade-remote-stable.sh` = The script used for the winesapOS Upgrade wizard. It pulls the latest upgrade script from the "stable" branch of winesapOS.
    - Source: `scripts/winesapos-upgrade-remote-stable.sh`
- `/etc/systemd/system/winesapos-sddm-health-check.service` = Run the SDDM health check script for the first 5 minutes.
    - Source: `files/winesapos-sddm-health-check.service`
- `/usr/local/bin/winesapos-sddm-health-check.sh` = Check the status of SDDM and invoke a recovery console if it fails.
    - Source: `scripts/winesapos-sddm-health-check.sh`
- `/etc/sysctl.d/99-vm-zram-parameters.conf` = Configure optimized zram settings used by Pop!_OS.
    - Source: `scripts/winesapos-setup.sh`
- `/etc/systemd/zram-generator.conf` = Configure zram to compress half of the available RAM.
    - Source: `scripts/winesapos-setup.sh`
- `/usr/lib/os-release-winesapos` = The version and variant information for winesapOS. There is also a symlink from '/etc/os-release-winesapos' to this file.
    - Source: `files/os-release-winesapos`

### Base Operating System

winesapOS supports builds using Arch Linux or Manjaro.

| Feature | Arch Linux |  Manjaro | Description |
| --- | --- | --- | --- |
| Pin package versions | Yes | No | Manjaro does not have an equivalent to the Arch Linux Archive (ALA). |
| Stability | Low | High | Based on real-world testing and reported bugs, Manjaro builds are usually more stable than Arch Linux. |
| AUR compatibility | High | Low | AUR packages target Arch Linux and sometimes have build and/or runtime issues on Manjaro. |

Arch Linux is used by default due to the compatibility with the large amount of AUR packages. However, developers have the option to create builds with Manjaro which provides an overall more stable experience.

## Build

### Container Versus Virtual Machine Builds

Use a container build for:

-  Local development builds. Run a single command to build a new winesapOS image.
-  CI/CD builds. Quickly test and publish new changes.
-  Release builds. This ensures consistency with what is being built and tested in CI.

Use a virtual machine build for:

-  GPU passthrough. Applications and games that require GPU acceleration can be thoroughly tested.
-  Desktop testing. Reboot directly into a virtual machine to see and manually test new changes that require user interaction.

### Download the Installer

Depending on which Arch Linux distribution you want to build, download the related installer. Both Arch Linux and Manjaro provide ISOs for a live CD environment.

- [Arch Linux ISO](https://archlinux.org/download/)
- [Manjaro KDE Plasma Minimal ISO](https://manjaro.org/download/)

### Create Virtual Machine

A virtual machine is used to build winesapOS in a safe and isolated manner. The disks on the hypervisor will not be touched. It is assumed that QEMU/KVM will be used although other hypervisors can be used.

Requirements:

- UEFI boot
- 2 vCPUs
- 12 GB RAM
- Storage
    - Performance or secure image = 25 GiB storage (to fit on a 32 GB flash drive)
    - Minimal image = 8 GiB storage (to fit on a 16 GB flash drive)

#### virt-install (CLI)

- Create the virtual storage device.

    - Performance or secure image:

        ```
        sudo qemu-img create -f raw -o size=25G /var/lib/libvirt/images/winesapos.img
        ```

    - Minimal image:

        ```
        sudo qemu-img create -f raw -o size=8G /var/lib/libvirt/images/winesapos.img
        ```

- Create the virtual machine to use for installing winesapOS.

    - Arch Linux and Manjaro use an installer ISO image.

        ```
        sudo virt-install --name winesapos --boot loader=/usr/share/edk2-ovmf/x64/OVMF_CODE.fd,loader.readonly=yes,loader.secure='no',loader.type=pflash --vcpus 2 --memory 12288 --disk path=/var/lib/libvirt/images/winesapos.img,bus=virtio,cache=none --cdrom=/var/lib/libvirt/images/<INSTALLER_ISO>
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

   - Performance or secure image = 25.0 GiB
   - Minimal image = 8.0 GiB

13. Forward
14. Name: winesapOS
15. Customize configuration before install: yes
16. Finish
17. Overview
18. Firmware: UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.fd
19. Apply
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

      - Performance or secure image = 25.0 GiB
      - Minimal image = 8.0 GiB

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
| WINESAPOS_CREATE_DEVICE_SIZE | integer for GiB | (None) | (None) | (None) | Manually override the default values for the device size (8 GiB with no cross-platform storage and 25 GiB with). |
| WINESAPOS_DEVICE | | vda | vda | vda | If WINESAPOS_CREATE=false, then use the existing `/dev/${WINESAPOS_DEVICE}` block device to install winesapOS onto. |
| WINESAPOS_ENABLE_PORTABLE_STORAGE | | true | true | false | If the 16 GiB exFAT flash drive storage should be enabled. |
| WINESAPOS_BUILD_CHROOT_ONLY | false | false | false | If partitioning and GRUB should be skipped for a chroot installation. |
| WINESAPOS_INSTALL_DIR | | /winesapos | /winesapos | /winesapos | The chroot directory where winesapOS will be installed into. |
| WINESAPOS_DISTRO | arch or manjaro | arch | arch | arch | The Linux distribution to install with. |
| WINESAPOS_HTTP_PROXY | | | (None) | (None) | (None) | The HTTP, HTTPS, FTP, and Rsync proxy to use for the build. |
| WINESAPOS_HTTP_PROXY_CA | | | (None) | (None) | (None) | The certificate authority file to import for the HTTPS_PROXY. |
| WINESAPOS_DE | i3, cinnamon, gnome, plasma, plasma-mobile, or sway | plasma | plasma | plasma | The desktop environment to install. |
| WINESAPOS_USER_NAME | | winesap | winesap | winesap | The name of the user to create. |
| WINESAPOS_ENCRYPT | true or false | false | true | false | If the root partition should be encrypted with LUKS. |
| WINESAPOS_ENCRYPT_PASSWORD | | password | password | password | The default password for the encrypted root partition. |
| WINESAPOS_LOCALE | | ``en_US.UTF-8 UTF-8`` | ``en_US.UTF-8 UTF-8`` | ``en_US.UTF-8 UTF-8`` | The locale to use for ``/etc/locale.gen``. |
| WINESAPOS_APPARMOR | true or false | false | true | false | If Apparmor should be installed and enabled. |
| WINESAPOS_PASSWD_EXPIRE | true or false | false | true | false | If the `root` user password will be forced to be changed after first login. |
| WINESAPOS_SUDO_NO_PASSWORD | true or false | true | false | true | If the user can run `sudo` without entering a password. |
| WINESAPOS_FIREWALL | true or false | false | true | false | If a firewall (`firewalld`) will be installed. |
| WINESAPOS_CPU_MITIGATIONS | true or false | false | true | false | If processor mitigations should be enabled in the Linux kernel. |
| WINESAPOS_DISABLE_KERNEL_UPDATES | true or false | false | false | false | If the Linux kernels should be excluded from being upgraded by Pacman. |
| WINESAPOS_DISABLE_KWALLET | true or false | true | false | true | If Kwallet should be enabled for securing various passwords. |
| WINESAPOS_ENABLE_KLIPPER | true or false | true | false | true | If Klipper should be disabled (as much as it can be) for storing copied text. |
| WINESAPOS_INSTALL_GAMING_TOOLS | true or false | true | true | false | Install all gaming tools and launchers. |
| WINESAPOS_INSTALL_PRODUCTIVITY_TOOLS | true or false | true | true | false | Install all productivity tools. |
| WINESAPOS_IMAGE_TYPE | minimal, performance, or secure | performance | secure | minimal | The image type to set in the file ``/var/winesapos/IMAGE_TYPE``. |
| WINESAPOS_CUSTOM_SCRIPT | | (None) | (None) | (None) | A custom script to run before the installation does a cleanup. |
| WINESAPOS_SINGLE_MIRROR | true or false | false | false | false | If a single mirror or a list of mirrors will be used. |
| WINESAPOS_SINGLE_MIRROR_URL | ``http://ohioix.mm.fcix.net/archlinux`` | ``http://ohioix.mm.fcix.net/archlinux`` | ``http://ohioix.mm.fcix.net/archlinux`` | ``http://ohioix.mm.fcix.net/archlinux`` | If a single mirror or a list of mirrors will be used. It is assumed that ``${WINESAPOS_SINGLE_MIRROR_URL}/[archlinux|manjaro]`` paths are available. |
| WINESAPOS_BOOTLOADER | grub or systemd-boot | grub | grub | grub | The bootloader to use. |
| WINESAPOS_ENV_FILE | | (None) | (None) | (None) | The `scripts/env/${WINESAPOS_ENV_FILE}` to load during a container build. |

### Install winesapOS

Once the virtual machine is running, a distribution of Arch Linux for winesapOS can be installed after the mirrors have been updated.

- Arch Linux:

    ```
    $ sudo journalctl -u reflector -f
    MMM DD HH:MM:SS archiso systemd[1]: reflector.service: Deactivated successfully.
    ```

- Manjaro:

    ```
    $ sudo journalctl -u mirrors-live -f
    MMM DD HH:MM:SS manjaro systemd[1]: mirrors-live.service: Deactivated successfully.
    ```

An automated script is provided to fully install the operating system. This script will only work in a virtual machine. Clone the entire project repository. This will provide additional files and scripts that will be copied into the virtual machine image.

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

    - Arch Linux (default):

        ```
        # export WINESAPOS_DISTRO=arch
        # bash ./winesapos-install.sh
        ```

    - Manjaro:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ sudo -E bash ./winesapos-install.sh
        ```

- Security-focused image build requires first sourcing the environment variables:

    - Arch Linux:

        ```
        # export WINESAPOS_DISTRO=arch
        # . ./env/winesapos-env-secure.sh
        # bash ./winesapos-install.sh
        ```

    - Manjaro:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ . ./env/winesapos-env-secure.sh
        $ sudo -E bash ./winesapos-install.sh
        ```

- Minimal storage-focused image build requires first sourcing the environment variables:

    - Arch Linux:

        ```
        # export WINESAPOS_DISTRO=arch
        # . ./env/winesapos-env-minimal.sh
        # bash ./winesapos-install.sh
        ```

    - Manjaro:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ . ./env/winesapos-env-minimal.sh
        $ sudo -E bash ./winesapos-install.sh
        ```

When complete, shutdown the virtual machine (do NOT restart).

Cleanup the image before use.

```
$ sudo virt-sysprep --operations defaults,-customize -a /var/lib/libvirt/images/winesapos.img
```

### Automated Container Build

The ``.github/workflows/main.yml`` GitHub Actions workflow has the steps needed to automatically build an image using a container. These can be run manually.

If using a distribution that has SELinux in enforcing mode, set it to permissive first.

```
sudo setenforce 0
```

Both `docker` and `podman` are supported for builds.

Arch Linux build:

```
mkdir output && chmod 777 output
sudo docker build --pull --no-cache -t winesapos-img-builder build/.
sudo docker run --rm -v $(pwd):/workdir -v /dev:/dev --privileged=true winesapos-img-builder:latest /bin/bash -x /workdir/scripts/winesapos-build.sh
```

Manjaro build:

```
mkdir output && chmod 777 output
sed -i s'/archlinux:latest/manjarolinux\/base:latest/'g build/Dockerfile
sudo docker build --pull --no-cache -t winesapos-img-builder:manjaro build/.
sudo docker run --rm -v $(pwd):/workdir -v /dev:/dev --env WINESAPOS_DISTRO=manjaro --privileged=true winesapos-img-builder:manjaro /bin/bash -x /workdir/scripts/winesapos-build.sh
```

By default, the performance image is built. Use `--env WINESAPOS_ENV_FILE=winesapos-env-minimal.sh` or `--env WINESAPOS_ENV_FILE=winesapos-env-secure.sh` to build a different image type.

After the build, these files will be created:

- `output/`
    - `winesapos.img` = The raw image that was built.
    - `winesapos-install.log` = The install log.
    - `winesapos-install-rc.txt` = The return code from the tests indicating how many failed.
    - `winesapos-packages.txt` = The list of packages installed.

### Tests

#### Automatic

Run the tests to ensure that everything was setup correctly. These are automatically ran and logged as part of the install script. The tests must be run with Bash.

```
$ sudo bash ./winesapos-tests.sh
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
        - Install a Flatpak package: `org.gnome.BreakTimer`
    - bauh
        - Install a Pacman package: `nginx`
        - Install a Flatpak package: `org.gabmus.gfeeds`
        - Install an AUR package: `cmatrix-git`
        - Install a Snap package: `lxd`
    - AppImagePool
        - Install an AppImage: `GitNote`
- Reboot and then use the display manager to launch Gamescope sessions for:
    - Open Gamepad UI
    - Steam

##### Upgrades

By default, the winesapOS upgrade script will update all upgrade files and exit if there are changes detected. For testing on a branch that is not `stable` (such as `test`), set an environment variable to skip updating upgrade files as these are pulled from the `stable` branch.

```
export WINESAPOS_UPGRADE_FILES=false
export WINESAPOS_UPGRADE_TESTING_REPO=true
export WINESAPOS_UPGRADE_VERSION_CHECK=false
curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/test/scripts/winesapos-upgrade.sh | sudo -E bash
```

## Workflows

### Adding Applications

For new contributors:

- Fork the `main` branch of the [LukeShortCloud/winesapOS](https://github.com/LukeShortCloud/winesapOS/tree/main) git repository.
- All shell scripts are written in Bash.
   -  Check for syntax errors by using the command `bash -n ${SCRIPT_FILE}`.

If adding a new application to winesapOS, these are all of the places it needs to be updated:

- `README.md` needs to mention that application under the "Usability" or "Gaming support" sections under the "Features" header.
- `CHANGELOG.md` needs to mention that the application has has been `Add`ed, `Change`d, or `Remove`d.
- `src/winesapos-install.sh`
    - The installer copies shortcut files for GUI applications to the desktop.
- `src/winesapos-tests.sh` needs updated tests to at least check for the existence of the package and desktop shortcut (if applicable).

### Updating Linux Kernels

winesapOS ships two Linux kernels:

- Linux T2 = The latest stable Linux kernel with additional patches to support Intel Macs with the Apple T2 Security Chip.
- Linux LTS = The latest upstream Linux LTS kernel.
    - A new version of this kernel is released every year around December.
        - For Arch Linux builds, `linux-lts` is already used. For Manjaro builds, the `linux<MAJOR_VERSION><MINOR_VERSION>` package needs to be updated.
        - The Mac drivers need to build cleanly against this kernel.

### Build Packages for winesapOS Repository

A container and script are provided to pre-build important AUR packages for winesapOS. If using a distribution that has SELinux in enforcing mode, set it to permissive first.

```
sudo setenforce 0
cd scripts/repo/
sudo docker build --pull --no-cache --tag ekultails/winesapos-build-repo:latest .
mkdir /tmp/winesapos-build-repo
chmod 777 /tmp/winesapos-build-repo
sudo docker run --name winesapos-build-repo --rm --volume /tmp/winesapos-build-repo:/output ekultails/winesapos-build-repo:latest &> /tmp/winesapos-build-repo_$(date --iso-8601=seconds).log
```

Check the amount of packages that failed to build (if any):

```
cat /tmp/winesapos-build-repo/winesapos-build-repo_exit-code.txt
```

Check to see what packages succeeded or failed to be built:

```
grep -P "PASSED|FAILED" /tmp/winesapos-build-repo_*.log
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

#### GPG Signing

As of winesapOS 3.4.0, all packages and the metadata database are signed using a GPG key.

- Sign all of the packages:
    ```
    for pkg in $(ls -1); do gpg --detach-sign --no-armor ${pkg}; done
    ```
- Update and sign the database:
    ```
    repo-add --verify --sign winesapos.db.tar.gz ./*.pkg.tar.zst
    ```

#### Repository Automation

The winesapOS testing repository packages are [automatically](.github/workflows/repo-testing.yml) built and published on the 15th of every month. That GitHub Actions workflow can also be manually triggered at any time.

### Custom Scripts

winesapOS supports running custom scripts before the installation finishes.

Specify the script to run before running `winesapos-install.sh`:

```
$ export WINESAPOS_CUSTOM_SCRIPT=/path/to/script.sh
```

Hints for writing a custom script:

- Source the `scripts/env/winesapos-env-defaults.sh` environment variables to load useful functions.
- Use one of the provided functions to install an application:
    - `${CMD_FLATPAK_INSTALL[*]}`
    - `${CMD_PACMAN_INSTALL[*]}`
    - `${CMD_YAY_INSTALL[*]}`
- Use `${WINESAPOS_INSTALL_DIR}` to reference the chroot directory used as part of the installation.

### Wayback Machine Backups

On the server that hosts the winesapOS repository, run these commands to automatically backup all of the files to the Wayback Machine (Internet Archive):

```
$ export WINESAPOS_VERSION=3.3.0
$ cd /data/winesapos-repo/repo/winesapos-${WINESAPOS_VERSION}
$ curl -v https://web.archive.org/save/https://winesapos.lukeshort.cloud/repo/${WINESAPOS_VERSION}
$ find . -exec curl -v https://web.archive.org/save/https://winesapos.lukeshort.cloud/repo/${WINESAPOS_VERSION}/{} \;
```

It is also possible for a community member to do a backup by downloading the a mirror of the repository to their computer first:

```
$ wget -m https://winesapos.lukeshort.cloud/repo/
$ cd winesapos.lukeshort.cloud
$ find . -name "*.html" -exec curl -v "https://web.archive.org/save/https://{}" ';'
```

## Release

### Checklist

These are tasks the need to happen before publishing a stable release.

- Rebuild all AUR packages.
    - First publish them to the `[winesapos-testing]` repository and test them via a new build.
    - For the stable build and release, move these packages to the `[winesapos]` repository.
- Update the versions for these programs by changing these variables:
    - scripts/winesapos-install.sh
        - `ETCHER_VER`
        - `YAY_VER`
    - scripts/winesapos-setup.sh
        - `ETCHER_VER`
        - `PROTON_GE_VERSION`
    - scripts/winesapos-upgrade.sh
        - `ETCHER_VER`
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
- For a new release, update the `os-release-winesapos` file in the git repository with the new `VERSION` and `VERSION_ID` before building an image.
- Before building an alpha of beta build, enable the `[winesapos-testing]` repository with `export WINESAPOS_ENABLE_TESTING_REPO=true`.
- Create a release image using a [container build](#automated-container-build).
- Make sure that no tests failed by checking the exit/return code of the installation script. It should be zero. If not, that is how many tests have failed. Review the installation log for more details.

    ```
    $ cat ./output/winesapos-install-rc.txt
    0
    $ less ./output/winesapos-install.log
    ```

- Sanitize the image.

    ```
    $ sudo cp ./output/winesapos.img /var/lib/libvirt/images/
    $ sudo virt-sysprep --operations defaults,-customize -a /var/lib/libvirt/images/winesapos.img
    ```

- Copy the packages list over for it to be checksummed.

    ```
    $ sudo cp ./output/winesapos-packages.txt /var/lib/libvirt/images/winesapos-<VERSION>-[performance|secure|minimal].packages.txt
    ```

- Create a release by using the universal `zip` compression utility. Do this for the build of the "performance" (default), "secure", and "minimal" images.

    ```
    $ cd /var/lib/libvirt/images/
    $ sudo mv winesapos.img winesapos-<VERSION>-[performance|secure|minimal].img
    $ sudo zip winesapos-<VERSION>-[performance|secure|minimal].img.zip winesapos-<VERSION>-[performance|secure|minimal].img
    $ ls -1 | grep winesapos
    winesapos-<VERSION>-[performance|secure|minimal].img
    winesapos-<VERSION>-[performance|secure|minimal].img.zip
    ```

- Create SHA512 checkums separately for the "performance", "secure", and "minimal" images and their related archive files. Users can then use those files to check for corruption or tampering.

    ```
    $ sha512sum winesapos-<VERSION>-[performance|secure|minimal]* > winesapos-<VERSION>-[performance|secure|minimal].sha512sum.txt
    $ sha512sum --check winesapos-<VERSION>-[performance|secure|minimal].sha512sum.txt
    ```

- Create a tarball of the root file system from the minimal image.

    ```
    $ export WINESAPOS_VERSION="4.1.0"
    $ sudo -E guestmount --add winesapos-${WINESAPOS_VERSION}-minimal.img --mount /dev/sda4 --ro /mnt
    $ sudo -E guestmount --add winesapos-${WINESAPOS_VERSION}-minimal.img --mount /dev/sda3 --ro /mnt/boot
    $ sudo -E guestmount --add winesapos-${WINESAPOS_VERSION}-minimal.img --mount /dev/sda2 --ro /mnt/boot/efi
    $ sudo -E tar --create --preserve-permissions --zstd --directory /mnt --file winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar.zst .
    $ sha512sum winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar.zst | sudo -E tee winesapos-${WINESAPOS_VERSION}-minimal-rootfs.sha512sum.txt
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

- Upload the images to be hosted at `https://winesapos.lukeshort.cloud/repo/iso/winesapos-${WINESAPOS_VERSION}/` and also on the Internet Archive.

    ```
    $ cd /usr/local/bin/
    $ sudo url -LOs https://archive.org/download/ia-pex/ia
    $ sudo chmod +x /usr/local/bin/ia
    $ ia configure
    $ export WINESAPOS_VERSION=4.1.0
    $ export WINESAPOS_VERSION_NO_PERIODS=410
    $ cd /data/winesapos-repo/repo/iso/winesapos-${WINESAPOS_VERSION}/
    $ ia upload \
        winesapos-${WINESAPOS_VERSION_NO_PERIODS} \
        winesapos-${WINESAPOS_VERSION}-minimal.img.zip \
        winesapos-${WINESAPOS_VERSION}-minimal.packages.txt \
        winesapos-${WINESAPOS_VERSION}-minimal.sha512sum.txt \
        winesapos-${WINESAPOS_VERSION}-performance.img.zip \
        winesapos-${WINESAPOS_VERSION}-performance.packages.txt \
        winesapos-${WINESAPOS_VERSION}-performance.sha512sum.txt \
        winesapos-${WINESAPOS_VERSION}-secure.img.zip \
        winesapos-${WINESAPOS_VERSION}-secure.packages.txt \
        winesapos-${WINESAPOS_VERSION}-secure.sha512sum.txt\
        winesapos-${WINESAPOS_VERSION}-minimal-rootfs.tar.zst \
        winesapos-${WINESAPOS_VERSION}-minimal-rootfs.sha512sum.txt \
        --metadata="mediatype:data" \
        --metadata="title:winesapOS ${WINESAPOS_VERSION}" \
        --metadata="creator:Luke Short" \
        --metadata="summary:https://github.com/LukeShortCloud/winesapOS/releases/tag/${WINESAPOS_VERSION}"
    ```
