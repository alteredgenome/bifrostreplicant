#!/bin/bash

# --- Color Config ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${CYAN}=== Bifrost Replicant: TARGET (Receiver) ===${NC}"

# --- 1. OS Detection & Dependency Installation ---
# We need to detect OS early to know how to restart SSH later
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
    else
        echo "Could not detect OS. Assuming generic Linux."
        OS_ID="unknown"
    fi
}

install_deps() {
    echo -e "${GREEN}Detecting OS and installing dependencies (curl, rsync)...${NC}"
    detect_os
    case $OS_ID in
        debian|ubuntu|kali|raspbian)
            apt-get update && apt-get install -y curl rsync openssh-server
            ;;
        centos|rhel|fedora|almalinux|rocky)
            dnf install -y curl rsync openssh-server || yum install -y curl rsync openssh-server
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm curl rsync openssh
            ;;
        alpine)
            apk add curl rsync openssh
            ;;
        *)
            echo "Unsupported OS family: $OS_ID. Please install curl and rsync manually."
            exit 1
            ;;
    esac
}

if ! command -v curl &> /dev/null || ! command -v rsync &> /dev/null; then
    install_deps
else
    detect_os # Ensure we still know the OS ID
fi

# --- 2. Install Malai ---
if ! command -v malai &> /dev/null; then
    echo -e "${GREEN}Installing Malai...${NC}"
    curl -fsSL https://malai.sh/install.sh | sh
fi

# --- 3. Generate Key ---
echo -e "${GREEN}Generating Bifrost identity file...${NC}"
malai keygen --file

# --- 4. Enable Root SSH (NEW) ---
echo -e "${CYAN}Configuring SSH to allow Root Login...${NC}"

SSH_CONFIG="/etc/ssh/sshd_config"

if [ -f "$SSH_CONFIG" ]; then
    # Backup config just in case
    cp "$SSH_CONFIG" "${SSH_CONFIG}.bifrost.bak"

    # 1. Enable PermitRootLogin
    # Check if the setting exists (commented or not) and replace it, or append if missing
    if grep -q "^#*PermitRootLogin" "$SSH_CONFIG"; then
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' "$SSH_CONFIG"
    else
        echo "PermitRootLogin yes" >> "$SSH_CONFIG"
    fi

    # 2. Enable PasswordAuthentication (Safety net if keys aren't set up)
    if grep -q "^#*PasswordAuthentication" "$SSH_CONFIG"; then
        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' "$SSH_CONFIG"
    else
        echo "PasswordAuthentication yes" >> "$SSH_CONFIG"
    fi

    echo -e "${GREEN}SSH Config updated. Restarting SSH service...${NC}"

    # Restart SSH based on OS
    case $OS_ID in
        debian|ubuntu|kali|raspbian)
            service ssh restart 2>/dev/null || systemctl restart ssh
            ;;
        centos|rhel|fedora|almalinux|rocky|arch|manjaro)
            systemctl restart sshd
            ;;
        alpine)
            rc-service sshd restart
            ;;
        *)
            echo -e "${YELLOW}Could not determine how to restart SSH. Please restart it manually!${NC}"
            ;;
    esac
else
    echo -e "${YELLOW}Warning: $SSH_CONFIG not found. Skipping SSH configuration.${NC}"
fi

# --- 5. Open the Bridge ---
echo -e "${CYAN}-------------------------------------------------------${NC}"
echo -e "${CYAN}Bifrost Target Open.${NC}"
echo -e "${GREEN}COPY THE ID BELOW (e.g., kulfi://...).${NC}"
echo -e "Paste this ID into the Source script."
echo -e "Keep this terminal OPEN until the transfer is finished."
echo -e "${CYAN}-------------------------------------------------------${NC}"

# Expose local SSH port (22) to the Malai network
malai tcp 22 --public
