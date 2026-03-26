#!/bin/bash
# usb-ntfs-repair.sh - Répare la clé USB (root only)
# Appelé par udev via systemd-run
# 
# Ce script est exécuté en tant que root et :
# 1. Répare le système de fichiers (ntfsfix/fsck)
# 2. Lance le script de montage en tant que l'utilisateur

DEVICE="$1"
DEVNAME=$(basename "$DEVICE")

# Vérifier que c'est une partition (ex: sdb1, pas sdb)
[[ ! "$DEVICE" =~ ^/dev/sd[a-z][0-9]+$ ]] && exit 0

FSTYPE=$(lsblk -no FSTYPE "$DEVICE" 2>/dev/null)

echo "[$(date)] USB Repair: $DEVICE (fs: $FSTYPE)" | systemd-cat -t usb-repair

# Réparer selon le filesystem (root, pas besoin de sudo)
case "$FSTYPE" in
    ntfs|ntfs-3g)
        echo "Réparation NTFS en cours..." | systemd-cat -t usb-repair
        ntfsfix -d "$DEVICE" 2>&1 | systemd-cat -t usb-repair
        ;;
    vfat)
        echo "Vérification FAT en cours..." | systemd-cat -t usb-repair
        fsck.vfat -a "$DEVICE" 2>&1 | systemd-cat -t usb-repair
        ;;
    exfat)
        echo "Vérification exFAT en cours..." | systemd-cat -t usb-repair
        fsck.exfat -a "$DEVICE" 2>&1 | systemd-cat -t usb-repair
        ;;
esac

echo "[$(date)] Réparation terminée" | systemd-cat -t usb-repair

# Lancer le montage en tant que fadele (UID 1000) via systemd-run
# Le montage sera fait dans /run/media/fadele/ avec les bonnes permissions
echo "[$(date)] Lancement du montage (user fadele)..." | systemd-cat -t usb-repair
systemd-run --unit=usb-ntfs-mount-"$DEVNAME" \
    --uid=1000 --gid=1000 \
    --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
    /usr/local/bin/usb-ntfs-mount-user.sh "$DEVICE"

exit 0
