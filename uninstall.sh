#!/bin/bash
# uninstall.sh - Script de désinstallation
# Exécuter en tant que root ou avec sudo

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
sudo rm -f /usr/local/bin/usb-ntfs-repair.sh
sudo rm -f /usr/local/bin/usb-ntfs-mount-user.sh
echo "      ✅ Scripts supprimés"

# 2. Supprimer la règle udev
echo ""
echo "[2/4] Suppression de la règle udev..."
sudo rm -f /etc/udev/rules.d/90-usb-repair.rules
echo "      ✅ Règle udev supprimée"

# 3. Supprimer la règle polkit
echo ""
echo "[3/4] Suppression de la règle polkit..."
sudo rm -f /etc/polkit-1/rules.d/49-udisks2.rules
echo "      ✅ Règle polkit supprimée"

# 4. Recharger les services
echo ""
echo "[4/4] Rechargement des services..."
sudo udevadm control --reload-rules
sudo systemctl restart polkit
echo "      ✅ Services rechargés"

# Résumé
echo ""
echo "=========================================="
echo "  ✅ Désinstallation terminée !"
echo "=========================================="
echo ""
echo "Les fichiers de configuration ont été supprimés."
echo "Le système de montage automatique USB est désactivé."
echo ""
