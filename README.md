# rke2-alpine-installer

An installer script for RKE2 on Alpine Linux.

The installer attempts to enable CGroups v2, then download and install RKE2.

It creates two OpenRC services:
 - `rke2-server`
 - `rke2-agent`

The script must be run as root. Run it with no arguments to see its usage.

Unlike the official installer, this installer does not detect the latest version or your architecture.
Use the `RKE2_VERSION` and `RKE2_ARCH` environment variables to set these values when running the script.

## Uninstall

This script does not delete the uninstall script provided by RKE2, but you should not run it because it assumes the existence of SystemD.

To uninstall, run [rke2-uninstall-alpine.sh] instead. It's recommended to stop the server/agent first because sometimes things are still unmounting.

## Alpine Problems

RKE2 dropped OpenRC support a few years ago, and Alpine is a lot slimmer than the distros it officially supports, so there are some issues you will encounter.

### CNI Problems

Calico CNI does not work out of the box because BPF isn't enabled by default on Alpine.

I personally prefer Flannel because it works nicely with IPv6 and doesn't require any special kernel modules.

### CGroup Problems

The official RKE2 installer uses SystemD's CGroup integration to manage all processes spawned for the server/agent.

OpenRC has CGroup support, but I ran into issues where it wouldn't actually stop all processes. I did my best to replicate the SystemD CGroup functionality
in the OpenRC service's stop function, but it may not be perfect and you may need to manually stop some things yourself.
