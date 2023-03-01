#!/bin/zsh

git_create_repo_from_bare() {
    mkdir .git
    mv branches ./.git/
    mv config ./.git/
    mv description ./.git/
    mv HEAD ./.git/
    mv hooks ./.git/
    mv info ./.git/
    mv objects ./.git/
    mv packed-refs ./.git/
    mv refs ./.git/
    git config --local --bool core.bare false
    git reset --hard
}

# Mesa (mesa-steamos on AUR).
pkg=mesa-2
valve_pkg_ver=$(curl --list-only --silent https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter-main/os/x86_64/ | grep "href=\"${pkg}" | sort --version-sort | tail -n 1 | grep ${pkg} | cut -d\" -f4)
valve_pkg_src=$(curl --list-only --silent https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/jupiter-main/ | grep $(echo ${valve_pkg_ver} | cut -d\. -f1,2,3,4,5,6) | cut -d\" -f4 | grep -v -P "\.sig$" | grep "^${pkg}" | tail -n 1)
cd /tmp
wget --prefer-family=IPv4 "https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/jupiter-main/${valve_pkg_src}"
tar -x -v -f "${valve_pkg_src}"
cd mesa/jupiter-mesa/
git_create_repo_from_bare
git remote add lukeshortcloud git@github.com:LukeShortCloud/steamos-jupiter-mesa.git
git push lukeshortcloud --all
git push lukeshortcloud --tags

# Linux Neptune (linux-steamos on AUR).
pkg=linux-neptune-5\.13
valve_pkg_ver=$(curl --list-only --silent https://steamdeck-packages.steamos.cloud/archlinux-mirror/jupiter-main/os/x86_64/ | grep "href=\"${pkg}" | sort --version-sort | tail -n 1 | grep ${pkg} | cut -d\" -f4)
valve_pkg_src=$(curl --list-only --silent https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/jupiter-main/ | grep $(echo ${valve_pkg_ver} | cut -d\. -f1,2,3,4 | cut -d\- -f1,2,3,4) | cut -d\" -f4 | grep -v -P "\.sig$")
cd /tmp
wget --prefer-family=IPv4 "https://steamdeck-packages.steamos.cloud/archlinux-mirror/sources/jupiter-main/${valve_pkg_src}"
tar -x -v -f "${valve_pkg_src}"
cd linux-neptune/archlinux-linux-neptune/
git_create_repo_from_bare
git remote add lukeshortcloud git@github.com:LukeShortCloud/steamos-linux-neptune.git
# This may fail but will get most of the new source code uploaded.
git push lukeshortcloud --all
# The tags are the most important as this is what the PKGBUILD will use.
git push lukeshortcloud --tags
