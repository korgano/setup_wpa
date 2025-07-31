# setup_wpa
Script for configuring iwlwifi on FreeBSD/OPNSense

## Instructions for Use

- Download `setup_wpa.sh`.
- Edit `SSID` and `psk` values to connect to the desired network (default = "Placeholder")
- If necessary, edit `iwlwifi0_wlan0` references to match your device's naming
- Copy to a USB drive
- Connect USB drive to FreeBSD/OPNSense box
- Use shell commands to mount USB drive
- Use shell commands to copy `setup_wpa.sh` to a local directory (Ex: `/usr/local/scripts`)
- Execute with `sh <path>/setup_wpa.sh `

## Recommended Text Editors

Edit setup_wpa.sh in a text editor that respects Linux/FreeBSD line endings. Using Notepad on a Windows machine may break the script and render it non-functional in your FreeBSD/OPNSense device.
