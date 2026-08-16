#!/bin/sh

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
	echo "We will enable them by writing to: /etc/conf.d/cgroups.conf"
	echo 'rc_cgroup_mode="unified"' > /etc/conf.d/cgroups.conf
	echo "We will now enable the cgroups service."
	rc-update add cgroups boot
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

echo "Creating service rke2-server..."
cat > /etc/init.d/rke2-server <<'EOF'
#!/sbin/openrc-run

name="rke2-server"
description="RKE2 Kubernetes Server"

command="
EOF

printf "$INSTALL_PREFIX" >> /etc/init.d/rke2-server

cat >> /etc/init.d/rke2-server << 'EOF'
/bin/rke2"
command_args="server"
command_background="yes"
pidfile="/run/${RC_SVCNAME}.pid"
output_log="/var/log/${RC_SVCNAME}.log"
error_log="/var/log/${RC_SVCNAME}.log"

depend() {
    need net
}
EOF

chmod +x /etc/init.d/rke2-server
rc-update add rke2-server default
rc-service rke2-server start

echo "RKE2 is installed and the service rke2-server is enabled and started."
echo "To add rke2 to your PATH for this session: $EXPORT_LINE"
echo "To monitor progress: tail -f /var/log/rke2-server.log"
