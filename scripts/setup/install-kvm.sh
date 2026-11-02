#!/bin/bash
# =============================================================================
# Script: Install KVM/libvirt on Ubuntu host (8GB RAM)
# Mục đích: Chuẩn bị host on-premise để chạy VM-A (guest) cho dự án
# Yêu cầu: Ubuntu 22.04, 8GB RAM, user có sudo
# =============================================================================

set -euo pipefail

echo "======================================================"
echo "Installing KVM/QEMU/libvirt on Ubuntu host"
echo "======================================================"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "ERROR: Do not run this script as root. Run as normal user with sudo privileges."
   exit 1
fi

# Check CPU virtualization support
echo "[1/6] Checking CPU virtualization support..."
if ! grep -E -q 'vmx|svm' /proc/cpuinfo; then
    echo "ERROR: CPU does not support hardware virtualization (VT-x/AMD-V)"
    echo "Enable it in BIOS/UEFI first."
    exit 1
fi
echo "✓ CPU supports virtualization"

# Install KVM packages
echo "[2/6] Installing KVM, QEMU, libvirt..."
sudo apt update
sudo apt install -y \
    qemu-kvm \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    virtinst \
    virt-manager \
    cpu-checker \
    cloud-image-utils \
    genisoimage

# Add user to libvirt and kvm groups
echo "[3/6] Adding user $USER to libvirt and kvm groups..."
sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER

# Enable and start libvirtd
echo "[4/6] Enabling and starting libvirtd service..."
sudo systemctl enable libvirtd
sudo systemctl start libvirtd

# Verify KVM installation
echo "[5/6] Verifying KVM installation..."
if ! kvm-ok &>/dev/null; then
    echo "WARNING: kvm-ok returned non-zero. Check virtualization support."
fi

# Configure default network
echo "[6/6] Checking default libvirt network..."
if ! virsh net-list --all | grep -q default; then
    echo "Creating default network..."
    virsh net-define /usr/share/libvirt/networks/default.xml
fi

if virsh net-list | grep -q "default.*inactive"; then
    echo "Starting default network..."
    virsh net-start default
    virsh net-autostart default
fi

echo ""
echo "======================================================"
echo "KVM/libvirt installation completed!"
echo "======================================================"
echo "Next steps:"
echo "  1. LOG OUT and LOG IN again (for group changes to take effect)"
echo "  2. Verify: virsh list --all"
echo "  3. Run create-vm-a.sh to create VM-A guest"
echo ""
echo "Estimated RAM usage:"
echo "  - Host OS + libvirt: ~1-2 GB"
echo "  - VM-A (guest):      ~2 GB"
echo "  - Docker containers: ~1.5 GB (nếu chạy Central trên host)"
echo "  - Available:         ~3-4 GB"
echo "======================================================"
