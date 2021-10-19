# Mac Linux Gaming Stick Developer Guide

## Drivers

### apple-bce

We provide a git repository [1] that syncs up both the t2linux [2] and macrosfad [3] forks.

1. https://github.com/ekultails/mbp2018-bridge-drv/tree/mac-linux-gaming-stick
2. https://github.com/t2linux/apple-bce-drv = Adds new patches for the kernel module compilation to work.
3. https://github.com/marcosfad/mbp2018-bridge-drv = Adds a dkms.conf configuration for easy rebuilding.

## Build

### Create Virtual Machine

A virtual machine is used to build Mac Linux Gaming Stick in a safe and isolated manner. The disks on the hypervisor will not be touched. It is assumed that QEMU/KVM will be used although other hypervisors can be used.

Requirements:

- UEFI boot
- 2 vCPUs
- 4 GB RAM
- 28 GiB storage (to fit on a 32 GB flash drive)

#### CLI

```
$ sudo qemu-img create -f raw -o size=28G /var/lib/libvirt/images/mac-linux-gaming-stick.img
$ sudo virt-install --name mac-linux-gaming-stick --boot uefi --vcpus 2 --memory 4096 --disk path=/var/lib/libvirt/images/mac-linux-gaming-stick.img,bus=virtio,cache=none --cdrom=/var/lib/libvirt/images/<MANJARO_ISO>
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
| MLGS_DEBUG | true or false | false | Use `set -x` for debug shell logging. |
| MLGS_DEVICE | | vda | The `/dev/${MLGS_DEVICE}` storage device to install Mac Linux Gaming Stick onto. |
| MLGS_ENCRYPT | true or false | false | If the root partition should be encrypted with LUKS. |
| MLGS_ENCRYPT_PASSWORD | | password | The default password for the encrypted root partition. |
| MLGS_APPARMOR | true or false | false | If Apparmor should be installed and enabled. |
| MLGS_PASSWD_EXPIRE | true or false | false | If the `root` and `stick` user passwords will be forced to be changed after first login. |
| MLGS_FIREWALL | true or false | false | If a firewall (`firewalld`) will be installed. |

### Install Manjaro

Once the virtual machine is running, Manjaro can be installed. An automated script is provided to fully install Manjaro. This script will only work in a virtual machine. Clone the entire project repository. This will provide additional files and scripts that will be copied into the virtual machine image.

```
$ git clone https://github.com/ekultails/mac-linux-gaming-stick.git
$ cd mac-linux-gaming-stick/scripts/
```

Before running the installation script, optionally set environment variables to configure the build. Use `sudo -E` to load the environment variables.

-  Performance focused image build:

    ```
    $ sudo -E ./install-manjaro.sh
    ```

-  Secure focused image build:

    ```
    $ export MLGS_ENCRYPT=true MLGS_APPARMOR=true MLGS_PASSWD_EXPIRE=true MLGS_FIREWALL=true
    $ sudo -E ./install-manjaro.sh
    ```

When complete, run the automated tests and then shutdown the virtual machine (do NOT restart). The image can then be cleaned up and used for manual testing on an external storage device.

### Tests

#### Automatic

Run the tests to ensure that everything was setup correctly. These are automatically ran and logged as part of the install script. The tests must be run with the ZSH shell (not BASH).

```
$ sudo zsh ./tests-arch-linux.sh
```

#### Manual

On the hypervisor, clean up the virtual machine image. This will ensure that the image will generated unique values for additional security and stability. The `customize` operation is disabled because the operation will set a new machine-id which is not what we want. Our image already has a blank `/etc/machine-id` file which will be automatically re-generated on first boot.

```
$ sudo virt-sysprep --operations defaults,-customize -a /var/lib/libvirt/images/mac-linux-gaming-stick.img
```

Install the image onto an external storage device for testing.

```
$ sudo dd if=/var/lib/libvirt/images/mac-linux-gaming-stick.img of=/dev/<DEVICE>
```

## Release

1. For a new release, update the `VERSION` file in the git repository with the new version before building an image.
2. After a build, make sure that no tests are failing.

    ```
    $ grep "FAIL" /mnt/etc/mac-linux-gaming-stick/install-manjaro.log
    ```

3. On the hypervisor, create a release by using the universal `zip` compression utility. Using `zip` also allows for splitting the archive into 2 GiB parts which is required for uploading a GitHub release.

    ```
    $ cd /var/lib/libvirt/images/
    $ sudo mv mac-linux-gaming-stick.img mac-linux-gaming-stick-<VERSION>.img
    $ sudo zip -s 1900m mac-linux-gaming-stick-<VERSION>.img.zip mac-linux-gaming-stick-<VERSION>.img
    $ ls -1 | grep mac-linux-gaming-stick
    mac-linux-gaming-stick-<VERSION>.img
    mac-linux-gaming-stick-<VERSION>.img.z01
    mac-linux-gaming-stick-<VERSION>.img.z02
    mac-linux-gaming-stick-<VERSION>.img.zip
    ```
