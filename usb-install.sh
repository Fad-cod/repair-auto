#!/bin/bash
# usb-install.sh - Installation automatique du système de montage USB
# Compatible : Arch/EndeavourOS, Debian/Ubuntu, Fedora/RHEL, openSUSE
# Auteur : fadele
# Usage : sudo bash usb-install.sh [--force | --uninstall]

set -e

# ─────────────────────────────────────────
# COULEURS
# ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; exit 1; }
info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

# ─────────────────────────────────────────
# VÉRIFICATION ROOT
# ─────────────────────────────────────────
[[ $EUID -ne 0 ]] && err "Ce script doit être exécuté en root (sudo bash usb-install.sh)"

# ─────────────────────────────────────────
# DÉTECTION UTILISATEUR RÉEL (pas root)
# ─────────────────────────────────────────
detect_user() {
    if [[ -n "$SUDO_USER" ]]; then
        REAL_USER="$SUDO_USER"
    else
        REAL_USER=$(ls /home | head -1)
    fi

    [[ -z "$REAL_USER" ]] && err "Impossible de détecter l'utilisateur réel."

    REAL_UID=$(id -u "$REAL_USER" 2>/dev/null) || err "Utilisateur '$REAL_USER' introuvable."
    REAL_GID=$(id -g "$REAL_USER" 2>/dev/null)

    info "Utilisateur détecté : $REAL_USER (uid=$REAL_UID, gid=$REAL_GID)"
}

# ─────────────────────────────────────────
# DÉTECTION DISTRIBUTION
# ─────────────────────────────────────────
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_ID="${ID,,}"
        DISTRO_LIKE="${ID_LIKE,,}"
    else
        err "Impossible de détecter la distribution (/etc/os-release absent)"
    fi

    if [[ "$DISTRO_ID" == "arch" || "$DISTRO_LIKE" == *"arch"* ]]; then
        DISTRO_FAMILY="arch"
        PKG_MANAGER="pacman"
        PKG_INSTALL="pacman -S --noconfirm"
        PKG_QUERY="pacman -Q"
        NTFS_PKG="ntfs-3g"
        GVFS_PKG="gvfs"
        EXFAT_PKG="exfatprogs"
        NOTIFY_PKG="libnotify"
        FSCK_VFAT="dosfstools"
        POLKIT_PKG="polkit"

    elif [[ "$DISTRO_ID" == "debian" || "$DISTRO_ID" == "ubuntu" || "$DISTRO_LIKE" == *"debian"* || "$DISTRO_LIKE" == *"ubuntu"* ]]; then
        DISTRO_FAMILY="debian"
        PKG_MANAGER="apt"
        PKG_INSTALL="apt-get install -y"
        PKG_QUERY="dpkg -l"
        NTFS_PKG="ntfs-3g"
        GVFS_PKG="gvfs-daemons"
        EXFAT_PKG="exfatprogs"
        NOTIFY_PKG="libnotify-bin"
        FSCK_VFAT="dosfstools"
        POLKIT_PKG="polkit"

    elif [[ "$DISTRO_ID" == "fedora" || "$DISTRO_LIKE" == *"rhel"* || "$DISTRO_LIKE" == *"fedora"* ]]; then
        DISTRO_FAMILY="fedora"
        PKG_MANAGER="dnf"
        PKG_INSTALL="dnf install -y"
        PKG_QUERY="rpm -q"
        NTFS_PKG="ntfs-3g"
        GVFS_PKG="gvfs"
        EXFAT_PKG="exfatprogs"
        NOTIFY_PKG="libnotify"
        FSCK_VFAT="dosfstools"
        POLKIT_PKG="polkit"

    elif [[ "$DISTRO_ID" == "opensuse"* || "$DISTRO_LIKE" == *"suse"* ]]; then
        DISTRO_FAMILY="opensuse"
        PKG_MANAGER="zypper"
        PKG_INSTALL="zypper install -y"
        PKG_QUERY="rpm -q"
        NTFS_PKG="ntfs-3g"
        GVFS_PKG="gvfs"
        EXFAT_PKG="exfatprogs"
        NOTIFY_PKG="libnotify-tools"
        FSCK_VFAT="dosfstools"
        POLKIT_PKG="polkit"

    else
        err "Distribution non supportée : $DISTRO_ID\nSupportées : Arch, Debian/Ubuntu, Fedora/RHEL, openSUSE"
    fi

    ok "Distribution détectée : $PRETTY_NAME (famille: $DISTRO_FAMILY)"
}

