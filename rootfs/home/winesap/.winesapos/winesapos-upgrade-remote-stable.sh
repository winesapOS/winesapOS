#!/bin/bash

set -x

if kdialog --title "winesapOS Upgrade" --yesno "Do you want to upgrade winesapOS?\nThis may take a long time."; then
    # The secure image requires that the "sudo" password be provided for the "winesap" user.
    # This password is also required to be reset during the first login so it is unknown.
    # Prompt the user to enter in their password.
    # On other image types, they do not require a password to run "sudo" commands so using
    # the command "sudo -S" to read the password from standard input still works as expected.
    while true;
        do user_pw=$(kdialog --title "winesapOS Upgrade" --password 'Please enter your password (default: "winesap") to start the upgrade.')
        if echo "${user_pw}" | sudo -S whoami; then
            # Break out of the "while" loop if the password works with the "sudo -S" command.
            break 2
        fi
    done
    echo "${USER}" > /tmp/winesapos_user_name.txt
    curl https://raw.githubusercontent.com/winesapOS/winesapOS/stable/scripts/winesapos-upgrade.sh | sudo -E bash
fi

kdialog --title "winesapOS Upgrade" --msgbox "Upgrade complete."
