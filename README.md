# Docker Installations-Skript

Ein universelles Bash-Skript zur Installation von Docker und Docker Compose auf verschiedenen Linux-Distributionen mit optionalen Management-Tools.

![Docker Logo](https://www.docker.com/sites/default/files/d8/2019-07/Moby-logo.png)

## Funktionen

- **Universelle Kompatibilität**: Unterstützt Debian/Ubuntu, Arch Linux, RHEL/Fedora und SUSE
- **Docker & Docker Compose**: Installiert die neuesten Versionen
- **Management-Tools**: Optionale Installation von Portainer, Dockge und Yacht
- **Benutzerfreundlich**: Farbige Ausgabe und Fortschrittsbalken
- **Automatische Konfiguration**: Fügt Benutzer zur Docker-Gruppe hinzu

## Installation

Führe einfach den folgenden Befehl aus:

```bash
curl -fsSL https://raw.githubusercontent.com/staubi82/docker-install/main/docker-install.sh | sudo bash
```

oder

```bash
wget -O- https://raw.githubusercontent.com/staubi82/docker-install/main/docker-install.sh | sudo bash
```

## Management-Tools

Das Skript bietet die Möglichkeit, folgende Docker-Management-Tools zu installieren:

- **Portainer** (Port 9000): Umfassendes Web-UI für Docker-Management
- **Dockge** (Port 5001): Modernes UI für Docker Compose Stack-Management
- **Yacht** (Port 8000): Leichtgewichtiges Web-UI für Docker-Management

## Unterstützte Distributionen

- Debian/Ubuntu
- Arch Linux/Manjaro
- RHEL/Fedora/CentOS/Rocky/AlmaLinux
- OpenSUSE/SLES

## Hinweise

- Das Skript muss mit Root-Rechten ausgeführt werden
- Nach der Installation musst du dich ab- und wieder anmelden, damit die Docker-Gruppenänderungen wirksam werden
- Die Management-Tools sind über den Browser unter http://IP-ADRESSE:PORT erreichbar

## Lizenz

MIT

## Autor

[staubi82](https://github.com/staubi82)
