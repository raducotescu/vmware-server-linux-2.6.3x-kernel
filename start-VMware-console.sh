#!/bin/bash
################################################################################
# Call VMWare Server's Remote Console in a clean GTK setup.                    #
# Author: Holger                                                               #
# URL: http://shellack.de/info/content/vmware-server-20-console-failure        #
################################################################################

# Clean GTK setup for VMWare
export VMWARE_USE_SHIPPED_GTK=yes

# Find console executable in Firefox plugins.
vmrc="$(find "$HOME/.mozilla/firefox" -name vmware-vmrc -type f -perm -111 | tail -1)"
[ -x "$vmrc" ] || exit 1

set -x
cd "$(dirname "$vmrc")" && "$vmrc" -h 127.0.0.1:8333

