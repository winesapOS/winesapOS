#!/bin/zsh

set -x

kdialog --title "winesapOS Upgrade" --yesno "Do you want to upgrade winesapOS?\nThis may take a long time."
if [ $? -eq 0 ]; then
    curl https://raw.githubusercontent.com/LukeShortCloud/winesapOS/stable/scripts/winesapos-upgrade.sh | sudo zsh
fi

kdialog --title "winesapOS Upgrade" --msgbox "Upgrade complete."
