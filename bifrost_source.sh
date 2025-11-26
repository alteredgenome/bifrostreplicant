#!/bin/bash

# --- Color Config ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

EXCLUDE_FILE="/tmp/rsync-exclude.txt"
LOCAL_PORT="2222"

# --- Cleanup Trap ---
cleanup() {
    if [ -n "$BRIDGE_PID" ]; then
        echo -e "\n${CYAN}Closing Malai bridge (PID: $BRIDGE_PID)...${NC}"
        kill $BRIDGE_PID 2>/dev/null
    fi
}
trap cleanup EXIT

echo -e "${CYAN}=== Malai Source Migration Tool ===${NC}"

# --- 1. OS Detection & Dependency Installation ---
install_deps() {
    echo -e "${GREEN}Detecting OS and installing dependencies (curl, rsync, ssh)...${NC}"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            debian|ubuntu|kali|raspbian)
                apt-get update && apt-get install -y curl rsync openssh-client
                ;;
            centos|rhel|fedora|almalinux|rocky)
                dnf install -y curl rsync openssh-clients || yum install -y curl rsync openssh-clients
                ;;
            arch|manjaro)
                pacman -Sy --noconfirm curl rsync openssh
                ;;
            alpine)
                apk add curl rsync openssh
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
echo -e "${GREEN}Generating Malai identity file...${NC}"
malai keygen --file

# --- 4. Establish Bridge ---
echo -e "${CYAN}Enter the Malai Remote ID (from the destination server):${NC}"
read -r REMOTE_ID

echo -e "${GREEN}Establishing bridge to $REMOTE_ID on port $LOCAL_PORT...${NC}"
# Run bridge in background
malai tcp-bridge "$REMOTE_ID" "$LOCAL_PORT" &
BRIDGE_PID=$!

# Wait a few seconds for the connection to stabilize
echo "Waiting for tunnel to stabilize..."
sleep 5

if ! ps -p $BRIDGE_PID > /dev/null; then
    echo -e "${RED}Error: Malai bridge failed to start. Check the ID and try again.${NC}"
    exit 1
fi

# --- 5. Create Exclude File (UPDATED) ---
echo "Creating exclude list at $EXCLUDE_FILE..."
cat <<EOF > "$EXCLUDE_FILE"
/boot
/dev
/tmp
/sys
/proc
/backup
/etc/fstab
/etc/mtab
/etc/mdadm.conf
/etc/sysconfig/network*
EOF

# --- 6. Run Rsync ---
echo -e "${CYAN}Starting Rsync Operation...${NC}"
# Using sudo explicitly for rsync to ensure permissions are preserved
sudo rsync -vPaAXH -e "ssh -p $LOCAL_PORT -o StrictHostKeyChecking=no" --exclude-from="$EXCLUDE_FILE" / root@localhost:/

RSYNC_STATUS=$?

if [ $RSYNC_STATUS -eq 0 ]; then
    echo -e "${GREEN}Rsync completed successfully!${NC}"
else
    echo -e "${RED}Rsync finished with errors (Exit Code: $RSYNC_STATUS).${NC}"
fi

# --- 7. Reboot Prompt ---
echo -e "${CYAN}-------------------------------------------------------${NC}"
read -p "Would you like to reboot the REMOTE host now? (y/N): " choice

case "$choice" in 
  y|Y ) 
    echo -e "${GREEN}Sending reboot command through tunnel...${NC}"
    ssh -p "$LOCAL_PORT" -o StrictHostKeyChecking=no root@localhost "reboot"
    echo "Reboot command sent."
    ;;
  * ) 
    echo -e "${GREEN}Skipping reboot. Goodbye!${NC}"
    ;;
esac
