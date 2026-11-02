#!/bin/bash
# =============================================================================
# Script: Create VM-A guest on KVM (On-Premise Agent)
# Mục đích: Tạo VM Ubuntu 22.04 với 2GB RAM, 16GB disk để chạy Telegraf agent
# Yêu cầu: KVM/libvirt đã cài (chạy install-kvm.sh trước)
# =============================================================================

set -euo pipefail

VM_NAME="vm-a"
VM_RAM=2048      # MB
VM_VCPUS=2
VM_DISK_SIZE=16  # GB
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
STORAGE_POOL="default"

echo "======================================================"
echo "Creating VM-A (On-Premise Agent) on KVM"
echo "======================================================"

# Check if VM already exists
if virsh list --all | grep -q " $VM_NAME "; then
    echo "ERROR: VM '$VM_NAME' already exists."
    echo "To recreate, run: virsh destroy $VM_NAME && virsh undefine $VM_NAME --remove-all-storage"
    exit 1
fi

# Download Ubuntu cloud image
CACHE_DIR="$HOME/.cache/libvirt/images"
mkdir -p "$CACHE_DIR"
CLOUD_IMG="$CACHE_DIR/ubuntu-22.04-server-cloudimg-amd64.img"

if [[ ! -f "$CLOUD_IMG" ]]; then
    echo "[1/6] Downloading Ubuntu 22.04 cloud image..."
    wget -O "$CLOUD_IMG" "$IMAGE_URL"
else
    echo "[1/6] Using cached Ubuntu image: $CLOUD_IMG"
fi

# Create VM disk from cloud image
VM_DISK="/var/lib/libvirt/images/${VM_NAME}.qcow2"
echo "[2/6] Creating VM disk ($VM_DISK_SIZE GB)..."
sudo qemu-img create -f qcow2 -F qcow2 -b "$CLOUD_IMG" "$VM_DISK" ${VM_DISK_SIZE}G
sudo chown libvirt-qemu:kvm "$VM_DISK"

# Create cloud-init configuration
echo "[3/6] Creating cloud-init config..."
CLOUD_INIT_DIR="/tmp/${VM_NAME}-cloud-init"
mkdir -p "$CLOUD_INIT_DIR"

# Get SSH public key
if [[ ! -f ~/.ssh/id_rsa.pub ]]; then
    echo "ERROR: SSH public key not found at ~/.ssh/id_rsa.pub"
    echo "Generate one with: ssh-keygen -t rsa -b 4096"
    exit 1
fi

SSH_PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

# meta-data
cat > "$CLOUD_INIT_DIR/meta-data" <<EOF
instance-id: ${VM_NAME}
local-hostname: ${VM_NAME}
EOF

# user-data
cat > "$CLOUD_INIT_DIR/user-data" <<EOF
#cloud-config
hostname: ${VM_NAME}
fqdn: ${VM_NAME}.localdomain
manage_etc_hosts: true

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: users, admin
    home: /home/ubuntu
    shell: /bin/bash
    ssh_authorized_keys:
      - ${SSH_PUB_KEY}

# Update and install essentials
package_update: true
package_upgrade: false
packages:
  - qemu-guest-agent
  - curl
  - wget
  - net-tools

# Enable qemu-guest-agent
runcmd:
  - systemctl enable qemu-guest-agent
  - systemctl start qemu-guest-agent
EOF

# Generate cloud-init ISO
CLOUD_INIT_ISO="$CLOUD_INIT_DIR/cloud-init.iso"
echo "[4/6] Generating cloud-init ISO..."
genisoimage -output "$CLOUD_INIT_ISO" \
    -volid cidata -joliet -rock \
    "$CLOUD_INIT_DIR/user-data" "$CLOUD_INIT_DIR/meta-data"

sudo mv "$CLOUD_INIT_ISO" "/var/lib/libvirt/images/${VM_NAME}-cloud-init.iso"
sudo chown libvirt-qemu:kvm "/var/lib/libvirt/images/${VM_NAME}-cloud-init.iso"

# Create VM
echo "[5/6] Creating VM with virt-install..."
sudo virt-install \
    --name "$VM_NAME" \
    --ram "$VM_RAM" \
    --vcpus "$VM_VCPUS" \
    --disk path="$VM_DISK",format=qcow2,bus=virtio \
    --disk path="/var/lib/libvirt/images/${VM_NAME}-cloud-init.iso",device=cdrom \
    --os-variant ubuntu22.04 \
    --network network=default,model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --import \
    --noautoconsole

echo "[6/6] Waiting for VM to boot (30s)..."
sleep 30

# Get VM IP
VM_IP=$(virsh domifaddr "$VM_NAME" | grep -oP '(\d+\.){3}\d+' | head -1 || echo "")

echo ""
echo "======================================================"
echo "VM-A created successfully!"
echo "======================================================"
echo "VM Name:       $VM_NAME"
echo "RAM:           ${VM_RAM} MB"
echo "vCPUs:         $VM_VCPUS"
echo "Disk:          ${VM_DISK_SIZE} GB"
echo "IP Address:    ${VM_IP:-"Detecting... run 'virsh domifaddr $VM_NAME' in 1 min"}"
echo ""
echo "Connect:"
echo "  virsh console $VM_NAME       (serial console, Ctrl+] to exit)"
echo "  ssh ubuntu@${VM_IP}          (SSH, after IP detected)"
echo ""
echo "Management:"
echo "  virsh list --all             (list VMs)"
echo "  virsh start $VM_NAME         (start VM)"
echo "  virsh shutdown $VM_NAME      (graceful shutdown)"
echo "  virsh destroy $VM_NAME       (force stop)"
echo "  virsh undefine $VM_NAME --remove-all-storage  (delete VM)"
echo ""
echo "Next step: Run setup-agent.sh on VM-A to install Telegraf"
echo "======================================================"

# Cleanup temp files
rm -rf "$CLOUD_INIT_DIR"
