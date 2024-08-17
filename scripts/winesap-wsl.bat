@echo off
setlocal

set TARFILE=winesapos-4.1.0-minimal-rootfs.tar.zst
set DistroName=winesapOS
set InstallPath=%LocalAppData%\Packages\%DistroName%

if not exist "%TARFILE%" (
    echo Downloading winesapOS tarball...
    powershell -Command "Invoke-WebRequest -Uri 'https://winesapos.lukeshort.cloud/repo/iso/winesapos-4.1.0/%TARFILE%' -OutFile '%TARFILE%'"
)

if not exist "%InstallPath%" (
    echo Creating installation directory...
    mkdir "%InstallPath%"
)

echo Extracting tarball...
tar -xJf "%TARFILE%" -C "%InstallPath%"

echo Registering WSL instance...
wsl --import %DistroName% "%InstallPath%" "%TARFILE%"

echo Setting up default user...
wsl -d %DistroName% bash -c "useradd -m -s /bin/bash winesap && echo 'winesap:winesap' | chpasswd"

echo winesapOS WSL installation complete!
pause

endlocal
