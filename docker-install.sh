#!/bin/bash
#
# Docker Installations-Skript
# Erstellt für GitHub: https://github.com/staubi82/docker-install
#
# Dieses Skript installiert Docker und Docker Compose auf verschiedenen Linux-Distributionen
# und bietet die Möglichkeit, Docker-Management-Tools zu installieren.

# ===== Farbige Ausgabe und Hilfsfunktionen =====

# Farben sind wie RGB-LEDs in deinem Gaming-PC - unnötig, aber hey, es sieht cool aus!
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color - wie ein Bildschirm nach einem Bluescreen

# Animiertes Ladesymbol - weil statische Ausgaben so 1990 sind
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  
  echo -ne "${YELLOW}"
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
  echo -ne "${NC}"
}

# Führt einen Befehl aus und zeigt dabei ein Ladesymbol an
run_with_spinner() {
  local message=$1
  local command=$2
  
  echo -ne "${CYAN}$message${NC} "
  $command >/dev/null 2>&1 &
  spinner $!
  local exit_code=$?
  
  if [ $exit_code -eq 0 ]; then
    echo -e " ${GREEN}✓${NC}"
  else
    echo -e " ${RED}✗${NC}"
  fi
  
  return $exit_code
}

# Fortschrittsbalken - weil wir alle gerne zusehen, wie sich Balken füllen.
# Ist wie Bier einschenken, nur digitaler.
progress_bar() {
  local duration=$1
  local steps=20
  
  echo -ne "${YELLOW}[${NC}"
  for ((i=0; i<$steps; i++)); do
    echo -ne "${GREEN}#${NC}"
    sleep 0.1
  done
  echo -ne "${YELLOW}]${NC}"
  echo
}

# Log-Funktion - weil wir später nachweisen müssen, dass es nicht unsere Schuld war
log() {
  local level=$1
  local message=$2
  local color=$NC
  
  case $level in
    "INFO") color=$GREEN ;;
    "WARN") color=$YELLOW ;;
    "ERROR") color=$RED ;;
  esac
  
  echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message${NC}"
}

# Titel-Funktion - macht Text groß und wichtig, wie ein Manager in einer E-Mail
title() {
  echo -e "\n${BOLD}${BLUE}═════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}${BLUE}  $1${NC}"
  echo -e "${BOLD}${BLUE}═════════════════════════════════════════════════${NC}\n"
}

# Trennlinie - für mehr Übersichtlichkeit
separator() {
  echo -e "\n${CYAN}───────────────────────────────────────────────────${NC}\n"
}

# Prüfen, ob das Skript als Root ausgeführt wird
# Root-Rechte sind wie Adminrechte in Windows - man braucht sie, um richtig Chaos anzurichten
check_root() {
  if [ "$EUID" -ne 0 ]; then
    log "ERROR" "Dieses Skript muss als Root ausgeführt werden! Sonst wird das nix, Kollege."
    log "INFO" "Versuch's mal mit 'sudo $0'"
    exit 1
  fi
}

# ===== Distributionserkennung =====