# ─────────────────────────────────────────
# VÉRIFICATION DES DÉPENDANCES
# ─────────────────────────────────────────
pkg_installed() {
    case "$DISTRO_FAMILY" in
        arch)     pacman -Q "$1" &>/dev/null ;;
        debian)   dpkg -l "$1" 2>/dev/null | grep -q "^ii" ;;
        fedora)   rpm -q "$1" &>/dev/null ;;
        opensuse) rpm -q "$1" &>/dev/null ;;
    esac
}

install_dependencies() {
    info "Vérification des dépendances..."
    local to_install=()

    # polkit
    if pkg_installed "$POLKIT_PKG"; then
        ok "$POLKIT_PKG déjà installé"
    else
        warn "$POLKIT_PKG manquant — sera installé"
        to_install+=("$POLKIT_PKG")
    fi

    # Autres dépendances
    for pkg in "$NTFS_PKG" "$GVFS_PKG" "$EXFAT_PKG" "$NOTIFY_PKG" "$FSCK_VFAT"; do
        if pkg_installed "$pkg"; then
            ok "$pkg déjà installé"
        else
            warn "$pkg manquant — sera installé"
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installation : ${to_install[*]}"
        $PKG_INSTALL "${to_install[@]}" || err "Échec installation des paquets"
        ok "Paquets installés"
    else
        ok "Toutes les dépendances sont présentes"
    fi
}

# ─────────────────────────────────────────
# CRÉATION DES SCRIPTS
# ─────────────────────────────────────────
create_scripts() {
    info "Création des scripts..."

    # ── usb-ntfs-repair.sh ──
    cat > /usr/local/bin/usb-ntfs-repair.sh << SCRIPT
#!/bin/bash
DEVICE="\$1"
DEVNAME=\$(basename "\$DEVICE")

[[ ! "\$DEVICE" =~ ^/dev/sd[a-z][0-9]+$ ]] && exit 0

FSTYPE=\$(lsblk -no FSTYPE "\$DEVICE" 2>/dev/null)
echo "[\$(date)] USB Repair: \$DEVICE (fs: \$FSTYPE)" | systemd-cat -t usb-repair

case "\$FSTYPE" in
    ntfs|ntfs-3g)
        echo "Réparation NTFS..." | systemd-cat -t usb-repair
        ntfsfix -d "\$DEVICE" 2>&1 | systemd-cat -t usb-repair
        ;;
    vfat)
        echo "Vérification FAT..." | systemd-cat -t usb-repair
        fsck.vfat -a "\$DEVICE" 2>&1 | systemd-cat -t usb-repair
        ;;
    exfat)
        echo "Vérification exFAT..." | systemd-cat -t usb-repair
        fsck.exfat -a "\$DEVICE" 2>&1 | systemd-cat -t usb-repair
        ;;
    *)
        exit 0
        ;;
esac

echo "[\$(date)] Réparation terminée, lancement montage..." | systemd-cat -t usb-repair

systemd-run --unit=usb-ntfs-mount-"\$DEVNAME" \\
    --uid=${REAL_UID} --gid=${REAL_GID} \\
    --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${REAL_UID}/bus \\
    /usr/local/bin/usb-ntfs-mount-user.sh "\$DEVICE"

