#!/bin/bash
sudo pacman -Syu --noconfirm
sudo pacman -S dnsmasq syslinux wget --noconfirm
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
sudo tee /etc/dnsmasq.conf > /dev/null <<EOL
interface=eth0
dhcp-range=192.168.1.100,192.168.1.200,12h
dhcp-boot=pxelinux.0
dhcp-option=3,192.168.1.1
dhcp-option=6,192.168.1.1
enable-tftp
tftp-root=/srv/tftp
EOL
sudo mkdir -p /srv/tftp/pxelinux.cfg
sudo cp /usr/lib/syslinux/pxelinux.0 /srv/tftp/
sudo cp /usr/lib/syslinux/{ldlinux.c32,libcom32.c32,libutil.c32,menu.c32} /srv/tftp/
sudo tee /srv/tftp/pxelinux.cfg/default > /dev/null <<EOL
DEFAULT menu.c32
PROMPT 0
TIMEOUT 50
MENU TITLE WINESAPOS-PXE Boot Menu
LABEL winesapOS
  MENU LABEL Boot winesapOS
  KERNEL vmlinuz-linux
  APPEND initrd=initramfs-linux.img root=/dev/nfs nfsroot=192.168.1.1:/srv/rootfs/winesapos-4.1.0 rw ip=dhcp
EOL
sudo mkdir -p /srv/rootfs/winesapos-4.2.0
wget -O /tmp/rootfs.tar.zst https://winesapos.lukeshort.cloud/repo/iso/winesapos-4.2.0/winesapos-4.2.0-minimal-rootfs.tar.zst
sudo tar -I zstd -xf /tmp/rootfs.tar.zst -C /srv/rootfs/winesapos-4.2.0
sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq
echo "PXE boot server setup is complete!"
