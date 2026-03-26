#!/bin/bash
# usb-ntfs-mount-user.sh - Monte la clé USB (user fadele only)
# Appelé par usb-ntfs-repair.sh via systemd-run --uid=1000
#
# Ce script est exécuté en tant que l'utilisateur (fadele) et :
# 1. Utilise udisksctl pour monter la clé
# 2. Le montage se fait dans /run/media/fadele/ avec les bonnes permissions
# 3. Envoie une notification bureau après montage

DEVICE="$1"
DEVNAME=$(basename "$DEVICE")

# Vérifier que c'est une partition (ex: sdb1, pas sdb)
[[ ! "$DEVICE" =~ ^/dev/sd[a-z][0-9]+$ ]] && exit 0

FSTYPE=$(lsblk -no FSTYPE "$DEVICE" 2>/dev/null)

echo "[$(date)] USB Mount (user): $DEVICE (fs: $FSTYPE)" | systemd-cat -t usb-mount

# Monter via udisksctl (utilise D-Bus session, monte dans /run/media/fadele/)
echo "Tentative de montage via udisks2..." | systemd-cat -t usb-mount
udisksctl mount -b "$DEVICE" --no-user-interaction 2>&1 | systemd-cat -t usb-mount

RESULT=$?

if [ $RESULT -eq 0 ]; then
    # Récupérer le point de montage
    MOUNTPOINT=$(udisksctl info -b "$DEVICE" | grep MountPoints | awk '{print $2}')
    
    echo "[$(date)] Montage réussi: $DEVICE -> $MOUNTPOINT" | systemd-cat -t usb-mount
    
    # Notification bureau
    notify-send "Clé USB montée" "$MOUNTPOINT" --icon=drive-removable-media
else
    echo "[$(date)] ÉCHEC montage: $DEVICE (code: $RESULT)" | systemd-cat -t usb-mount
fi

exit $RESULT
