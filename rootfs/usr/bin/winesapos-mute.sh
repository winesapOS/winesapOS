#!/bin/bash

set -x

if sudo /usr/bin/dmidecode -s system-product-name | grep -P ^Mac; then
    echo "Mac hardware detected."
    /usr/bin/pactl set-sink-volume 0 0

    if [ $? -eq 1 ]; then
        echo "Failed to mute volume."
        exit 1
    fi

else
    sudo /usr/bin/dmidecode -s system-product-name
    if [ $? -eq 1 ]; then
        echo "Failed to detect if the hardware is a Mac. Volume will be muted to be safe."
        /usr/bin/pactl set-sink-volume 0 0

        if [ $? -eq 1 ]; then
            echo "Failed to mute volume."
            exit 1
        fi

    else
        echo "No Mac hardware detected."
    fi
fi

echo Done.