# Hier spielen wir Detektiv mit deinem Betriebssystem - "Elementary, my dear Linux!"
detect_distribution() {
  title "Distributionserkennung"
  log "INFO" "Schnüffle an deinem System... 🕵️"
  
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    VERSION=$VERSION_ID
    log "INFO" "Distribution: $PRETTY_NAME gefunden"
    
    case $DISTRO in
      "ubuntu"|"debian")
        log "INFO" "Ah, ein Debian-basiertes System! Die Toyota Corolla unter den Linux-Distros: zuverlässig, aber nicht fancy."
        PACKAGE_MANAGER="apt"
        ;;
      "arch"|"manjaro")
        log "INFO" "Oha, ein Arch-basiertes System! Du musst auf Parties erzählen, dass du Arch benutzt, oder?"
        PACKAGE_MANAGER="pacman"
        ;;
      "fedora"|"rhel"|"centos"|"rocky"|"almalinux")
        log "INFO" "Ein RedHat-basiertes System! Enterprise-ready, wie man so schön sagt (bedeutet: kompliziert)."
        PACKAGE_MANAGER="dnf"
        ;;
      "opensuse"*|"sles")
        log "INFO" "OpenSUSE oder SLES gefunden. Das grüne Chamäleon ist noch am Leben!"
        PACKAGE_MANAGER="zypper"
        ;;
      *)
        log "WARN" "Exotische Distribution $DISTRO gefunden. Ich versuche mein Bestes, aber keine Garantie!"
        if command -v apt &>/dev/null; then
          PACKAGE_MANAGER="apt"
        elif command -v dnf &>/dev/null; then
          PACKAGE_MANAGER="dnf"
        elif command -v yum &>/dev/null; then
          PACKAGE_MANAGER="yum"
        elif command -v pacman &>/dev/null; then
          PACKAGE_MANAGER="pacman"
        elif command -v zypper &>/dev/null; then
          PACKAGE_MANAGER="zypper"
        else
          log "ERROR" "Konnte keinen bekannten Paketmanager finden. Dein System ist zu hipster für mich!"
          exit 1
        fi
        ;;
    esac
  else
    log "ERROR" "Konnte die Distribution nicht erkennen. Ist das überhaupt Linux? 🤔"
    exit 1
  fi
}

# ===== Docker Installation =====

# Prüft, ob systemd verfügbar ist
has_systemd() {
  if command -v systemctl &>/dev/null && [ -d /run/systemd/system ]; then
    return 0  # systemd ist verfügbar
  else
    return 1  # systemd ist nicht verfügbar
  fi
}

# Prüft, ob Docker installiert ist
is_docker_installed() {
  if command -v docker &>/dev/null; then
    return 0  # Docker ist installiert
  else
    return 1  # Docker ist nicht installiert
  fi
}

# Startet Docker ohne systemd
start_docker_without_systemd() {
  log "INFO" "Starte Docker ohne systemd..."
  
  # Prüfen, ob dockerd bereits läuft
  if pgrep -x "dockerd" > /dev/null; then
    log "INFO" "Docker-Daemon läuft bereits."
    return 0
  fi
  
  # Docker-Daemon im Hintergrund starten
  if [ -x /usr/bin/dockerd ]; then
    nohup /usr/bin/dockerd > /var/log/dockerd.log 2>&1 &
    sleep 2  # Kurz warten, damit Docker starten kann
    if pgrep -x "dockerd" > /dev/null; then
      log "INFO" "Docker-Daemon erfolgreich gestartet."
      return 0
    fi
  elif [ -x /usr/bin/docker-daemon ]; then
    nohup /usr/bin/docker-daemon > /var/log/dockerd.log 2>&1 &
    sleep 2
    if pgrep -x "docker-daemon" > /dev/null; then
      log "INFO" "Docker-Daemon erfolgreich gestartet."
      return 0
    fi
  fi
  
  log "ERROR" "Konnte Docker-Daemon nicht starten."
  return 1
}

