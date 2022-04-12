#!/bin/zsh

set -ex

export \
    WINESAPOS_DEBUG_INSTALL=true \
    WINESAPOS_CREATE_DEVICE=true \
    WINESAPOS_BUILD_IN_VM_ONLY=false

/bin/zsh scripts/winesapos-install.sh

## we need to introduce versioning here
zip -s 1900m winesapos.img.zip winesapos.img
mv winesapos.img.* /workdir/output/
sha512sum /workdir/output/winesapos.img.* > /workdir/output/winesapos-sha512sum.txt
