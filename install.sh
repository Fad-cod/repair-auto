#!/bin/bash
# install.sh - Script d'installation automatique
# Exécuter en tant que root ou avec sudo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERNAME="${1:-fadele}"
USERID="${2:-1000}"

echo "=========================================="
echo "  USB NTFS Auto-Mount - Installation"
echo "=========================================="
echo ""
echo "Utilisateur cible : $USERNAME (UID: $USERID)"
echo ""

# 1. Copier les scripts
echo "[1/5] Copie des scripts..."
sudo cp "$SCRIPT_DIR/scripts/usb-ntfs-repair.sh" /usr/local/bin/
sudo cp "$SCRIPT_DIR/scripts/usb-ntfs-mount-user.sh" /usr/local/bin/
sudo chmod +x /usr/local/bin/usb-ntfs-repair.sh /usr/local/bin/usb-ntfs-mount-user.sh
echo "      ✅ Scripts installés dans /usr/local/bin/"

# 2. Personnaliser usb-ntfs-repair.sh pour l'UID utilisateur
echo ""
echo "[2/5] Configuration de l'UID utilisateur..."
sudo sed -i "s/--uid=1000/--uid=$USERID/g" /usr/local/bin/usb-ntfs-repair.sh
sudo sed -i "s/--gid=1000/--gid=$USERID/g" /usr/local/bin/usb-ntfs-repair.sh
sudo sed -i "s|/run/user/1000/|/run/user/$USERID/|g" /usr/local/bin/usb-ntfs-repair.sh
echo "      ✅ UID configuré : $USERID"

# 3. Copier la règle udev
echo ""
echo "[3/5] Installation de la règle udev..."
sudo cp "$SCRIPT_DIR/etc-udev-rules/90-usb-repair.rules" /etc/udev/rules.d/
echo "      ✅ Règle udev installée"

# 4. Personnaliser et copier la règle polkit
echo ""
echo "[4/5] Installation de la règle polkit..."
# Créer une version personnalisée de la règle polkit
sudo sed "s/fadele/$USERNAME/g" "$SCRIPT_DIR/etc-polkit-rules/49-udisks2.rules" | \
    sudo tee /etc/polkit-1/rules.d/49-udisks2.rules > /dev/null
echo "      ✅ Règle polkit installée pour l'utilisateur : $USERNAME"

# 5. Recharger les services
echo ""
echo "[5/5] Rechargement des services..."
sudo udevadm control --reload-rules
sudo systemctl restart polkit
echo "      ✅ Services rechargés"

# Résumé
echo ""
echo "=========================================="
echo "  ✅ Installation terminée !"
echo "=========================================="
echo ""
echo "Pour tester :"
echo "  1. Branche une clé USB NTFS"
echo "  2. journalctl -t usb-repair -t usb-mount -f"
echo "  3. La clé sera montée dans /run/media/$USERNAME/"
echo ""
echo "Pour désinstaller :"
echo "  sudo rm /usr/local/bin/usb-ntfs-repair.sh"
echo "  sudo rm /usr/local/bin/usb-ntfs-mount-user.sh"
echo "  sudo rm /etc/udev/rules.d/90-usb-repair.rules"
echo "  sudo rm /etc/polkit-1/rules.d/49-udisks2.rules"
echo "  sudo udevadm control --reload-rules"
echo "  sudo systemctl restart polkit"
echo ""