# Installiert Docker - wie ein Umzug, nur dass Container einziehen statt Möbel
install_docker() {
  title "Docker Installation"
  log "INFO" "Bereite Docker-Installation vor. Lass die Container-Party beginnen! 🐳"
  
  case $PACKAGE_MANAGER in
    "apt")
      install_docker_debian
      ;;
    "pacman")
      install_docker_arch
      ;;
    "dnf"|"yum")
      install_docker_redhat
      ;;
    "zypper")
      install_docker_suse
      ;;
    *)
      log "ERROR" "Unsupported package manager: $PACKAGE_MANAGER"
      exit 1
      ;;
  esac
  
  # Prüfen, ob Docker installiert wurde
  if ! is_docker_installed; then
    log "ERROR" "Docker wurde nicht korrekt installiert. Überprüfe die Installationsschritte."
    exit 1
  fi
  
  # Docker-Dienst starten
  log "INFO" "Starte Docker-Dienst. Brumm brumm! 🚗"
  
  DOCKER_STARTED=false
  
  # Versuchen, Docker mit systemd zu starten, falls verfügbar
  if has_systemd; then
    log "INFO" "Systemd erkannt, versuche Docker als Systemdienst zu starten..."
    if systemctl start docker 2>/dev/null; then
      systemctl enable docker 2>/dev/null
      if systemctl is-active --quiet docker; then
        log "INFO" "Docker-Dienst läuft. Die Container-Fabrik ist einsatzbereit!"
        DOCKER_STARTED=true
      else
        log "WARN" "Docker-Dienst konnte nicht mit systemd gestartet werden. Versuche alternative Methode..."
      fi
    else
      log "WARN" "Docker-Dienst konnte nicht mit systemd gestartet werden. Versuche alternative Methode..."
    fi
  else
    log "INFO" "Systemd nicht erkannt, verwende alternative Startmethode..."
  fi
  
  # Wenn Docker nicht mit systemd gestartet werden konnte, alternative Methode verwenden
  if [ "$DOCKER_STARTED" = false ]; then
    if start_docker_without_systemd; then
      DOCKER_STARTED=true
      
      # Autostart-Eintrag für Docker erstellen
      if [ -d /etc/init.d ]; then
        log "INFO" "Erstelle Autostart-Eintrag für Docker..."
        cat > /etc/init.d/docker << 'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:           docker
# Required-Start:     $network $remote_fs $syslog
# Required-Stop:      $network $remote_fs $syslog
# Default-Start:      2 3 4 5
# Default-Stop:       0 1 6
# Short-Description:  Docker Application Container Engine
### END INIT INFO

start() {
    if ! pgrep -x "dockerd" > /dev/null; then
        nohup /usr/bin/dockerd > /var/log/dockerd.log 2>&1 &
    fi
}

stop() {
    if pgrep -x "dockerd" > /dev/null; then
        pkill -x "dockerd"
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
EOF
        chmod +x /etc/init.d/docker
        if command -v update-rc.d &>/dev/null; then
          update-rc.d docker defaults
        elif command -v chkconfig &>/dev/null; then
          chkconfig --add docker
        fi
      fi
    else
      log "ERROR" "Docker-Dienst konnte nicht gestartet werden. Das ist so traurig, Alexa spiel Despacito."
      log "WARN" "Du kannst versuchen, Docker manuell zu starten mit: 'dockerd &'"
      log "WARN" "Die Installation wird fortgesetzt, aber einige Funktionen könnten nicht verfügbar sein."
    fi
  fi
  
  # Benutzer zur Docker-Gruppe hinzufügen
  log "INFO" "Füge aktuellen Benutzer zur Docker-Gruppe hinzu - quasi der VIP-Bereich des Systems, nur ohne Champagner."
  if [ -n "$SUDO_USER" ]; then
    usermod -aG docker $SUDO_USER
    log "INFO" "Benutzer $SUDO_USER zur Docker-Gruppe hinzugefügt."
    log "INFO" "Bitte melde dich ab und wieder an, damit die Gruppenänderungen wirksam werden."
  else
    log "WARN" "Konnte den Benutzer nicht zur Docker-Gruppe hinzufügen. Du musst vielleicht 'sudo' vor Docker-Befehlen verwenden."
  fi
}

# Debian/Ubuntu Installation - der Klassiker unter den Distributionen
install_docker_debian() {
  log "INFO" "Installiere Docker auf Debian/Ubuntu. Apt-get ist wie Online-Shopping für Nerds."
  separator
  
  # Alte Versionen entfernen (falls vorhanden)
  run_with_spinner "Entferne alte Docker-Versionen..." "apt-get remove -y docker docker-engine docker.io containerd runc"
  
  # Abhängigkeiten installieren
  run_with_spinner "Aktualisiere Paketlisten..." "apt-get update"
  run_with_spinner "Installiere Abhängigkeiten..." "apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release"
  
  # Docker-Repository hinzufügen
  log "INFO" "Füge Docker-Repository hinzu. Frische Software direkt vom Hersteller!"
  mkdir -p /etc/apt/keyrings
  run_with_spinner "Lade Docker GPG-Schlüssel..." "curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg"
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DISTRO $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  # Docker installieren
  run_with_spinner "Aktualisiere Paketlisten..." "apt-get update"
  run_with_spinner "Installiere Docker Engine und Docker Compose..." "apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin"
  
  log "INFO" "Docker wurde erfolgreich auf deinem Debian/Ubuntu-System installiert. Glückwunsch, du bist jetzt ein Container-Kapitän! 🚢"
}

