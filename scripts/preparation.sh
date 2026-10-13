#!/bin/bash

sudo systemctl stop NetworkManager
sudo systemctl stop wpa_supplicant
sudo systemctl stop sshd
sudo systemctl stop bluetooth
sudo systemctl stop cups
sudo systemctl stop cronie
sudo systemctl stop systemd-timesyncd
sudo systemctl stop power-profiles-daemon
sudo systemctl stop systemd-timesyncd.service # Prevents clock synchronization in the background
sudo systemctl stop udisks2.service           # Prevents the disk polling/automount daemon
sudo systemctl stop ananicy-cpp.service       # MUST BE STOPPED! Ananicy automatically changes the process ‘nice’ level and will disrupt your PCT scheduler control.

sudo systemctl stop archlinux-keyring-wkd-sync.timer
sudo systemctl stop man-db.timer
sudo systemctl stop shadow.timer
sudo systemctl stop systemd-tmpfiles-clean.timer

sudo cpupower frequency-set -g performance
cpupower frequency-info