exit 0
SCRIPT

    # ── usb-ntfs-mount-user.sh ──
    cat > /usr/local/bin/usb-ntfs-mount-user.sh << SCRIPT
#!/bin/bash
DEVICE="\$1"
DEVNAME=\$(basename "\$DEVICE")

[[ ! "\$DEVICE" =~ ^/dev/sd[a-z][0-9]+$ ]] && exit 0

FSTYPE=\$(lsblk -no FSTYPE "\$DEVICE" 2>/dev/null)
echo "[\$(date)] USB Mount: \$DEVICE (fs: \$FSTYPE)" | systemd-cat -t usb-mount

udisksctl mount -b "\$DEVICE" --no-user-interaction 2>&1 | systemd-cat -t usb-mount
RESULT=\$?

if [ \$RESULT -eq 0 ]; then
    MOUNTPOINT=\$(udisksctl info -b "\$DEVICE" 2>/dev/null | grep MountPoints | awk '{print \$2}')
    echo "[\$(date)] Montage réussi: \$MOUNTPOINT" | systemd-cat -t usb-mount
    notify-send "Clé USB montée" "\${MOUNTPOINT:-\$DEVICE}" --icon=drive-removable-media 2>/dev/null
else
    echo "[\$(date)] ÉCHEC montage: \$DEVICE" | systemd-cat -t usb-mount
    notify-send "Clé USB" "Échec du montage de \$DEVICE" --icon=dialog-error 2>/dev/null
fi

exit \$RESULT
SCRIPT

    # ── usb-unmount-user.sh ──
    cat > /usr/local/bin/usb-unmount-user.sh << SCRIPT
#!/bin/bash
DEVICE="\$1"

[[ ! "\$DEVICE" =~ ^/dev/sd[a-z][0-9]+$ ]] && exit 0

echo "[\$(date)] USB Remove: \$DEVICE" | systemd-cat -t usb-unmount

udisksctl unmount -b "\$DEVICE" --no-user-interaction 2>&1 | systemd-cat -t usb-unmount
notify-send "Clé USB retirée" "\$DEVICE" --icon=drive-removable-media 2>/dev/null

exit 0
SCRIPT

    chmod +x /usr/local/bin/usb-ntfs-repair.sh
    chmod +x /usr/local/bin/usb-ntfs-mount-user.sh
    chmod +x /usr/local/bin/usb-unmount-user.sh

    ok "Scripts créés et rendus exécutables"
}

# ─────────────────────────────────────────
# RÈGLES UDEV
# ─────────────────────────────────────────
create_udev_rules() {
    info "Création des règles udev..."

    cat > /etc/udev/rules.d/90-usb-repair.rules << 'RULES'
# Montage USB avec réparation automatique
# Filtre USB uniquement (ID_BUS=="usb"), bloque udisks2 pendant réparation

ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", ENV{ID_BUS}=="usb", ENV{ID_FS_TYPE}=="ntfs*", ENV{UDISKS_AUTO}="0", RUN+="/usr/bin/systemd-run --unit=usb-ntfs-repair-%k /usr/local/bin/usb-ntfs-repair.sh /dev/%k"
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", ENV{ID_BUS}=="usb", ENV{ID_FS_TYPE}=="vfat", ENV{UDISKS_AUTO}="0", RUN+="/usr/bin/systemd-run --unit=usb-ntfs-repair-%k /usr/local/bin/usb-ntfs-repair.sh /dev/%k"
ACTION=="add", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", ENV{ID_BUS}=="usb", ENV{ID_FS_TYPE}=="exfat", ENV{UDISKS_AUTO}="0", RUN+="/usr/bin/systemd-run --unit=usb-ntfs-repair-%k /usr/local/bin/usb-ntfs-repair.sh /dev/%k"
RULES

    cat > /etc/udev/rules.d/91-usb-remove.rules << RULES
ACTION=="remove", SUBSYSTEM=="block", KERNEL=="sd[a-z][0-9]", ENV{ID_BUS}=="usb", RUN+="/usr/bin/systemd-run --uid=${REAL_UID} --gid=${REAL_GID} --setenv=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${REAL_UID}/bus /usr/local/bin/usb-unmount-user.sh /dev/%k"
RULES

    ok "Règles udev créées"
}

