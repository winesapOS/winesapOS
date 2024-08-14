$installPath = "$env:LOCALAPPDATA\Packages\winesapos"
$winesaposTarballUrl = "https://winesapos.lukeshort.cloud/repo/iso/winesapos-4.1.0/winesapos-4.1.0-secure.img.zip"
$winesaposTarballPath = "$installPath\winesapos.tar.zst"

wsl --install

Invoke-WebRequest -Uri $winesaposTarballUrl -OutFile $winesaposTarballPath

if (-not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

wsl --import winesapos $installPath $winesaposTarballPath
wsl --set-default winesapos

Write-Output "winesapos distro installed successfully."
