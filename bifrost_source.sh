#!/bin/bash

# --- Color Config ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

EXCLUDE_FILE="/tmp/bifrost-exclude.txt"
LOCAL_PORT="2222"

# --- SSH Options Wrapper ---
# We force SSH to ignore known_hosts to prevent "Remote Host Identification Changed" errors
# since we are tunneling different servers over the same local port (2222).
SSH_OPTS="-p $LOCAL_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# --- Cleanup Trap ---
cleanup() {
    if [ -n "$BRIDGE_PID" ]; then
        echo -e "\n${CYAN}Closing Bifrost bridge (PID: $BRIDGE_PID)...${NC}"
        kill $BRIDGE_PID 2>/dev/null
    fi
}
trap cleanup EXIT

echo -e "${CYAN}=== Bifrost Replicant: SOURCE (Sender) ===${NC}"

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
echo -e "${GREEN}Generating Bifrost identity file...${NC}"
malai keygen --file

# --- 4. Connect to Bridge ---
echo -e "${CYAN}Enter the Bifrost Target ID (from the other server):${NC}"
read -r REMOTE_ID < /dev/tty

echo -e "${GREEN}Establishing bridge to $REMOTE_ID on port $LOCAL_PORT...${NC}"
malai tcp-bridge "$REMOTE_ID" "$LOCAL_PORT" &
BRIDGE_PID=$!

echo "Waiting for tunnel to stabilize..."
sleep 5

if ! ps -p $BRIDGE_PID > /dev/null; then
    echo -e "${RED}Error: Bifrost bridge failed to start. Check the ID and try again.${NC}"
    exit 1
fi

# --- 5. OS Compatibility Check ---
echo -e "${CYAN}Checking Source and Target compatibility...${NC}"

# Get Local OS Info
source /etc/os-release
LOCAL_ID=$ID
LOCAL_VERSION=$VERSION_ID
LOCAL_PRETTY=$PRETTY_NAME

# Get Remote OS Info via Tunnel using SSH_OPTS
REMOTE_OS_DATA=$(ssh $SSH_OPTS -o ConnectTimeout=10 root@localhost "cat /etc/os-release" 2>/dev/null)

if [ -z "$REMOTE_OS_DATA" ]; then
    echo -e "${RED}CRITICAL WARNING: Could not read remote OS data!${NC}"
    echo "The target might not be Linux, or SSH failed."
    REMOTE_ID="unknown"
else
    REMOTE_ID=$(echo "$REMOTE_OS_DATA" | grep "^ID=" | cut -d'=' -f2 | tr -d '"')
    REMOTE_VERSION=$(echo "$REMOTE_OS_DATA" | grep "^VERSION_ID=" | cut -d'=' -f2 | tr -d '"')
    REMOTE_PRETTY=$(echo "$REMOTE_OS_DATA" | grep "^PRETTY_NAME=" | cut -d'=' -f2 | tr -d '"')
fi

echo -e "------------------------------------------------"
echo -e "SOURCE OS: ${GREEN}$LOCAL_PRETTY${NC} ($LOCAL_ID $LOCAL_VERSION)"
echo -e "TARGET OS: ${GREEN}$REMOTE_PRETTY${NC} ($REMOTE_ID $REMOTE_VERSION)"
echo -e "------------------------------------------------"

# Logic: Check for mismatch
if [ "$LOCAL_ID" != "$REMOTE_ID" ]; then
    echo -e "${RED}!!! OS MISMATCH DETECTED !!!${NC}"
    echo -e "${YELLOW}You are attempting to clone $LOCAL_ID onto a $REMOTE_ID system.${NC}"
    echo -e "${YELLOW}This will likely result in a broken system unless you know exactly what you are doing.${NC}"
    echo -e "Type 'OVERWRITE' to proceed anyway, or anything else to cancel."
    read -p "> " confirmation < /dev/tty
    if [ "$confirmation" != "OVERWRITE" ]; then
        echo "Aborting operation safely."
        exit 1
    fi
elif [ "$LOCAL_VERSION" != "$REMOTE_VERSION" ]; then
     echo -e "${YELLOW}WARNING: Version mismatch detected ($LOCAL_VERSION vs $REMOTE_VERSION).${NC}"
     echo "This is usually fine (upgrade/downgrade), but proceed with caution."
     echo "Press ENTER to continue, or Ctrl+C to cancel."
     read -r < /dev/tty
else
    echo -e "${GREEN}OS Match Confirmed. Proceeding.${NC}"
fi

# --- 6. Create Exclude File ---
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
/etc/netplan/*
/etc/network/interfaces
EOF

# --- 7. Run Rsync (PUSH) ---
echo -e "${CYAN}Starting Bifrost Replication (PUSHING)...${NC}"
# We pass the SSH_OPTS inside the rsync -e command
sudo rsync -vPaAXH -e "ssh $SSH_OPTS" --exclude-from="$EXCLUDE_FILE" / root@localhost:/

RSYNC_STATUS=$?

if [ $RSYNC_STATUS -eq 0 ]; then
    echo -e "${GREEN}Replication completed successfully!${NC}"
else
    echo -e "${RED}Replication finished with errors (Exit Code: $RSYNC_STATUS).${NC}"
fi

# --- 8. Reboot Prompt ---
echo -e "${CYAN}-------------------------------------------------------${NC}"
read -p "Would you like to reboot the TARGET host now? (y/N): " choice < /dev/tty

case "$choice" in 
  y|Y ) 
    echo -e "${GREEN}Sending reboot command through tunnel...${NC}"
    # Using SSH_OPTS to bypass host key check
    ssh $SSH_OPTS root@localhost "reboot"
    echo "Reboot command sent to target."
    ;;
  * ) 
    echo -e "${GREEN}Skipping reboot. Goodbye!${NC}"
    ;;
esac
