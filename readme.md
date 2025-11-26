
# TheBifro.st

**Bifrost Replicant** is a powerful server synchronization tool designed to clone any two Linux servers across the globe. By leveraging the **[Malai](https://malai.sh)** P2P tunneling network and the robustness of **rsync**, this tool allows you to create an exact duplicate of a source server onto a target server, regardless of firewalls, NATs, or geographic location.

> **Warning**: This tool performs a full system synchronization. **All data on the Target server will be overwritten** to match the Source server. Ensure you have backups before proceeding.

## Features

-   **Global Sync**: Sync servers anywhere in the world without complex port forwarding or VPNs.
    
-   **Secure Tunneling**: Uses `malai.sh` to establish a secure, ephemeral peer-to-peer connection.
    
-   **Exact Replication**: Utilizes `rsync` to ensure the target filesystem becomes an identical mirror of the source.
    
-   **Simple Execution**: One-line commands for both source and target environments.
    

## Prerequisites

Before running the scripts, ensure the following:

1.  **Root Access**: You must have root privileges (or ability to `sudo`) on both servers.
    
2.  **Matching OS**: The Source and Target servers must be running the **same Linux distribution and version** (e.g., both Ubuntu 22.04) to avoid kernel/library incompatibilities.
    
3.  **Internet Access**: Both servers need outbound internet access to fetch the scripts and establish the tunnel.
    

## Usage Instructions

### Step 1: Prepare the Target Server

On the server you wish to **copy to** (the destination/target), run the following command as root:

    curl -sL https://thebifro.st/target | bash

**What this does:**

-   Installs necessary dependencies (including `malai` and `rsync`).
    
-   Sets up a secure tunnel endpoint.
    
-   **Output**: It will display a unique **Connection ID** or **Token**. Keep this terminal open and copy the ID/Token provided.
    

### Step 2: Prepare the Source Server and Sync to the Target

On the server you wish to **copy from** (the source), run the following command as root:

    curl -sL https://thebifro.st/source | bash

**What this does:**

-   Installs necessary dependencies.
    
-   Connects to the target server via the Malai tunnel.
    
-   Initiates the `rsync` process to push all data to the target.
    
-   Replicates the file system, permissions, and configurations.
    

## How It Works

1.  **Tunneling**: The `target` script initializes a **Malai** node, creating a direct P2P tunnel that bypasses traditional network barriers. This exposes the necessary synchronization ports securely.
    
2.  **Synchronization**: The `source` script connects to this tunnel and triggers `rsync`.
    
3.  **Replication**: Data is transferred compressed and encrypted. The target system's files are updated to match the source, deleting extraneous files on the target to ensure a 1:1 clone.
    

## Troubleshooting

-   **Connection Failed**: Ensure both servers allow outbound traffic. If `malai` cannot establish a connection, check if a strict firewall is blocking P2P traffic.
    
-   **Rsync Errors**: If the sync fails halfway, simply re-run the `source` script. Rsync is resumable and will only transfer missing data.
    
-   **Boot Issues**: If the Target server fails to boot after sync, ensure that the `/etc/fstab` and bootloader configurations (GRUB) on the Source were generic enough to handle the Target's hardware (UUIDs for disks may need manual adjustment if hardware differs significantly).
    

## Source Code

The full source code for Bifrost Replicant allows for auditing and modification.

-   **GitHub Repository**: [https://github.com/alteredgenome/bifrostreplicant/](https://github.com/alteredgenome/bifrostreplicant/)
----------

_Created by AlteredGenome._