# Arch Linux Installation - für die, die gerne am Bleeding Edge leben
install_docker_arch() {
  log "INFO" "Installiere Docker auf Arch Linux. Bleeding edge, wie ein Samurai-Schwert!"
  separator
  
  # Docker installieren
  run_with_spinner "Aktualisiere System..." "pacman -Syu --noconfirm"
  run_with_spinner "Installiere Docker..." "pacman -S --noconfirm docker docker-compose"
  
  log "INFO" "Docker wurde erfolgreich auf deinem Arch-System installiert. Du kannst jetzt bei Arch-Nutzertreffen angeben!"
}

# RedHat Installation - Enterprise-ready, wie man so schön sagt
install_docker_redhat() {
  log "INFO" "Installiere Docker auf RedHat/Fedora. Enterprise-Grade Container, yay!"
  separator
  
  # Abhängigkeiten installieren
  run_with_spinner "Installiere Abhängigkeiten..." "$PACKAGE_MANAGER install -y dnf-plugins-core"
  
  # Docker-Repository hinzufügen
  run_with_spinner "Füge Docker-Repository hinzu..." "$PACKAGE_MANAGER config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo"
  
  # Docker installieren
  run_with_spinner "Installiere Docker..." "$PACKAGE_MANAGER install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin"
  
  log "INFO" "Docker wurde erfolgreich auf deinem RedHat-System installiert. Jetzt bist du enterprise-ready!"
}

# SUSE Installation - das grüne Chamäleon unter den Distributionen
install_docker_suse() {
  log "INFO" "Installiere Docker auf SUSE. Das grüne Chamäleon trifft auf den blauen Wal!"
  separator
  
  # Repository hinzufügen und Docker installieren
  run_with_spinner "Füge Docker-Repository hinzu..." "zypper addrepo https://download.docker.com/linux/sles/docker-ce.repo"
  run_with_spinner "Aktualisiere Repositories..." "zypper refresh"
  run_with_spinner "Installiere Docker..." "zypper install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin"
  
  log "INFO" "Docker wurde erfolgreich auf deinem SUSE-System installiert. Grün und Blau - eine schöne Kombination!"
}

# ===== Docker Management Tools =====

# Installiert Docker Management Tools - weil niemand gerne mit der Kommandozeile arbeitet, wenn es auch GUIs gibt
install_management_tools() {
  title "Docker Management Tools"
  log "INFO" "Zeit für ein paar schicke Management-Tools! Weil CLIs so 1990 sind..."
  
  # Temporäres Verzeichnis für Docker Compose Dateien
  DOCKER_DIR="/opt/docker-management"
  mkdir -p $DOCKER_DIR
  
  # Menü für Tool-Auswahl anzeigen
  echo -e "${CYAN}Wähle die Docker Management Tools, die du installieren möchtest:${NC}"
  echo -e "${YELLOW}1) Portainer${NC} - Umfassendes Web-UI für Docker-Management"
  echo -e "${YELLOW}2) Dockge${NC} - Modernes UI für Docker Compose Stack-Management"
  echo -e "${YELLOW}3) Yacht${NC} - Leichtgewichtiges Web-UI für Docker-Management"
  echo -e "${YELLOW}4) Alle installieren${NC}"
  echo -e "${YELLOW}5) Keines installieren${NC}"
  
  read -p "Deine Wahl (1-5): " choice
  
  case $choice in
    1)
      install_portainer
      ;;
    2)
      install_dockge
      ;;
    3)
      install_yacht
      ;;
    4)
      install_portainer
      install_dockge
      install_yacht
      ;;
    5)
      log "INFO" "Keine Management-Tools ausgewählt. Du bist wohl ein CLI-Purist!"
      ;;
    *)
      log "WARN" "Ungültige Auswahl. Keine Management-Tools werden installiert."
      ;;
  esac
}

