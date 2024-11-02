#!/bin/bash

while true
    do if journalctl --unit sddm | grep -q "Could not start Display server on"; then
        echo "Display manager working NOT normally."
        echo -e "winesapOS\n\nSDDM has failed to start. You are now in a TTY for troubleshooting.\nPossible causes might be a bad display server configuration or other graphical issues.\nYou can try to fix the issue here or reboot the system.\nFor more detailed logs, use \'journalctl -xe | grep sddm\'.\n\n" > /etc/issue
        /usr/bin/chvt 2
        exit
    else
        echo "Display manager working normally."
        echo -e "winesapOS\n\n" > /etc/issue
    fi
    sleep 5s
 done
