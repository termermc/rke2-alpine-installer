#!/bin/sh

which rke2
if [ ! "$?" = 0 ]; then
	echo "It appears that RKE2 is not installed."
	exit 1
fi

set -e

DEF_INSTALL_PREFIX="/usr/local"

if [ "$INSTALL_PREFIX" = "" ]; then
	echo "Missing INSTALL_PREFIX. Using default: $DEF_INSTALL_PREFIX"
	echo "If you're OK with this, press enter. Otherwise, press CTRL+C."
	read
	INSTALL_PREFIX="$DEF_INSTALL_PREFIX"
fi

if [ ! "$( id -u )" = 0 ]; then
	echo "This script requires root."
	exit 1
fi

if [ -f /sys/fs/cgroup/cgroup.stat ]; then
	echo "cgroups v2 appears to be enabled on this system."
	echo "We will NOT disable it automatically. If you want to disable it, run: rc-update del cgroups"
fi

echo "Stopping services..."
rc-service rke2-server stop 2>/dev/null || true
rc-service rke2-agent stop 2>/dev/null || true
rc-update del rke2-server default 2>/dev/null || true
rc-update del rke2-agent default 2>/dev/null || true

echo "Giving it a few seconds to shut down..."
sleep 5

echo "Unmounting kubelet-related mounts..."
mount | awk '$3 ~ /^\/var\/lib\/kubelet\/pods\// {print $3}' | sort -r | while read -r m; do
  umount -f "$m"
done
umount -l /var/lib/kubelet 2>/dev/null || true
umount -f -R /var/lib/kubelet 2>/dev/null || true

echo "Removing services..."
rm -f /etc/init.d/rke2-server
rm -f /etc/init.d/rke2-agent

echo "Deleting RKE2 files..."
rm -f "${INSTALL_PREFIX}/bin/rke2"
rm -f "${INSTALL_PREFIX}/bin/rke2-killall.sh"
rm -f "${INSTALL_PREFIX}/bin/rke2-uninstall.sh"
rm -rf "${INSTALL_PREFIX}/share/rke2"

rm -rf /etc/rancher/rke2
rm -rf /etc/rancher/node
rm -rf /etc/cni
rm -rf /opt/cni/bin
rm -rf /var/lib/cni
rm -rf /var/log/pods
rm -rf /var/log/containers
rm -rf /var/log/calico
rm -rf /var/lib/kubelet
rm -rf /var/lib/rancher/rke2
