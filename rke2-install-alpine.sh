#!/bin/sh

which rke2
if [ "$?" = 0 ]; then
	echo "It appears that RKE2 is already installed. Press enter to continue, or press CTRL+C to cancel."
	read
fi

set -e

if [ "$RKE2_VERSION" = "" ]; then
	echo "Missing RKE2_VERSION environment variable. Please set it before running this script. Example: v1.36.3+rke2r1 (get it from the GitHub releases: https://github.com/rancher/rke2/releases)"
	exit 1
fi
if [ "$RKE2_ARCH" = "" ]; then
	echo "Missing RKE2_ARCH environment variable. Please set it before running this script. Example: amd64"
	exit 1
fi

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

if [ ! -f /sys/fs/cgroup/cgroup.stat ]; then
	echo "cgroups v2 are not enabled on this system."
	echo "We will now enable and start the cgroups service."
	rc-update add cgroups sysinit
	rc-service cgroups start
	mount

	if [ ! -f /sys/fs/cgroup/cgroup.stat ]; then
		echo "It seems like enabling the cgroups service did not work."
		echo "Try rebooting."
		exit 1
	fi

	echo "cgroups are enabled!"
fi

TMP_DIR="/tmp/rke2-install"

rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

echo "Downloading to ${TMP_DIR}..."
wget "https://github.com/rancher/rke2/releases/download/${RKE2_VERSION}/rke2.linux-${RKE2_ARCH}.tar.gz"
wget "https://github.com/rancher/rke2/releases/download/${RKE2_VERSION}/sha256sum-${RKE2_ARCH}.txt"

echo "Verifying..."
grep "rke2.linux-${RKE2_ARCH}.tar.gz" "sha256sum-${RKE2_ARCH}.txt" | sha256sum -c -

echo "Installing to ${INSTALL_PREFIX}..."
tar xzf "rke2.linux-${RKE2_ARCH}.tar.gz" -C "$INSTALL_PREFIX"

echo "Adding to PATH in ~/.profile..."
EXPORT_LINE="export PATH=\"$INSTALL_PREFIX/bin:$PATH\""
echo "$EXPORT_LINE" >> ~/.profile

mksvc() {
	local SVC_MODE="$1"
	local SVC_PATH="/etc/init.d/rke2-$SVC_MODE"

	echo "Creating service rke2-$SVC_MODE..."

	printf "#!/sbin/openrc-run\n\n: \"\${INSTALL_PREFIX:=$INSTALL_PREFIX}\"\n: \"\${SVC_MODE:=$SVC_MODE}\"\n\n" > "$SVC_PATH"

	cat >> "$SVC_PATH" <<'EOF'

name="rke2-$SVC_MODE"
description="RKE2 Kubernetes $SVC_MODE"
command="${INSTALL_PREFIX}/bin/rke2"
command_args="$SVC_MODE"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/${RC_SVCNAME}.log"
error_log="/var/log/${RC_SVCNAME}.log"

depend() {
    need net
}

start_pre() {
	modprobe br_netfilter
	modprobe overlay
}

# OpenRC's rc_cgroup_cleanup setting doesn't work properly.
# I don't know why. OpenRC sucks.
# We have to do it ourselves.
stop_pre() {
	local cg="/sys/fs/cgroup/openrc.${RC_SVCNAME}"
	local i

	pkill kube
	pkill flannel
	pkill pause
	pkill etcd
	pkill traefik
	pkill coredns
	pkill calico
	pkill runsv

	ebegin "Stopping ${RC_SVCNAME}"

	printf '1' > "${cg}/cgroup.kill"

	for i in 1 2 3 4 5; do
		[ ! -s "${cg}/cgroup.procs" ] && break
		sleep 1
	done

	find "${cg}" -depth -type d 2>/dev/null | while read -r d; do
		rmdir "$d" 2>/dev/null || true
	done

	rmdir "$cg"

	mount | awk '$3 ~ /^\/var\/lib\/kubelet\/pods\// {print $3}' | sort -r | while read -r m; do
		umount -f "$m"
	done
	umount -l /var/lib/kubelet 2>/dev/null || true
	umount -f -R /var/lib/kubelet 2>/dev/null || true

	eend 0
}
EOF

	chmod +x "$SVC_PATH"
}

mksvc server
mksvc agent

echo "RKE2 is installed."
echo "To add rke2 to your PATH for this session: $EXPORT_LINE"