# Portainer - der Klassiker unter den Docker UIs
install_portainer() {
  log "INFO" "Installiere Portainer - das Schweizer Taschenmesser für Docker-Management."
  separator
  
  mkdir -p $DOCKER_DIR/portainer
  cat > $DOCKER_DIR/portainer/docker-compose.yml << EOF
version: '3'
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: always
    security_opt:
      - no-new-privileges:true
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - portainer_data:/data
    ports:
      - 9000:9000
volumes:
  portainer_data:
EOF
  
  run_with_spinner "Starte Portainer..." "cd $DOCKER_DIR/portainer && docker compose up -d"
  
  if [ $? -eq 0 ]; then
    log "INFO" "Portainer erfolgreich installiert und läuft auf Port 9000."
    PORTAINER_INSTALLED=true
  else
    log "ERROR" "Portainer-Installation fehlgeschlagen. Schade, das wäre ein schönes UI gewesen."
  fi
}

# Dockge - der Neue im Block
install_dockge() {
  log "INFO" "Installiere Dockge - weil 'Docker Compose' zu einfach auszusprechen war."
  separator
  
  mkdir -p $DOCKER_DIR/dockge
  cat > $DOCKER_DIR/dockge/docker-compose.yml << EOF
version: '3'
services:
  dockge:
    image: louislam/dockge:latest
    container_name: dockge
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - dockge_data:/app/data
      - /opt/stacks:/opt/stacks
    ports:
      - 5001:5001
    environment:
      - DOCKGE_STACKS_DIR=/opt/stacks
volumes:
  dockge_data:
EOF
  
  # Stacks-Verzeichnis erstellen
  mkdir -p /opt/stacks
  
  run_with_spinner "Starte Dockge..." "cd $DOCKER_DIR/dockge && docker compose up -d"
  
  if [ $? -eq 0 ]; then
    log "INFO" "Dockge erfolgreich installiert und läuft auf Port 5001."
    DOCKGE_INSTALLED=true
  else
    log "ERROR" "Dockge-Installation fehlgeschlagen. Vielleicht beim nächsten Mal."
  fi
}

# Yacht - der Leichtgewichtige
install_yacht() {
  log "INFO" "Installiere Yacht - für alle, die auf einer Yacht leben möchten, aber nur für ein Ruderboot Budget haben."
  separator
  
  mkdir -p $DOCKER_DIR/yacht
  cat > $DOCKER_DIR/yacht/docker-compose.yml << EOF
version: '3'
services:
  yacht:
    image: selfhostedpro/yacht:latest
    container_name: yacht
    restart: always
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - yacht_data:/config
    ports:
      - 8000:8000
volumes:
  yacht_data:
EOF
  
  run_with_spinner "Starte Yacht..." "cd $DOCKER_DIR/yacht && docker compose up -d"
  
  if [ $? -eq 0 ]; then
    log "INFO" "Yacht erfolgreich installiert und läuft auf Port 8000."
    YACHT_INSTALLED=true
  else
    log "ERROR" "Yacht-Installation fehlgeschlagen. Kein Segeln heute."
  fi
}

# ===== Abschluss und Informationsausgabe =====

