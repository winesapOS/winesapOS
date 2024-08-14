$installPath = "$env:LOCALAPPDATA\Packages\winesapos"
$winesaposTarballUrl = "https://winesapos.lukeshort.cloud/repo/iso/winesapos-4.1.0/_test/winesapos-4.1.0-beta.0-minimal-rootfs.tar.zst"
$winesaposTarballPath = "$installPath\winesapos.tar.zst"

wsl --install

Invoke-WebRequest -Uri $winesaposTarballUrl -OutFile $winesaposTarballPath

if (-not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

wsl --import winesapos $installPath $winesaposTarballPath
wsl --set-default winesapos

Write-Output "winesapos distro installed successfully."
