#!/bin/bash

###############################################################################
# @author Radu Cotescu                                                        #
#                                                                             #
# For further details visit:                                                  #
#   http://radu.cotescu.com/?p=948                                            #
#                                                                             #
# This script will help you install VMWare Server 2.0.x on Ubuntu 9.10.       #
# Based on a script from http://communities.vmware.com/thread/215985          #
#                                                                             #
# This script must be run with super-user privileges.                         #
# Usage:                                                                      #
# ./vmware-server-2.0.x-kernel-2.6.31-14-install.sh [PATH TO VMWARE ARCHIVE]  #
# If you do not specify the PATH the script will scan the current folder for  #
# VMware server archive and if doesn't find anything it will exit.            #
###############################################################################

VMWARE_HOME=$1
PATCH="vmware-server-2.0.x_x64-modules-2.6.30.4-fix.patch"

display_usage() {
	errorMessage=$1
	if [[ ! -z $errorMessage ]]; then
		echo "Error message: $errorMessage"
	fi
	echo "This script must be run with super-user privileges."
	echo -e "Usage:\n./vmware-server-2.0.x-kernel-2.6.31-14-install.sh [PATH_TO_VMWARE_ARCHIVE]"
	echo "If you do not specify the PATH_TO_VMWARE_ARCHIVE the script will scan the current folder"
	echo "for VMware server archive and if doesn't find anything it will exit."
	echo "Take care so that the PATH_TO_VMWARE_ARCHIVE doesn't contain any spaces."
	exit 1
}

check_user() {
	if [[ $USER != "root" ]]; then
		display_usage "You do not seem to be root or to be in the sudo-ers list!"
	fi
}

set_workspace() {
	if [[ -z $VMWARE_HOME ]] ; then
		VMWARE_HOME="`pwd`"
	fi
	VMWARE_ARCHIVE=`ls "$VMWARE_HOME" 2> /dev/null | egrep "^(VMware-server-2.0.[0-9]-)[0-9]*.[A-Za-z0-9_]*.tar.gz"`
	MODULES_DIR="$VMWARE_HOME/vmware-server-distrib/lib/modules"
	MODULES_SOURCE="$MODULES_DIR/source"
}

check_archive() {
	if [[ -z $VMWARE_ARCHIVE ]]; then
		display_usage "There is no archive containing VMware Server in the path you indicated!"
	else
		echo -e "You have VMware Server archive: \n\t$VMWARE_ARCHIVE"
	fi
}

check_usage() {
	if [ ! $params -le 1 ]
	then
		display_usage "You have supplied more parameters than needed!"
	fi
	if [[ ($param == "--help") ||  $param == "-h" ]]
	then
		display_usage
	fi
	check_user
	path_spaces_check=`echo $VMWARE_HOME | grep " "`
	if [[ ! -z $path_spaces_check ]]
	then
		display_usage "The path where the VMware Server archive is located should not contain spaces in it!"
	fi
	check_archive
}

