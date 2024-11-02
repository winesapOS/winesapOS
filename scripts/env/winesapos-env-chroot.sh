#!/bin/bash

# shellcheck disable=SC1091
. "$(dirname "$0")/winesapos-env-minimal.sh"
export \
    WINESAPOS_BUILD_CHROOT_ONLY=true
