# USB NTFS Auto-Mount avec Réparation Automatique

Solution automatique pour **réparer et monter les clés USB NTFS** sous Linux (Arch/EndeavourOS) sans intervention manuelle.

## 🎯 Problème résolu

Quand Windows laisse une clé USB dans un état "sale" (dirty bit activé, fast startup, débranchement brutal), Linux refuse de la monter en écriture ou affiche des erreurs cryptiques.

Ce système :
1. **Détecte** automatiquement le branchement d'une clé USB
2. **Répare** le système de fichiers (NTFS, FAT32, exFAT)
3. **Monte** la clé dans `/run/media/USERNAME/` avec les bonnes permissions
4. **Notifie** l'utilisateur via une notification bureau
5. **Gère le retrait** de la clé avec notification
6. **Tout ça automatiquement** — aucune intervention manuelle requise

---

## 📁 Structure des fichiers

```
usb-ntfs-auto-mount/
├── scripts/
│   ├── usb-ntfs-repair.sh          # Réparation (root)
│   ├── usb-ntfs-mount-user.sh      # Montage + notification (utilisateur)
│   └── usb-unmount-user.sh         # Retrait + notification (utilisateur)
├── etc-udev-rules/
│   ├── 90-usb-repair.rules         # Règle udev (branchement)
│   └── 91-usb-remove.rules         # Règle udev (retrait)
├── etc-polkit-rules/
│   └── 49-udisks2.rules            # Autorisation polkit
├── usb-install.sh                  # Installation automatique
├── usb-uninstall.sh                # Désinstallation
└── README.md                       # Ce fichier
```

---

## 🚀 Installation rapide

```bash
# Aller dans le dossier
cd ~/Bureau/usb-ntfs-auto-mount/

# Lancer l'installation (détecte ton utilisateur automatiquement)
sudo ./usb-install.sh

# Ou avec nom d'utilisateur personnalisé
sudo ./usb-install.sh ton-utilisateur 1000
```

### Installation manuelle

```bash
# 1. Copier les scripts
sudo cp scripts/usb-ntfs-repair.sh /usr/local/bin/
sudo cp scripts/usb-ntfs-mount-user.sh /usr/local/bin/
sudo cp scripts/usb-unmount-user.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/usb-ntfs-*.sh
sudo chmod +x /usr/local/bin/usb-unmount-user.sh

# 2. Copier les règles udev
sudo cp etc-udev-rules/90-usb-repair.rules /etc/udev/rules.d/
sudo cp etc-udev-rules/91-usb-remove.rules /etc/udev/rules.d/

# 3. Copier la règle polkit
sudo cp etc-polkit-rules/49-udisks2.rules /etc/polkit-1/rules.d/

# 4. Recharger les services
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo systemctl restart polkit
```

---

## 🧪 Utilisation

### Test automatique

1. **Branche** une clé USB NTFS
2. **Notification** bureau apparaît
3. **Vérifie** le montage :
   ```bash
   lsblk -f
   ```

La clé devrait être montée dans `/run/media/USERNAME/NOM_DE_LA_CLE/`

### Logs

```bash
# Voir tous les logs
journalctl -t usb-repair -t usb-mount -t usb-unmount

# Voir les logs en temps réel
journalctl -t usb-repair -t usb-mount -t usb-unmount -f

# Voir les logs depuis 1 heure
journalctl -t usb-repair -t usb-mount --since="1 hour ago"
```

---

## 🔧 Comment ça marche

```
┌─────────────────────────────────────────────────────────┐
│  BRANCHEMENT                                            │
│         ↓                                               │
│  1. udev détecte l'événement ADD                        │
│     → ENV{UDISKS_AUTO}="0" (bloque udisks2)            │
│     → ENV{ID_BUS}=="usb" (filtre USB uniquement)       │
│     → systemd-run usb-ntfs-repair.sh                   │
│         ↓                                               │
│  2. usb-ntfs-repair.sh (root)                           │
│     → ntfsfix -d /dev/sdX1 (répare NTFS)               │
│     → fsck.vfat -a /dev/sdX1 (FAT32)                   │
│     → fsck.exfat -a /dev/sdX1 (exFAT)                  │
│     → systemd-run --uid=1000 usb-ntfs-mount-user.sh    │
│         ↓                                               │
│  3. usb-ntfs-mount-user.sh (utilisateur)               │
│     → udisksctl mount -b /dev/sdX1                     │
│     → Monte dans /run/media/USERNAME/                  │
│     → notify-send "Clé USB montée"                     │
│         ↓                                               │
│  4. Clé accessible en lecture/écriture                 │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  RETRAIT                                                │
│         ↓                                               │
│  1. udev détecte l'événement REMOVE                     │
│     → systemd-run --uid=1000 usb-unmount-user.sh       │
│         ↓                                               │
│  2. usb-unmount-user.sh (utilisateur)                   │
│     → udisksctl unmount -b /dev/sdX1                   │
│     → notify-send "Clé USB retirée"                    │
│         ↓                                               │
│  3. Clé proprement démontée                            │
└─────────────────────────────────────────────────────────┘
```

