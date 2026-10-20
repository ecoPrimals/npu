#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# bind-vfio.sh — Bind the Akida AKD1000 NPU to vfio-pci
#
# Run as root (or via sudo). After binding, /dev/vfio/<group> is owned
# by eastgate via udev rule 99-akida-vfio.rules.
#
# Usage:
#   sudo ./bind-vfio.sh          # bind
#   sudo ./bind-vfio.sh unbind   # release
#
# The device is at 0000:08:00.0, IOMMU group 23.
# Vendor: 0x1e7c (Brainchip), Device: 0xbca1 (AKD1000).

set -euo pipefail

PCIE_ADDR="0000:08:00.0"
VENDOR="1e7c"
DEVICE="bca1"

status() {
    local driver
    driver=$(readlink "/sys/bus/pci/devices/${PCIE_ADDR}/driver" 2>/dev/null || true)
    driver=$(basename "${driver}" 2>/dev/null || echo "none")
    echo "PCIe:  ${PCIE_ADDR}"
    echo "Chip:  AKD1000 (Brainchip Akida V1)"
    echo "Driver: ${driver}"
    if [[ -e "/dev/vfio/23" ]]; then
        echo "VFIO:  /dev/vfio/23 ($(stat -c '%U:%G %a' /dev/vfio/23))"
    else
        echo "VFIO:  not present"
    fi
}

bind() {
    echo "── Binding ${PCIE_ADDR} to vfio-pci ──"

    modprobe vfio-pci

    # Unbind from current driver if any
    if [[ -e "/sys/bus/pci/devices/${PCIE_ADDR}/driver/unbind" ]]; then
        echo "${PCIE_ADDR}" > "/sys/bus/pci/devices/${PCIE_ADDR}/driver/unbind"
        echo "  unbound from previous driver"
    fi

    # Register vendor:device with vfio-pci
    echo "${VENDOR} ${DEVICE}" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true

    # Explicit bind (may already be bound from new_id)
    echo "${PCIE_ADDR}" > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true

    echo "── Done ──"
    status
}

unbind() {
    echo "── Unbinding ${PCIE_ADDR} from vfio-pci ──"

    if [[ -e "/sys/bus/pci/drivers/vfio-pci/unbind" ]]; then
        echo "${PCIE_ADDR}" > /sys/bus/pci/drivers/vfio-pci/unbind 2>/dev/null || true
        echo "  unbound"
    fi

    echo "── Done ──"
    status
}

case "${1:-bind}" in
    bind)   bind ;;
    unbind) unbind ;;
    status) status ;;
    *)      echo "Usage: $0 [bind|unbind|status]"; exit 1 ;;
esac
