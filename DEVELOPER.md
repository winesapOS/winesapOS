# mac-linux-gaming-stick Developer Guide

## Build

### Create Virtual Machine

A virtual machine is used to build `mac-linux-gaming-stick` in a safe and isolated manner. The disks on the hypervisor will not be touched. It is assumed that QEMU/KVM will be used although other hypervisors can be used.

Requirements:

- UEFI boot
- 2 vCPUs
- 4 GB RAM
- 24 GB storage

#### CLI

```
$ sudo qemu-img create -f raw -o size=30G /var/lib/libvirt/images/mac-linux-gaming-stick.img
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

### Install Manjaro

Once the virtual machine is running, Manjaro can be installed. An automated script is provided to fully install Manjaro. This script will only work in a virtual machine. Clone the entire project repository. This will provide additional files and scripts that will be copied into the virtual machine image.

```
$ git clone https://github.com/ekultails/mac-linux-gaming-stick.git
$ cd mac-linux-gaming-stick/scripts/
$ sudo ./install-manjaro.sh 2> /dev/stdout | tee -a /tmp/install-manjaro.log
$ sudo cp /tmp/install-manjaro.log /mnt/etc/mac-linux-gaming-stick/
```

When complete, shutdown the virtual machine (do NOT restart).

### Test

On the hypervisor, clean up the virtual machine image. This will ensure that the image will generated unique values for additional security and stability.

```
$ sudo virt-sysprep -a /var/lib/libvirt/images/mac-linux-gaming-stick.img
```

Install the image onto an external storage device for testing.

```
$ sudo dd if=/var/lib/libvirt/images/mac-linux-gaming-stick.img of=/dev/<DEVICE>
```

## Release

For a new release, update the `VERSION` file in the git repository with the new version before building an image.

On the hypervisor, create a release by using the fast `zstd` compression utility.

```
$ cd /var/lib/libvirt/images/
$ sudo mv mac-linux-gaming-stick.img mac-linux-gaming-stick-<VERSION>.img
$ sudo zstd mac-linux-gaming-stick-<VERSION>.img
```
