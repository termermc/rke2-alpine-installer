# rke2-alpine-installer

An installer script for RKE2 on Alpine Linux

The installer attempts to enable CGroups v2, then download and install RKE2. It
will create an OpenRC service named `rke2-server` and enable it.

The script must be run as root. Run it with no arguments to see its usage.
