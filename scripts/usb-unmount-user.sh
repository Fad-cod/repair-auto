#!/bin/bash
# usb-unmount-user.sh - Gère le retrait de la clé USB (user fadele only)
# Appelé par udev via systemd-run --uid=1000
#
# Ce script est exécuté quand une clé USB est retirée et :
# 1. Nettoie le montage si nécessaire
# 2. Envoie une notification bureau
# 3. Logue dans journalctl

DEVICE="$1"
DEVNAME=$(basename "$DEVICE")

# Vérifier que c'est une partition
[[ ! "$DEVICE" =~ ^/dev/sd[a-z][0-9]+$ ]] && exit 0

echo "[$(date)] USB Remove: $DEVICE détecté" | systemd-cat -t usb-unmount

# Tenter de démonter (si encore monté)
udisksctl unmount -b "$DEVICE" 2>&1 | systemd-cat -t usb-unmount

# Notification bureau
notify-send "Clé USB retirée" "$DEVICE a été déconnectée" --icon=drive-removable-media

echo "[$(date)] Clé USB retirée: $DEVICE" | systemd-cat -t usb-unmount

exit 0
