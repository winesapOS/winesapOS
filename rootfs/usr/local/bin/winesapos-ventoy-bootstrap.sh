#!/bin/bash

set -x

export VENTOY_VER="1.0.35"
wget https://github.com/ventoy/vtoyboot/releases/download/v${VENTOY_VER}/vtoyboot-${VENTOY_VER}.iso
sudo mount vtoyboot-${VENTOY_VER}.iso /mnt
sudo mkdir /vtoyboot
sudo tar -xvf /mnt/vtoyboot-${VENTOY_VER}.tar.gz -C /vtoyboot
cd /vtoyboot/vtoyboot-${VENTOY_VER}/ || exit 1
sudo ./vtoyboot.sh
# shellcheck disable=SC2164
cd -
sudo umount /mnt
sudo rm -r -f /vtoyboot /vtoyboot-${VENTOY_VER}.iso
