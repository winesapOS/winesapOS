#!/bin/bash

# winesapOS-pxeboot by GuestSneezeOSDev 
INTERFACE="eth0"  
TFTP_ROOT="/srv/tftp"
DHCP_RANGE_START="192.168.1.100"
DHCP_RANGE_END="192.168.1.200"
GATEWAY="192.168.1.1"
DNS_SERVER="192.168.1.1"

sudo pacman -Syu --noconfirm
sudo pacman -S dnsmasq syslinux --noconfirm

sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup

sudo tee /etc/dnsmasq.conf > /dev/null <<EOL
interface=${INTERFACE}
dhcp-range=${DHCP_RANGE_START},${DHCP_RANGE_END},12h
dhcp-boot=pxelinux.0
dhcp-option=3,${GATEWAY}
dhcp-option=6,${DNS_SERVER}

enable-tftp
tftp-root=${TFTP_ROOT}
EOL

sudo mkdir -p ${TFTP_ROOT}/pxelinux.cfg
sudo cp /usr/lib/syslinux/pxelinux.0 ${TFTP_ROOT}/
sudo cp /usr/lib/syslinux/{ldlinux.c32,libcom32.c32,libutil.c32,menu.c32} ${TFTP_ROOT}/

sudo tee ${TFTP_ROOT}/pxelinux.cfg/default > /dev/null <<EOL
DEFAULT menu.c32
PROMPT 0
TIMEOUT 50
MENU TITLE WINESAPOS-PXE Boot Menu

LABEL winesapOS
  MENU LABEL Boot winesapOS
  KERNEL vmlinuz-linux
  APPEND initrd=initramfs-linux.img root=/dev/sda1 rw
EOL

sudo systemctl enable dnsmasq
sudo systemctl start dnsmasq

echo "PXE boot server setup is complete!"
