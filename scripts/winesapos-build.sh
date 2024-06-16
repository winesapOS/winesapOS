#!/bin/bash

set -ex

export \
    WINESAPOS_CREATE_DEVICE=true \
    WINESAPOS_BUILD_IN_VM_ONLY=false

if [[ ! -z "${WINESAPOS_ENV_FILE}" ]]; then
    source "/workdir/scripts/env/${WINESAPOS_ENV_FILE}"
fi

/bin/bash /workdir/scripts/winesapos-install.sh