---

## 🛡️ Sécurité

### Ce qui est sécurisé :

- ✅ **Filtre USB uniquement** (`ID_BUS=="usb"`) — ne touche pas aux disques internes
- ✅ **Pas de sudo dans les scripts** — chaque script tourne avec les permissions appropriées
- ✅ **Pas de chmod 777** — les permissions sont gérées proprement via udisks2
- ✅ **Polkit restreint** — seul l'utilisateur spécifié est autorisé
- ✅ **Logs via journalctl** — pas de fichiers texte sensibles

### Edge cases connus :

- ⚠️ **Branchement avant login** — Si la clé est branchée avant que la session utilisateur ne soit active (`/run/user/1000/bus` n'existe pas encore), le montage échouera. Cas rare.

---

## 🧰 Dépannage

### La clé ne se monte pas

```bash
# Vérifier les logs
journalctl -t usb-repair -t usb-mount --since="5 minutes ago"

# Vérifier si la clé est détectée
lsusb

# Vérifier les partitions
lsblk -f

# Vérifier l'état des services
systemctl --failed
```

### Erreur "Not authorized"

Vérifie que la règle polkit est bien installée :

```bash
sudo cat /etc/polkit-1/rules.d/49-udisks2.rules
```

Redémarre polkit :

```bash
sudo systemctl restart polkit
```

### Les notifications ne s'affichent pas

Vérifie que `libnotify` est installé :

```bash
pacman -Q libnotify
```

Installe si nécessaire :

```bash
sudo pacman -S libnotify
```

---

## 📝 Fichiers de configuration

### `/etc/udev/rules.d/90-usb-repair.rules`

Déclenche la réparation au branchement d'une clé USB.

### `/etc/udev/rules.d/91-usb-remove.rules`

Déclenche la notification et le nettoyage au retrait d'une clé USB.

### `/etc/polkit-1/rules.d/49-udisks2.rules`

Autorise l'utilisateur spécifié à monter des périphériques sans authentification.

### `/usr/local/bin/usb-ntfs-repair.sh`

Script de réparation (exécuté en root).

### `/usr/local/bin/usb-ntfs-mount-user.sh`

Script de montage + notification (exécuté en tant que l'utilisateur).

### `/usr/local/bin/usb-unmount-user.sh`

Script de retrait + notification (exécuté en tant que l'utilisateur).

---

## 🎯 Systèmes testés

- ✅ Arch Linux
- ✅ EndeavourOS
- ✅ KDE Plasma
- ✅ Hyprland
- ✅ XFCE
- ✅ Tout système avec systemd + udev + udisks2 + polkit + libnotify

---

## 📚 Ressources

- [ntfsfix man page](https://linux.die.net/man/8/ntfsfix)
- [udisks2 documentation](https://www.freedesktop.org/software/udisks2/)
- [Arch Wiki - udev](https://wiki.archlinux.org/title/Udev)
- [Arch Wiki - polkit](https://wiki.archlinux.org/title/Polkit)
- [libnotify](https://github.com/GNOME/libnotify)

---

## 🤝 Contributing

Les améliorations sont les bienvenues ! Notamment :

- Support multi-utilisateurs
- Fallback pour branchement avant login
- Notifications bureau personnalisées
- Support d'autres systèmes de fichiers

---

## 📄 License

MIT License — utilise librement.

---

## 🙏 Remerciements

Développé suite à des problèmes récurrents de clés USB NTFS laissées dans un état sale par Windows (fast startup, débranchements brutaux).

Merci à la communauté Arch/EndeavourOS pour le support !

---

## 📖 Historique des versions

### v1.1.0
- ✅ Ajout des notifications bureau (notify-send)
- ✅ Gestion du retrait des clés USB (91-usb-remove.rules)
- ✅ Script d'installation automatique (usb-install.sh)
- ✅ Script de désinstallation (usb-uninstall.sh)
- ✅ Logs centralisés dans journalctl

### v1.0.0
- ✅ Réparation automatique NTFS/FAT32/exFAT
- ✅ Montage automatique via udisks2
- ✅ Filtre USB uniquement (pas de disques internes)
- ✅ Permissions utilisateur correctes
