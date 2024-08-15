$installPath = "$env:LOCALAPPDATA\Packages\winesapos"
$winesaposTarballUrl = "https://winesapos.lukeshort.cloud/repo/iso/winesapos-4.1.0/winesapos-4.1.0-minimal-rootfs.tar.zst"
$winesaposTarballPath = "$installPath\winesapos.tar.zst"
$zstdUrl = "https://github.com/facebook/zstd/releases/download/v1.5.5/zstd-v1.5.5-win64.zip"
$zstdZipPath = "$env:TEMP\zstd.zip"
$zstdExtractPath = "$env:ProgramFiles\zstd"

wsl --install

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

Invoke-WebRequest -Uri $winesaposTarballUrl -OutFile $winesaposTarballPath

wsl --import winesapos $installPath $winesaposTarballPath

wsl --set-default winesapos

Write-Output "winesapos distro installed successfully."
