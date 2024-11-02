#!/bin/bash

set -ex

export \
    WINESAPOS_CREATE_DEVICE=true \
    WINESAPOS_BUILD_IN_VM_ONLY=false

if [[ -n "${WINESAPOS_ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "/workdir/scripts/env/${WINESAPOS_ENV_FILE}"
fi

/bin/bash /workdir/scripts/winesapos-install.sh
