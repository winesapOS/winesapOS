#!/bin/sh

set -x

WORK_DIR="${WORK_DIR:-/tmp}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"

# Mesa 64-bit.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/mesa-steamos.git
cd mesa-steamos
makepkg -s --noconfirm
cp mesa-steamos*.pkg.tar.zst ${OUTPUT_DIR}

# Mesa 32-bit.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/lib32-mesa-steamos.git
cd lib32-mesa-steamos
makepkg -s --noconfirm
cp lib32-mesa-steamos*.pkg.tar.zst ${OUTPUT_DIR}

# Linux Neptune.
cd ${WORK_DIR}
git clone https://aur.archlinux.org/linux-steamos.git
cd linux-steamos
makepkg -s --noconfirm
cp linux-steamos*.pkg.tar.zst ${OUTPUT_DIR}

# Build Pacman repository metadata.
repo-add ${OUTPUT_DIR}/winesapos.db.tar.gz ${OUTPUT_DIR}/*pkg.tar.zst
