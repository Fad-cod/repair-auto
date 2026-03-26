#!/bin/bash
# usb-uninstall.sh - Script de désinstallation
# Doit être exécuté en tant que root ou avec sudo

set -e

echo "=========================================="
echo "  USB NTFS Auto-Mount - Désinstallation"
echo "=========================================="
echo ""

read -p "Voulez-vous vraiment désinstaller ce système ? (o/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "Annulé."
    exit 0
fi

# 1. Supprimer les scripts
echo "[1/4] Suppression des scripts..."
rm -f /usr/local/bin/usb-ntfs-repair.sh
rm -f /usr/local/bin/usb-ntfs-mount-user.sh
rm -f /usr/local/bin/usb-unmount-user.sh
echo "      ✅ Scripts supprimés"

# 2. Supprimer les règles udev
echo ""
echo "[2/4] Suppression des règles udev..."
rm -f /etc/udev/rules.d/90-usb-repair.rules
rm -f /etc/udev/rules.d/91-usb-remove.rules
echo "      ✅ Règles udev supprimées"

# 3. Supprimer la règle polkit
echo ""
echo "[3/4] Suppression de la règle polkit..."
rm -f /etc/polkit-1/rules.d/49-udisks2.rules
echo "      ✅ Règle polkit supprimée"

# 4. Recharger les services
echo ""
echo "[4/4] Rechargement des services..."
systemctl daemon-reload
udevadm control --reload-rules
echo "      ✅ Services rechargés"

# Résumé
echo ""
echo "=========================================="
echo "  ✅ Désinstallation terminée !"
echo "=========================================="
echo ""
echo "Le système de montage automatique USB est désactivé."
echo "Les règles udev et polkit ont été supprimées."
echo ""
