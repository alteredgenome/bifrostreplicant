#!/bin/bash

# --- Color Config ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Malai Destination Setup ===${NC}"

# --- 1. OS Detection & Dependency Installation ---
install_deps() {
    echo -e "${GREEN}Detecting OS and installing dependencies (curl, rsync)...${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            debian|ubuntu|kali|raspbian)
                apt-get update && apt-get install -y curl rsync
                ;;
            centos|rhel|fedora|almalinux|rocky)
                dnf install -y curl rsync || yum install -y curl rsync
                ;;
            arch|manjaro)
                pacman -Sy --noconfirm curl rsync
                ;;
            alpine)
                apk add curl rsync
                ;;
            *)
                echo "Unsupported OS family: $ID. Please install curl and rsync manually."
                exit 1
                ;;
        esac
    else
        echo "Could not detect OS. Please install curl and rsync manually."
        exit 1
    fi
}

# Check if tools exist, if not install them
if ! command -v curl &> /dev/null || ! command -v rsync &> /dev/null; then
    install_deps
else
    echo "Dependencies already installed."
fi

# --- 2. Install Malai ---
if ! command -v malai &> /dev/null; then
    echo -e "${GREEN}Installing Malai...${NC}"
    curl -fsSL https://malai.sh/install.sh | sh
else
    echo "Malai is already installed."
fi

# --- 3. Generate Key (File Based) ---
echo -e "${GREEN}Generating Malai identity file...${NC}"
malai keygen --file

# --- 4. Expose SSH and Wait ---
echo -e "${CYAN}-------------------------------------------------------${NC}"
echo -e "${CYAN}Starting Malai Tunnel.${NC}"
echo -e "${GREEN}COPY THE ID BELOW (e.g., kulfi://...).${NC}"
echo -e "You will need to paste this into the Source script."
echo -e "Keep this terminal OPEN until the rsync is finished."
echo -e "${CYAN}-------------------------------------------------------${NC}"

# This command will block (wait) automatically
malai tcp 22 --public
