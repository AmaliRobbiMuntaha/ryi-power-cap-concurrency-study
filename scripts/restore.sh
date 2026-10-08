#!/bin/bash

sudo systemctl start NetworkManager
sudo systemctl start wpa_supplicant
sudo systemctl start sshd
sudo systemctl start bluetooth
sudo systemctl start cups
sudo systemctl start cronie
sudo systemctl start systemd-timesyncd
sudo systemctl start power-profiles-daemon
sudo systemctl start systemd-timesyncd.service
sudo systemctl start udisks2.service
sudo systemctl start ananicy-cpp.service

sudo systemctl start archlinux-keyring-wkd-sync.timer
sudo systemctl start man-db.timer
sudo systemctl start shadow.timer
sudo systemctl start systemd-tmpfiles-clean.timer

sudo cpupower frequency-set -g performance
cpupower frequency-info
