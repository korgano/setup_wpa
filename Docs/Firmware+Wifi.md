This is for all the folks setting up OPNSense on a miniPC with Intel WiFi - specifically iwlwifi*, who want to use the WiFi for anything.

*I **think** this process could be used for other Intel WiFi systems with some tweaks, but I don't have systems to test with.

## Required Resources
- miniPC with OPNSense installed and Intel WiFi card using iwlwifi driver
- USB drive
- iwlwifi firmware (get it precompiled from my repo - https://github.com/korgano/iwlwifi-firmware )
- [My wifi setup script](https://github.com/korgano/setup_wpa/blob/main/setup_wpa.sh)
- A text editor that doesn't screw with line ending formats

## How do you know if you have an iwlwifi problem?
![OPNSense iwlwifi error messages due to missing iwlwifi firmware.](https://github.com/korgano/setup_wpa/blob/main/Docs/cyber-proj-tfb08a.jpg?raw=true)
You will typically see a lot of messages saying iwlwifi# cannot find a firmware image in OPNSense 25.1.8+, since they stopped including it in their build process.
Even if you miss it at boot, just restart your services and look for the messages to come in a big block.

Alternatively, go to the Shell and use the following command to get the list:
`dmesg | grep "firmware image"`

## What to Do
1. Find out what version of iwlwifi firmware you need.
2. Download the appropriate ZIP file from my iwlwifi-firmware repo.
3. Copy at least one firmware .ucode file to the USB drive.
    1. Only having one .ucode works on my system, but it might not for yours.
4. Download my wifi setup script from its repo.
5. Edit the script to remove the placeholder values for SSID and PSK in `/var/etc/wpa_supplicant_iwlwifi0_wlan0.conf`.
    1. Do this in a text editor that respects Linux/FreeBSD line endings.
    2. If you are not sure how your text editor handles line endings, edit the script on the OPNSense device before executing it.
6. Copy the script onto the same USB drive as the firmware.
7. Connect the USB drive to the miniPC.
8. Login as root and enter the shell.
9. Mount the USB drive.
    1. If you don't know how to do this, Microsoft Copilot will give you the commands.
    2. For USB drives with some kind of FAT format, use `mount -t msdosfs`
10. Copy the firmware .ucode file to `/boot/firmware`. This file **WILL** persist across updates through the OPNSense GUI/CLI.
11. Copy the setup script to a local directory like `/usr/local/scripts`.
12. If you didn't edit in the login credentials before, edit them in either before or after you copy the script.
13. Execute the script with command `sh <path>/setup_wpa.sh`.
14. You should see the following output: 
![OPNSense rebooting wpa_supplicant and initializing properly after script run.](https://github.com/korgano/setup_wpa/blob/main/Docs/cyber-proj-tfb25.jpg?raw=true)

If you had an assigned IP to the WiFi interface, from prior to an upgrade to 25.1.8+ or 25.7+, your connection should reestablish immediately.

## Setting up WiFi as Management Interface
This is for all the folks setting up dual ethernet N100 boxes as Transparent Filtering Bridges and need a management interface.
1. Connect to the miniPC via ethernet.
2. Log into the webGUI.
3. Go to `Rules>[Name of WiFi]`.
4. Make a rule allowing all traffic in from your router's IP address.
5. Create a rule allowing HTTPS web traffic with the following settings: 
![OPNSense rule settings to allow HTTPS connections into the iwlwifi connection.](https://github.com/korgano/setup_wpa/blob/main/Docs/opnsense-config-02.png?raw=true)

Apply the state type setting (`None`) to your router access rule as well.

For extra peace of mind, you can add an additional rule that's essentially the inverse of this, allowing all HTTPS traffic out from the interface to the network.

## Why do all this?
1. If you want to use your device's iwlwifi card, you need the firmware.
2. The combination of the default wpa_supplicant implementation and FreeBSD iwlwifi driver results in connection issues over 2+ hours.
    1. This was tested via setting up a cron job to restart the interface every 4 hours. Prior to the current version of the script, I was getting between 2 and 3 hours of connectivity, then connection failures.
    2. The current version of the script maintains connectivity through the entire 4 hour window between interface restarts.
3. For Transparent Filtering Bridges on dual ethernet systems, the WiFi might be the only available option for network connectivity, especially if your routers are fully port populated.
4. Removing states when accepting packets in on the WiFi interface allows you to keep the firewall up and maintain network connections.
5. Having the network stuff in a script allows you to quickly fix everything when OPNSense updates and reverts back to a less good default.

## TL;DR:
This is the solution to the problem I was having setting up my Transparent Filtering Bridge with WiFi as the management interface.
