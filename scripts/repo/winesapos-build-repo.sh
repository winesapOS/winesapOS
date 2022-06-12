#!/bin/sh

set -x

WORK_DIR="${WORK_DIR:-/tmp}"
OUTPUT_DIR="${OUTPUT_DIR:-/output}"
CMD_PACMAN_INSTALL=(/usr/bin/pacman --noconfirm -S --needed)
CMD_YAY_INSTALL=(yay --noconfirm -S --removemake)
echo 'MAKEFLAGS="-j $(nproc)"' | sudo tee -a /etc/makepkg.conf

sudo pacman -S -y -y --noconfirm

# Install yay for helping install AUR build dependencies.
sudo -E ${CMD_PACMAN_INSTALL[*]} base-devel binutils curl dkms git make tar wget
export YAY_VER="11.1.2"
curl https://github.com/Jguer/yay/releases/download/v${YAY_VER}/yay_${YAY_VER}_x86_64.tar.gz --remote-name --location
tar -x -v -f yay_${YAY_VER}_x86_64.tar.gz
sudo mv yay_${YAY_VER}_x86_64/yay /usr/bin/yay
rm -rf ./yay*

# Pamac.
## vala dependency for Pamac.
### Build dependencies for vala.
sudo -E ${CMD_PACMAN_INSTALL[*]} dbus gobject-introspection libx11
#### vala 0.54.6-1.
mkdir ${WORK_DIR}/vala/
cd ${WORK_DIR}/vala
wget https://raw.githubusercontent.com/archlinux/svntogit-packages/9b2b7e9e326dff5af4d3ee49f5b3971462a046ff/trunk/PKGBUILD
makepkg -s --noconfirm
cp vala*.pkg.tar.zst ${OUTPUT_DIR}
cd -
## libpamac dependency for Pamac.
### Build dependencies for libpamac-full.
${CMD_YAY_INSTALL[*]} archlinux-appstream-data-pamac asciidoc flatpak gettext gobject-introspection itstool libhandy libnotify meson ninja snapd snapd-glib xorgproto
#### libpamac-full 11.2.0-1.
mkdir ${WORK_DIR}/libpamac-full
cd ${WORK_DIR}/libpamac-full
wget https://aur.archlinux.org/cgit/aur.git/snapshot/aur-a2fb8db350a87e4e94bbf5af6b3f960c8959ad85.tar.gz
tar -xvf aur-a2fb8db350a87e4e94bbf5af6b3f960c8959ad85.tar.gz
cd aur-a2fb8db350a87e4e94bbf5af6b3f960c8959ad85
makepkg -s --noconfirm
cp libpamac-full*.pkg.tar.zst ${OUTPUT_DIR}
cd -

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
