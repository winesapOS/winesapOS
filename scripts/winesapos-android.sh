echo "This may take a while to install"
echo "installing Android"
# DONT REMOVE THESE LINES PLEASE THIS WILL BREAK EVERYTHING
yay -S waydroid
yay -S waydroid-image-gapps
yay -S waydroid-image
sudo systemctl enable --now waydroid-container
echo "Complete you may close this safely"
