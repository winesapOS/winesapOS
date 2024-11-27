# TODO:
# Find a way to download the latest version of winesapOS without updating the script 
# OR
# ask the user which version (4.1.0 - Latest version)
$installPath = "$env:LOCALAPPDATA\Packages\winesapos"
$winesaposTarballCompressedUrl = "https://winesapos.lukeshort.cloud/repo/iso/winesapos-4.2.0/winesapos-4.2.0-minimal-rootfs.tar.zst"
$winesaposTarballCompressedPath = "$installPath\winesapos.tar.zst"
$winesaposTarballUncompressedPath = "$installPath\winesapos.tar"
$zstdUrl = "https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-v1.5.5-win64.zip"
$zstdZipPath = "$env:TEMP\zstd.zip"
$zstdExtractPath = "$env:TEMP\zstd"


if (-not (Get-Command "zstd" -ErrorAction SilentlyContinue)) {
    Invoke-WebRequest -Uri $zstdUrl -OutFile $zstdZipPath

    if (-not (Test-Path $zstdExtractPath)) {
        New-Item -Path $zstdExtractPath -ItemType Directory
    }

    Expand-Archive -Path $zstdZipPath -DestinationPath $zstdExtractPath -Force

    [System.Environment]::SetEnvironmentVariable("PATH", "$env:PATH;$zstdExtractPath\zstd-v1.5.5-win64", [System.EnvironmentVariableTarget]::Machine)

    Remove-Item -Path $zstdZipPath

    Write-Output "zstd installed successfully."
} else {
    Write-Output "zstd is already installed."
}

if (-not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath -Force
}

Invoke-WebRequest -Uri $winesaposTarballCompressedUrl -OutFile $winesaposTarballCompressedPath

zstd --decompress $winesaposTarballCompressedPath

wsl --import winesapos $installPath $winesaposTarballUncompressedPath

Write-Output "winesapOS successfully added to WSL."
