echo "This may take a while to install dependencies"
# This part will install yay
cd ~/
sudo pacman -S git
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
echo "Time To install Android"
# DONT REMOVE THESE LINES PLEASE THIS WILL BREAK EVERyTHING
yay -S waydroid
yay -S waydroid-image-gapps
yay -S waydroid-image
echo "Complete you may close this safely"
sudo systemctl enable --now waydroid-container