install() {
	LINUX_HEADERS="linux-headers-`uname -r`"
	check_headers=`dpkg-query -W -f='${Status} ${Version}\n' $LINUX_HEADERS 2> /dev/null | egrep "^install"`
	if [[ -z $check_headers ]]; then
		echo Installing linux-headers-`uname -r` package...
		apt-get -y install linux-headers-`uname -r`
	else echo "You do have the $LINUX_HEADERS package..."
	fi
	check_build=`dpkg-query -W -f='${Status} ${Version}\n' build-essential 2> /dev/null | egrep "^install"`
	if [[ -z $check_build ]]; then
		echo "Installing build-essential package..."
		apt-get -y install build-essential
	else echo "You do have the build-essential package..."
	fi
	check_patch=`dpkg-query -W -f='${Status} ${Version}\n' "patch" 2> /dev/null | egrep "^install"`
	if [[ -z $check_patch ]]; then
		echo "Installing patch package..."
		apt-get -y install patch
	else echo "You do have the patch package..."
	fi
	if [[ ! -e "$VMWARE_HOME/vmware-server-distrib" ]]; then
		echo "Extracting the contents of $VMWARE_ARCHIVE"
		tar zxf "$VMWARE_HOME/$VMWARE_ARCHIVE" -C "$VMWARE_HOME"
	fi
	echo "Checking patch existence..."
	if [ ! -r "$VMWARE_HOME/$PATCH" ]; then
        echo "Downloading patch file..."
	    wget http://codebin.cotescu.com/vmware/$PATCH -O "$VMWARE_HOME/$PATCH"
        if [ $? != 0 ]; then
    		echo "The download of $PATCH from http://codebin.cotescu.com/vmware/ failed!"
	    	echo "Check your internet connection. :("
	    	exit 1
        fi
	fi
    echo "Checking archives from the extracted folders..."
	TARS=`find "$MODULES_SOURCE" -maxdepth 1 -name '*.tar'`
	if [ ! "$TARS" ]; then
		echo ".tar files from $MODULES_SOURCE appear to be missing!"
		echo "Cannot continue process. :("
		exit 1
	fi
	BASES=""
	for TARFILE in $TARS
	do
		BASE=`basename "$TARFILE" | rev | cut -c5- | rev`
		BASES="$BASES $BASE"
		echo "Found .tar file for $BASE module"
	done
	echo "Extracting .tar files in order to apply the patch..."
	for BASE in $BASES
	do
		TARFILE="${BASE}.tar"
		MODDIR="${BASE}-only"
		echo "Untarring $MODULES_SOURCE/$TARFILE"
		tar -xf "$MODULES_SOURCE/$TARFILE" -C "$MODULES_SOURCE"
		if [ ! -d "$MODULES_SOURCE/$MODDIR" ]; then
			echo "$TARFILE tarball failed to extract in the directory $MODDIR. :("
			exit 1
		fi
	done
	echo "Testing patch..."
	patch --dry-run -N -p1 --directory="$MODULES_SOURCE" -s < "$VMWARE_HOME/$PATCH"
	RESULT=$?
	if [ "0" != "$RESULT" ]; then
		echo "The patch cannot be applied. :("
		exit 1
	fi
	echo "Applying patch..."
	patch -N -p1 --directory="$MODULES_SOURCE" -s < "$VMWARE_HOME/$PATCH"
	RESULT=$?
	if [ "0" != "$RESULT" ]; then
		echo "A problem occured with the patch while it was being applied. :("
		exit 1
	fi
	for BASE in $BASES
	do
		TEMPFILE="${BASE}-temp.tar"
		MODDIR="${BASE}-only"
		echo "Preparing new tar file for $BASE module"
		rm -f "$MODULES_SOURCE/$TEMPFILE"
		tar -cf "$MODULES_SOURCE/$TEMPFILE" -C "$MODULES_SOURCE" "$MODDIR"
	done
	echo "Checking that the compiling will succeed..."
	for BASE in $BASES
	do
	# Skip checking vmppuser module because it's badly broken dead code
	if [ "vmppuser" != "$BASE" ]; then
		MODDIR="${BASE}-only"
		echo "Trying to compile $BASE module to see if it works"
		echo "Performing make in $MODULES_SOURCE/$MODDIR"
		make -s -C "$MODULES_SOURCE/$MODDIR"
		RESULT=$?
		if [ "0" != "$RESULT" ]; then
			echo "There is a problem compiling the $BASE module after it was patched. :("
			exit 1
		fi
	fi
	done
	echo "Rebuilding tar files..."
	for BASE in $BASES
	do
		TEMPFILE="${BASE}-temp.tar"
		TARFILE="${BASE}.tar"
		OFILE="${BASE}.o"
		MODDIR="${BASE}-only"
		echo "Replacing original file $TARFILE with patched file..."
		rm -rf "$MODULES_SOURCE/$TARFILE" "$MODULES_SOURCE/$OFILE" "$MODULES_SOURCE/$MODDIR"
		mv -f "$MODULES_SOURCE/$TEMPFILE" "$MODULES_SOURCE/$TARFILE"
	done
	echo "Removing binaries directory..."
	rm -rf "$MODULES_DIR/binary"
	echo "Starting VMware Server original install script..."
	$VMWARE_HOME/vmware-server-distrib/vmware-install.pl
}

clean() {
	echo "Housekeeping..."
	rm -rf $VMWARE_HOME/vmware-server-distrib "$VMWARE_HOME/$PATCH"
	echo "Thank you for using the script!"
	echo "Author: Radu Cotescu"
	echo "http://radu.cotescu.com"
}


set_workspace
params=$#
param=$1
check_usage params param
install
clean
exit 0