# ─────────────────────────────────────────
# POLKIT
# ─────────────────────────────────────────
create_polkit_rule() {
    info "Configuration polkit..."

    cat > /etc/polkit-1/rules.d/49-udisks2.rules << POLKIT
// Autoriser $REAL_USER à monter sans authentification
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.udisks2.filesystem-mount") === 0 &&
        subject.user === "$REAL_USER") {
        return polkit.Result.YES;
    }
});
POLKIT

    ok "Règle polkit créée"
}

# ─────────────────────────────────────────
# RECHARGEMENT
# ─────────────────────────────────────────
reload_services() {
    info "Rechargement des services..."
    systemctl daemon-reload
    udevadm control --reload-rules
    udevadm trigger
    systemctl reset-failed 2>/dev/null || true
    ok "udev et systemd rechargés"
}

# ─────────────────────────────────────────
# DÉSINSTALLATION
# ─────────────────────────────────────────
uninstall() {
    warn "Désinstallation du système USB Auto-Mount..."
    echo ""

    rm -f /usr/local/bin/usb-ntfs-repair.sh
    rm -f /usr/local/bin/usb-ntfs-mount-user.sh
    rm -f /usr/local/bin/usb-unmount-user.sh
    ok "Scripts supprimés"

    rm -f /etc/udev/rules.d/90-usb-repair.rules
    rm -f /etc/udev/rules.d/91-usb-remove.rules
    ok "Règles udev supprimées"

    rm -f /etc/polkit-1/rules.d/49-udisks2.rules
    ok "Règle polkit supprimée"

    systemctl daemon-reload
    udevadm control --reload-rules
    ok "Services rechargés"

    echo ""
    ok "Désinstallation terminée !"
    exit 0
}

# ─────────────────────────────────────────
# RÉSUMÉ
# ─────────────────────────────────────────
print_summary() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Installation terminée avec succès !${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo ""
    echo "  Distribution : $PRETTY_NAME"
    echo "  Utilisateur  : $REAL_USER (uid=$REAL_UID)"
    echo ""
    echo "  Fichiers installés :"
    echo "  ├── /usr/local/bin/usb-ntfs-repair.sh"
    echo "  ├── /usr/local/bin/usb-ntfs-mount-user.sh"
    echo "  ├── /usr/local/bin/usb-unmount-user.sh"
    echo "  ├── /etc/udev/rules.d/90-usb-repair.rules"
    echo "  ├── /etc/udev/rules.d/91-usb-remove.rules"
    echo "  └── /etc/polkit-1/rules.d/49-udisks2.rules"
    echo ""
    echo "  Logs : journalctl -t usb-repair -t usb-mount -t usb-unmount"
    echo ""
    warn "Edge case connu : si clé branchée avant login,"
    warn "/run/user/${REAL_UID}/bus n'existe pas encore → montage échouera."
    echo ""
}

# ─────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────
main() {
    # Gérer --uninstall
    if [[ "$1" == "--uninstall" || "$1" == "-u" ]]; then
        uninstall
    fi

    # Gérer --force
    FORCE=false
    if [[ "$1" == "--force" || "$1" == "-f" ]]; then
        FORCE=true
        info "Mode force activé — écrasement des fichiers existants"
    fi

    echo ""
    info "=== USB Auto-Mount Installer ==="
    echo ""

    detect_user
    detect_distro
    install_dependencies
    create_scripts
    create_udev_rules
    create_polkit_rule
    reload_services
    print_summary
}

main "$@"
