#!/bin/bash

set -ex

export \
    WINESAPOS_DEBUG_INSTALL=true \
    WINESAPOS_DEBUG_TESTS=true \
    WINESAPOS_CREATE_DEVICE=true \
    WINESAPOS_CREATE_DEVICE_SIZE=7 \
    WINESAPOS_ENABLE_PORTABLE_STORAGE=false \
    WINESAPOS_BUILD_IN_VM_ONLY=false

/bin/bash /workdir/scripts/winesapos-install.sh

cp /tmp/winesapos-install.log ./
