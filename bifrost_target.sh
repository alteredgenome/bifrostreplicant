#!/bin/bash

# --- Color Config ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== Bifrost Replicant: TARGET (Receiver) ===${NC}"

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

if ! command -v curl &> /dev/null || ! command -v rsync &> /dev/null; then
    install_deps
fi

# --- 2. Install Malai ---
if ! command -v malai &> /dev/null; then
    echo -e "${GREEN}Installing Malai...${NC}"
    curl -fsSL https://malai.sh/install.sh | sh
fi

# --- 3. Generate Key ---
echo -e "${GREEN}Generating Bifrost identity file...${NC}"
malai keygen --file

# --- 4. Open the Bridge ---
echo -e "${CYAN}-------------------------------------------------------${NC}"
echo -e "${CYAN}Bifrost Target Open.${NC}"
echo -e "${GREEN}COPY THE ID BELOW (e.g., kulfi://...).${NC}"
echo -e "Paste this ID into the Source script."
echo -e "Keep this terminal OPEN until the transfer is finished."
echo -e "${CYAN}-------------------------------------------------------${NC}"

# Expose local SSH port (22) to the Malai network
malai tcp 22 --public
