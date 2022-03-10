# winesapOS Developer Guide

* [winesapOS Developer Guide](#winesapos-developer-guide)
   * [Architecture](#architecture)
      * [Partitions](#partitions)
      * [Drivers](#drivers)
         * [Mac](#mac)
   * [Build](#build)
      * [Download the Installer](#download-the-installer)
      * [Create Virtual Machine](#create-virtual-machine)
         * [CLI](#cli)
         * [GUI](#gui)
      * [Environment Variables](#environment-variables)
      * [Install winesapOS](#install-winesapos)
      * [Tests](#tests)
         * [Automatic](#automatic)
         * [Manual](#manual)
   * [Workflows](#workflows)
       * [Adding Applications](#adding-applications)
   * [Release](#release)

## Architecture

### Partitions

| Number | Label | File System | Size | Description |
| ------ | ----- | ----------- | ---- |------------ |
| 1 | None | None | 2 MB | BIOS boot backwards compatibility. |
| 2 | wos-drive | exFAT | 16 GB | Cross-platform flash drive storage. |
| 3 | WOS-EFI | FAT32 | 500 MB | UEFI boot firmware. |
| 4 | winesapos-boot | ext4 | 1 GB | GRUB boot loader and Linux kernel. |
| 5 (Performance) | winesapos-root | Btrfs | 100% | The root and home file systems. |
| 5 (Secure) | winesapos-luks | LUKS | 100% | The encrypted root and home file systems. |

## Drivers

### Mac

These drivers are provided for better compatibility with the lastest Macs with Intel processors:

- **apple-bce = T2 driver** required for storage, mouse, keyboard, and audio support. We provide a [git repository](https://github.com/LukeShortCloud/mbp2018-bridge-drv/tree/mac-linux-gaming-stick) that syncs up both the [t2linux](https://github.com/t2linux/apple-bce-drv) and [macrosfad](https://github.com/marcosfad/mbp2018-bridge-drv) forks. It provides the newer kernel compatibility from t2linux and also a DKMS module from macrosfad for easily installing the kernel driver.
- **macbook12-spi-driver-dkms = Touchbar driver.** The package is installed from the [AUR](https://aur.archlinux.org/packages/macbook12-spi-driver-dkms/).
- **snd_hda_macbookpro = Sound driver.** This requires the **apple-bce** driver to work on some Macs. We provide a [git repository](https://github.com/LukeShortCloud/snd_hda_macbookpro/tree/mac-linux-gaming-stick) that modifies the installation script to install for all Linux kernels found on the system instead of just the running Linux kernel.

## Build

### Download the Installer

Depending on which Arch Linux distribution you want to build, download the related installer. Both Arch Linux and Manjaro provide ISOs for a live CD environment. The Steam Deck recovery image is a block device so it needs to be configured differently in a virtual machine before installing winesapOS.

- [Arch Linux ISO](https://archlinux.org/download/)
- [Manjaro KDE Plasma ISO](https://manjaro.org/downloads/official/kde/)
- [Steam Deck Recovery Image (for SteamOS 3)](https://store.steampowered.com/steamos/download/?ver=steamdeck&snr=) (default)

### Create Virtual Machine

A virtual machine is used to build winesapOS in a safe and isolated manner. The disks on the hypervisor will not be touched. It is assumed that QEMU/KVM will be used although other hypervisors can be used.

Requirements:

- UEFI boot
- 2 vCPUs
- 4 GB RAM
- 28 GiB storage (to fit on a 32 GB flash drive)

#### CLI

- Create the virtual storage device.

    - All:

    ```
    $ sudo qemu-img create -f raw -o size=28G /var/lib/libvirt/images/winesapos.img
    ```

- Create the virtual machine to use for installing winesapOS.

    - SteamOS 3 uses a recovery image.

    ```
    $ sudo virt-install --name winesapos --boot uefi --vcpus 2 --memory 4096 --disk path=/var/lib/libvirt/images/steamdeck-recovery-1.img,bus=virtio,cache=none --disk path=/var/lib/libvirt/images/winesapos.img,bus=virtio,cache=none
    ```

    - Arch Linux and Manjaro use an installer ISO image.

    ```
    $ sudo virt-install --name winesapos --boot uefi --vcpus 2 --memory 4096 --disk path=/var/lib/libvirt/images/winesapos.img,bus=virtio,cache=none --cdrom=/var/lib/libvirt/images/<INSTALLER_ISO>
    ```

#### GUI

SteamOS 3:

1. Virtual Machine Manager (virt-manager)
2. File
3. New Virtual Machine
4. Import existing disk image
5. Provide the existing storage path: steamdeck-recovery-1.img
6. Choose the operating system you are installing: Arch Linux (archlinux)
7. Forward
8. Memory: 4096
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
18. Create a disk image for the virtual machine: 24.0 GiB
19. Finish
20. Begin Installation

Arch Linux and Manjaro:

1. Virtual Machine Manager (virt-manager)
2. File
3. New Virtual Machine
4. Local install media (ISO image or CDROM)
5. Forward
6. Choose ISO or CDROM install media: <INSTALLER_ISO>
7. Forward
8. Memory: 4096
9. CPUs: 2
7. Forward
8. Enable storage for this virtual machine: yes
9. Create a disk image for the virtual machine: 24.0 GiB
10. Forward
11. Name: winesapOS
12. Customize configuration before install: yes
13. Finish
14. Overview
15. Firmware: UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.secboot.fd
16. Apply
17. Begin Installation

### Environment Variables

For specialized builds, use environment variables to modify the installation settings.

```
$ export <KEY>=<VALUE>
```

| Key | Values | Performance Value (Default) | Secure Value | Description |
| --- | ------ | --------------------------- | ------------ | ----------- |
| WINESAPOS_DEBUG_INSTALL | true or false | true | true | Use `set -x` for debug shell logging during the installation. |
| WINESAPOS_DEBUG_TESTS | true or false | false | false | Use `set -x` for debug shell logging during the tests. |
| WINESAPOS_INSTALL_DIR | | /winesapos | /winesapos | The chroot directory where winesapOS will be installed into. |
| WINESAPOS_DISTRO | arch, manjaro, or steamos | steamos | steamos | The Linux distribution to install with. |
| WINESAPOS_DE | cinnamon or plasma | plasma | plasma | The desktop environment to install. |
| WINESAPOS_DEVICE | | vda | vda | The `/dev/${WINESAPOS_DEVICE}` storage device to install winesapOS onto. |
| WINESAPOS_ENCRYPT | true or false | false | true | If the root partition should be encrypted with LUKS. |
| WINESAPOS_ENCRYPT_PASSWORD | | password | password | The default password for the encrypted root partition. |
| WINESAPOS_LOCALE | | ``en_US.UTF-8 UTF-8`` | ``en_US.UTF-8 UTF-8`` | The locale to use for ``/etc/locale.gen``. |
| WINESAPOS_APPARMOR | true or false | false | true | If Apparmor should be installed and enabled. |
| WINESAPOS_PASSWD_EXPIRE | true or false | false | true | If the `root` and `winesap` user passwords will be forced to be changed after first login. |
| WINESAPOS_FIREWALL | true or false | false | true | If a firewall (`firewalld`) will be installed. |
| WINESAPOS_CPU_MITIGATIONS | true or false | false | true | If processor mitigations should be enabled in the Linux kernel. |
| WINESAPOS_DISABLE_KERNEL_UPDATES | true or false | true | false | If the Linux kernels should be excluded from being upgraded by Pacman. |

### Install winesapOS

Once the virtual machine is running, a distribution of Arch Linux for winesapOS can be installed. An automated script is provided to fully install the operating system. This script will only work in a virtual machine. Clone the entire project repository. This will provide additional files and scripts that will be copied into the virtual machine image.

SteamOS 3 requires making the root file system writable and then installing required dependencies.

```
$ sudo steamos-readonly disable
$ sudo pacman -S -y
$ sudo pacman -S zsh
```

Arch Linux and Manjaro require installing dependencies.

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

- Performance focused image build:

    - SteamOS 3 (default):

        ```
        $ export WINESAPOS_DEVICE=vdb
        $ sudo -E ./winesapos-install.sh
        ```

    - Arch Linux:

        ```
        # export WINESAPOS_DISTRO=arch
        # ./winesapos-install.sh
        ```

    - Manjaro:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ sudo -E ./winesapos-install.sh
        ```

- Secure focused image build requires first sourcing the environment variables:

    - SteamOS 3:

        ```
        $ sudo steamos-readonly disable
        $ export WINESAPOS_DEVICE=vdb
        $ . ./winesapos-env-secure.sh
        $ sudo -E ./winesapos-install.sh
        ```

    - Arch Linux:

        ```
        # export WINESAPOS_DISTRO=arch
        # . ./winesapos-env-secure.sh
        # ./winesapos-install.sh
        ```

    - Manjaro:

        ```
        $ export WINESAPOS_DISTRO=manjaro
        $ . ./winesapos-env-secure.sh
        $ sudo -E ./winesapos-install.sh
        ```

When complete, run the automated tests and then shutdown the virtual machine (do NOT restart). The image can then be cleaned up and used for manual testing on an external storage device.

### Tests

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

Install the image onto an external storage device for testing.

```
$ sudo dd if=/var/lib/libvirt/images/winesapos.img of=/dev/<DEVICE>
```

## Workflows

### Adding Applications

If adding a new application to winesapOS, these are all of the places it needs to be updated:

- `README.md` needs to mention that application under the "Usability" or "Gaming support" sections under the "Features" header.
- `CHANGELOG.md` needs to mention that the application has has been `Add`ed, `Change`d, or `Remove`d.
- `src/winesapos-install.sh`
    - The installer creates a file at "/home/winesap/Desktop/README.txt" that lists every GUI applications.
    - The installer creates shortcut files for GUI applications.
- `src/winesapos-tests.sh` needs updated tests to at least check for the existence of the package and desktop shortcut (if applicable).

## Release

1. For a new release, update the `VERSION` file in the git repository with the new version before building an image.
2. After a build, make sure that no tests are failing.

    ```
    $ grep "FAIL" /winesapos/etc/winesapos/winesapos-install.log
    ```

3. On the hypervisor, stop the virtual machine and then sanitize the image.

    ```
    $ sudo virt-sysprep --operations defaults,-customize -a /var/lib/libvirt/images/winesapos.img
    ```

4. Create a release by using the universal `zip` compression utility. Using `zip` also allows for splitting the archive into 2 GiB parts which is required for uploading a GitHub release. Do this for both a build of the "performance" (default) and "secure" images.

    ```
    $ cd /var/lib/libvirt/images/
    $ sudo mv winesapos.img winesapos-[performance|secure]-<VERSION>.img
    $ sudo zip -s 1900m winesapos-[performance|secure]-<VERSION>.img.zip winesapos-[performance|secure]-<VERSION>.img
    $ ls -1 | grep winesapos
    winesapos-[performance|secure]-<VERSION>.img
    winesapos-[performance|secure]-<VERSION>.img.z01
    winesapos-[performance|secure]-<VERSION>.img.z02
    winesapos-[performance|secure]-<VERSION>.img.zip
    ```

5. Create SHA512 checkums separately for both the performance and secure image and their related archive files. Users can then use those files to check for corruption or tampering.

    ```
    $ sha512sum winesapos-performance* > winesapos-performance-<VERSION>_sha512sum.txt
    $ sha512sum winesapos-secure* > winesapos-secure-<VERSION>_sha512sum.txt
    $ sha512sum --check winesapos-performance-<VERSION>_sha512sum.txt
    $ sha512sum --check winesapos-secure-<VERSION>_sha512sum.txt
    ```
