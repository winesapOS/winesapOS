#!/bin/bash

set -x

# Prepare the storage devices before the Calamares installer partitions them.
#
# Calamares runs 'btrfs check' before it shrinks a partition and treats anything that the check
# reports as a failure, which aborts the installation with an error that does not explain the cause.
# A stale free space tree is common on Btrfs installations such as Fedora and SteamOS and makes the
# check fail even though the file system is perfectly healthy:
#
#   Space key logical 1048576 length 4194304 has no corresponding block group
#
# The free space tree is only a cache. It is rebuilt automatically the next time that the file
# system is mounted, so it is safe to clear when it is the only problem that the check reports.
#
# This never exits with a failure. Being unable to prepare a file system is not a reason to stop the
# installation because the user may not even be installing onto that storage device.

# Only unmounted Btrfs file systems are considered. The live winesapOS media that is running the
# installer is mounted, so it is never touched.
for device in $(lsblk --noheadings --list --paths --output NAME,FSTYPE | awk '$2 == "btrfs" {print $1}'); do
    if findmnt --source "${device}" &> /dev/null; then
        echo "INFO: ${device} is mounted. Skipping."
        continue
    fi

    if check_output="$(btrfs check "${device}" 2>&1)"; then
        echo "INFO: ${device} passed the file system check."
        continue
    fi

    if ! echo "${check_output}" | grep -q "has no corresponding block group"; then
        echo "WARNING: ${device} failed the file system check for a reason that cannot be repaired automatically."
        echo "${check_output}"
        continue
    fi

    echo "INFO: Clearing the stale free space tree on ${device}..."
    if ! btrfs rescue clear-space-cache v2 "${device}"; then
        echo "WARNING: Failed to clear the free space tree on ${device}."
        continue
    fi

    if btrfs check "${device}" &> /dev/null; then
        echo "INFO: ${device} now passes the file system check."
    else
        echo "WARNING: ${device} still fails the file system check."
    fi
done

exit 0
