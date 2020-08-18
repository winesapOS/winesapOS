# Mac Linux Gaming Stick

Linux gaming, on a stick, designed for Mac enthusiasts. This is an opinonated take on creating a portable USB flash drive with Linux installed to enable gaming on a Mac (or any laptop) via Steam and Proton/Wine.

## Why?

- No 32-bit support in mac OS. The latest version is now 64-bit only. As of 2020, there are [less than 70 full PC games](https://www.macgamerhq.com/opinion/32-bit-mac-games/) (i.e., not apps) on mac OS that are available as 64-bit.
- Old and incomplete implementation of OpenGL.
- No native Vulkan support.
    - MoltenVK is [incomplete due to missing functionality in Apple's Metal API](https://github.com/KhronosGroup/MoltenVK/issues/203).
- Linux has better gaming support than mac OS because it supports 32-bit applications, DirectX (via Wine with WineD3D, DXVK, and/or Vkd3d), OpenGL, and Vulkan.
- Steam Play's Proton is only [supported on Linux](https://github.com/ValveSoftware/Proton/wiki/Requirements) ([not mac OS](https://github.com/ValveSoftware/Proton/issues/1344)).

## Goals

Goals:

- Portability. The flash drive should be bootable on both BIOS and UEFI systems.
- Gaming support out-of-the-box.
- Minimze writes to the flash drive to improve its longevity.
- Full backups via BtrFS and Snapper.
- Automatic operating system updates are disabled. Updates should always be intentional and planned.
- Battery optimizations.
- As much reproducible automation as possible via Ansible.
    - Any manual steps will be documented in this README file.

Not planned to support:

- Built-in sound.
- Built-in WiFi and/or Bluetooth.

It is easier and more reliable to buy additional hardware and use a USB-C hub than to rely on hacky Linux drivers for Mac. Workarounds do exist for [sound](https://github.com/davidjo/snd_hda_macbookpro) and [WiFi](https://gist.github.com/roadrunner2/1289542a748d9a104e7baec6a92f9cd7#gistcomment-3080934).

## Target Hardware

Mac:

- 2016-2017 Macbook Pro.

This guide should work for older models of Macs as well. Compatibility may vary with the latest Mac hardware.

Suggested hardware to buy:

- USB-C hub with USB-A ports and a 3.5mm audio port.
- Fast USB flash drive.
- WiFi USB adapter.
- Bluetooth USB adapter.
- USB speakers.

## Planning

- Test with Ubuntu 20.04.
    - Boot on an existing Mac.
    - Build automation using Ansible.
- Switch to elementary OS 6 (ETA: October 2020).
- Switch to Linux kernel 5.9 (ETA: October 4th 2020).

## License

GPLv3