# Zeigt Informationen nach der Installation an
show_completion_info() {
  title "Installation abgeschlossen"
  
  # IP-Adresse ermitteln - komplizierter als man denkt!
  IP_ADDRESS=$(hostname -I | awk '{print $1}')
  if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)
    if [ -z "$IP_ADDRESS" ]; then
      IP_ADDRESS="localhost"
      log "WARN" "Konnte IP-Adresse nicht ermitteln. Verwende 'localhost' stattdessen."
    fi
  fi
  
  separator
  
  echo -e "${BOLD}${GREEN}╔═════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${GREEN}║             INSTALLATION ERFOLGREICH!            ║${NC}"
  echo -e "${BOLD}${GREEN}╚═════════════════════════════════════════════════╝${NC}\n"
  
  log "INFO" "Docker wurde erfolgreich installiert! 🎉"
  log "INFO" "Docker Version: $(docker --version)"
  log "INFO" "Docker Compose Version: $(docker compose version)"
  
  separator
  
  echo -e "${BOLD}${MAGENTA}╔═════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${MAGENTA}║            INSTALLIERTE MANAGEMENT-TOOLS        ║${NC}"
  echo -e "${BOLD}${MAGENTA}╚═════════════════════════════════════════════════╝${NC}\n"
  
  if [ "$PORTAINER_INSTALLED" = true ]; then
    echo -e "${BOLD}${CYAN}Portainer:${NC}"
    echo -e "  URL:      ${GREEN}http://$IP_ADDRESS:9000${NC}"
    echo -e "  Login:    Benutzername und Passwort bei erstem Login festlegen"
    echo
  fi
  
  if [ "$DOCKGE_INSTALLED" = true ]; then
    echo -e "${BOLD}${CYAN}Dockge:${NC}"
    echo -e "  URL:      ${GREEN}http://$IP_ADDRESS:5001${NC}"
    echo -e "  Login:    Benutzername und Passwort bei erstem Login festlegen"
    echo
  fi
  
  if [ "$YACHT_INSTALLED" = true ]; then
    echo -e "${BOLD}${CYAN}Yacht:${NC}"
    echo -e "  URL:      ${GREEN}http://$IP_ADDRESS:8000${NC}"
    echo -e "  Login:    admin@yacht.local / pass"
    echo -e "  Hinweis:  Bitte ändere das Passwort sofort nach dem ersten Login!"
    echo
  fi
  
  separator
  
  echo -e "${BOLD}${BLUE}╔═════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${BLUE}║              NÜTZLICHE DOCKER-BEFEHLE            ║${NC}"
  echo -e "${BOLD}${BLUE}╚═════════════════════════════════════════════════╝${NC}\n"
  
  echo -e "${YELLOW}docker ps${NC}                   # Zeigt laufende Container"
  echo -e "${YELLOW}docker images${NC}               # Zeigt heruntergeladene Images"
  echo -e "${YELLOW}docker compose up -d${NC}        # Startet Container im Hintergrund"
  echo -e "${YELLOW}docker compose down${NC}         # Stoppt und entfernt Container"
  echo -e "${YELLOW}docker system prune${NC}         # Räumt ungenutzte Ressourcen auf"
  
  separator
  
  echo -e "${BOLD}${YELLOW}WICHTIGER HINWEIS:${NC}"
  echo -e "Bitte melde dich ab und wieder an, damit die Docker-Gruppenänderungen wirksam werden."
  echo -e "\n${BOLD}${GREEN}Viel Spaß mit deinen Containern! 🐳${NC}"
}

# ===== Hauptfunktion =====

main() {
  # ASCII-Art, weil wir fancy sind
  echo -e "${BLUE}"
  echo -e "╔═══════════════════════════════════════════════════════════╗"
  echo -e "║                                                           ║"
  echo -e "║   ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗        ║"
  echo -e "║   ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗       ║"
  echo -e "║   ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝       ║"
  echo -e "║   ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗       ║"
  echo -e "║   ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║       ║"
  echo -e "║   ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝       ║"
  echo -e "║                                                           ║"
  echo -e "║   Installations-Skript                                    ║"
  echo -e "║   https://github.com/staubi82/docker-install              ║"
  echo -e "║                                                           ║"
  echo -e "╚═══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  
  # Root-Check
  check_root
  
  # Distributionserkennung
  detect_distribution
  
  # Docker installieren
  install_docker
  
  # Fortschrittsbalken für die Show
  log "INFO" "Docker-Installation abgeschlossen. Bereite Management-Tools vor..."
  echo -ne "${YELLOW}Verarbeite... ${NC}"
  progress_bar 3
  
  # Management-Tools installieren
  install_management_tools
  
  # Abschlussinformationen anzeigen
  show_completion_info
}

# Los geht's!
main
