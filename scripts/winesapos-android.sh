echo "This may take a while to install"
echo "installing Android"
# DONT REMOVE THESE LINES PLEASE THIS WILL BREAK EVERYTHING
makepkg_fn waydroid install
makepkg_fn waydroid-image-gapps install
makepkg_fn waydroid-image
echo "Starting Container"
sudo systemctl enable --now waydroid-container
echo "Complete you may close this safely"
