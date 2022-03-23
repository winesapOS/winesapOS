#!/bin/bash

set -x

dmidecode -s system-product-name | grep -P ^Mac
if [ $? -eq 0 ]; then
    echo "Mac hardware detected."
    echo '1-3' > /sys/bus/usb/drivers/usb/unbind
    echo '1-3' > /sys/bus/usb/drivers/usb/bind
else
    echo "No Mac hardware detected."
fi

echo Done.
