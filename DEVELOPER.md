# winesapOS Developer Guide

## Drivers

### apple-bce

We provide a git repository [1] that syncs up both the t2linux [2] and macrosfad [3] forks.

1. https://github.com/LukeShortCloud/mbp2018-bridge-drv/tree/mac-linux-gaming-stick
2. https://github.com/t2linux/apple-bce-drv = Adds new patches for the kernel module compilation to work.
3. https://github.com/marcosfad/mbp2018-bridge-drv = Adds a dkms.conf configuration for easy rebuilding.

## Build

### Create Virtual Machine

A virtual machine is used to build winesapOS in a safe and isolated manner. The disks on the hypervisor will not be touched. It is assumed that QEMU/KVM will be used although other hypervisors can be used.

Requirements:

- UEFI boot
- 2 vCPUs
- 4 GB RAM
- 28 GiB storage (to fit on a 32 GB flash drive)

#### CLI

```
$ sudo qemu-img create -f raw -o size=28G /var/lib/libvirt/images/winesapos.img
$ sudo virt-install --name winesapos --boot uefi --vcpus 2 --memory 4096 --disk path=/var/lib/libvirt/images/winesapos.img,bus=virtio,cache=none --cdrom=/var/lib/libvirt/images/<MANJARO_ISO>
```

#### GUI

1. Virtual Machine Manager (virt-manager)
2. File
3. New Virtual Machine
4. Local install media (ISO image or CDROM)
5. Choose ISO or CDROM install media: <MANJARO_ISO>
6. Forward
7. Forward
8. Enable storage for this virtual machine: yes
9. Create a disk image for the virtual machine: 24.0 GiB
10. Forward
11. Customize configuration before install
12. Overview
13. Firmware: UEFI x86_64: /usr/share/edk2-ovmf/x64/OVMF_CODE.secboot.fd
14. Apply
15. Begin Installation

### Environment Variables

For specialized builds, use environment variables to modify the installation settings.

```
$ export <KEY>=<VALUE>
```

| Key | Values | Default Value | Description |
| --- | ------ | ------------- | ----------- |
| WINESAPOS_DEBUG | true or false | false | Use `set -x` for debug shell logging. |
| WINESAPOS_DISTRO | arch or manjaro | arch | The Linux distribution to install with. |
| WINESAPOS_DEVICE | | vda | The `/dev/${WINESAPOS_DEVICE}` storage device to install winesapOS onto. |
| WINESAPOS_ENCRYPT | true or false | false | If the root partition should be encrypted with LUKS. |
| WINESAPOS_ENCRYPT_PASSWORD | | password | The default password for the encrypted root partition. |
| WINESAPOS_APPARMOR | true or false | false | If Apparmor should be installed and enabled. |
| WINESAPOS_PASSWD_EXPIRE | true or false | false | If the `root` and `winesap` user passwords will be forced to be changed after first login. |
| WINESAPOS_FIREWALL | true or false | false | If a firewall (`firewalld`) will be installed. |
| WINESAPOS_CPU_MITIGATIONS | true or false | false | If processor mitigations should be enabled in the Linux kernel. |
| WINESAPOS_DISABLE_KERNEL_UPDATES | true or false | true | If the Linux kernels should be excluded from being upgraded by Pacman. |

### Install winesapOS

Once the virtual machine is running, a distribution of Arch Linux for winesapOS can be installed. An automated script is provided to fully install the operating system. This script will only work in a virtual machine. Clone the entire project repository. This will provide additional files and scripts that will be copied into the virtual machine image.

```
$ sudo pacman -S -y
$ sudo pacman -S git
$ git clone https://github.com/LukeShortCloud/winesapos.git
$ cd winesapos/scripts/
```

Before running the installation script, optionally set environment variables to configure the build. Use `sudo -E` to load the environment variables.

-  Performance focused image build:

    ```
    $ sudo -E ./winesapos-install.sh
    ```

-  Secure focused image build requires first sourcing the environment variables:

    ```
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

## Release

1. For a new release, update the `VERSION` file in the git repository with the new version before building an image.
2. After a build, make sure that no tests are failing.

    ```
    $ grep "FAIL" /mnt/etc/winesapos/winesapos-install.log
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
