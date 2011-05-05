#!/bin/bash
###############################################################################
# @author Radu Cotescu                                                        #
# @version 1.6                                                                #
#                                                                             #
# For further details visit:                                                  #
# http://radu.cotescu.com/?p=1095                                             #
#                                                                             #
# This script will help you install VMWare Server 2.0.x on Linux systems      #
# based on Ubuntu, Fedora, openSuSE or SuSE running kernels 2.6.31, 2.6.32,   #
# 2.6.35 and 2.6.38.                                                          #
#                                                                             #
# Based on a script from http://communities.vmware.com/thread/215985          #
#                                                                             #
# This script must be run with super-user privileges.                         #
# Usage:                                                                      #
# ./vmware-server-2.0.x-kernel-2.6.3x-install.sh [PATH TO VMWARE ARCHIVE]     #
# If you do not specify the PATH the script will scan the current folder for  #
# VMware server archive and if doesn't find anything it will exit.            #
###############################################################################

SCRIPT_NAME=`basename $0`
DIR_NAME=`dirname $0`
VMWARE_HOME=$1
PATCH="vmware-server-2.0.2-203138-update.patch"
CONFIG_PATCH="vmware-config.patch"
KERNEL=`uname -r`

display_usage() {
	echo "This script must be run with super-user privileges."
	echo -e "\nUsage:\n./$SCRIPT_NAME [PATH TO VMWARE ARCHIVE]\n"
	echo "If you do not specify the PATH the script will scan the current folder"
	echo "for VMware server archive and if doesn't find anything it will exit."
	echo "Please make sure that PATH doesn't contain any spaces."
}

check_usage() {
	if [ ! $params -le 1 ]
	then
		display_usage
		exit 1
	fi
	if [[ ($param == "--help") ||  $param == "-h" ]]
	then
		display_usage
		exit 0
	fi
}

check_user() {
	if [[ $USER != "root" ]]; then
		echo "This script must be run as root!"
		exit 1
	fi
}

set_workspace() {
	if [[ -z $VMWARE_HOME ]]; then
		VMWARE_HOME="`pwd`"
	fi
	case $VMWARE_HOME in
		*\ *)
			echo "The path you indicated contains spaces. Please adjust your path accordingly."
			display_usage
			exit 1
		;;
	esac
	VMWARE_ARCHIVE=`ls "$VMWARE_HOME" 2> /dev/null | egrep "^(VMware-server-2.0.[0-9]-)[0-9]*.[A-Za-z0-9_]*.tar.gz"`
	MODULES_DIR="$VMWARE_HOME/vmware-server-distrib/lib/modules"
	MODULES_SOURCE="$MODULES_DIR/source"
}

check_archive() {
	if [[ -z $VMWARE_ARCHIVE ]]; then
		echo -e "There is no archive containing VMware Server in the path you indicated!\n"
		exit 1
	else
		echo -e "You have VMware Server archive: \n\t$VMWARE_ARCHIVE"
	fi
}

check_distro() {
	ubuntu=`cat /etc/*-release | grep Ubuntu`
	fedora=`cat /etc/*-release | grep Fedora`
	suse=`cat /etc/*-release | grep SUSE`
	if [[ ! -z $ubuntu ]] ; then
		distro="ubuntu"
	elif [[ ! -z $fedora ]] ; then
		distro="fedora"
	elif [[ ! -z $suse ]] ; then
		distro="suse"
	fi
}

packageError() {
	if [[ $1 -ne 0 ]]; then
		echo "I am unable to install the before mentioned package..."
		echo "Please install the required package and rerun the script..."
		exit 1
	fi
}

resolveDepsUbuntu() {
	echo "Checking for needed packages on Ubuntu"
	LINUX_HEADERS="linux-headers-`uname -r`"
	check_headers=`dpkg-query -W -f='${Status} ${Version}\n' $LINUX_HEADERS 2> /dev/null | egrep "^install"`
	if [[ -z $check_headers ]]; then
		echo "Installing linux-headers-`uname -r` package..."
		apt-get -y install linux-headers-`uname -r`
		packageError $?
	else echo "You do have the $LINUX_HEADERS package..."
	fi
	check_build=`dpkg-query -W -f='${Status} ${Version}\n' build-essential 2> /dev/null | egrep "^install"`
	if [[ -z $check_build ]]; then
		echo "Installing build-essential package..."
		apt-get -y install build-essential
		packageError $?
	else echo "You do have the build-essential package..."
	fi
	check_patch=`dpkg-query -W -f='${Status} ${Version}\n' "patch" 2> /dev/null | egrep "^install"`
	if [[ -z $check_patch ]]; then
		echo "Installing patch package..."
		apt-get -y install patch
		packageError $?
	else echo "You do have the patch package..."
	fi
}

resolveDepsFedora() {
	echo "Checking for needed packages on Fedora"
	if [[ -z `rpm -qa xinetd` ]]; then
                echo "Installing xinetd..."
                yum -y install xinetd
                packageError $?
        else echo "You do have the xinetd package..."
	fi
	if [[ -z `rpm -qa kernel-headers` ]]; then
		echo "Installing kernel-headers..."
		yum -y install kernel-headers
		packageError $?
	else echo "You do have the kernel-headers package..."
	fi
	if [[ -z `rpm -qa kernel-devel` ]]; then
		echo "Installing kernel-devel..."
		yum -y install kernel-devel
		packageError $?
	else echo "You do have the kernel-devel package..."
	fi
	if [[ -z `rpm -qa gcc` ]]; then
		echo "Installing gcc..."
		yum -y install gcc
		packageError $?
	else echo "You do have the gcc package..."
	fi
	if [[ -z `rpm -qa patch` ]]; then
		echo "Installing patch..."
		yum -y install patch
		packageError $?
	else echo "You do have the patch package..."
	fi
	if [[ -z `rpm -qa make` ]]; then
		echo "Installing make..."
		yum -y install make
		packageError $?
	else echo "You do have the make package..."
	fi
}

resolveDepsSuse() {
	echo "Checking for needed packages on SUSE"
	if [[ -z `rpm -qa linux-kernel-headers` ]]; then
		echo "Installing linux-kernel-headers..."
		zypper --non-interactive install linux-kernel-headers
		packageError $?
	else echo "You do have the linux-kernel-headers package..."
	fi
	if [[ -z `rpm -qa kernel-source` ]]; then
		echo "Installing kernel-source..."
		zypper --non-interactive install kernel-source
		packageError $?
	else echo "You do have the kernel-source package..."
	fi
	if [[ -z `rpm -qa kernel-syms` ]]; then
		echo "Installing kernel-syms..."
		zypper --non-interactive install kernel-syms
		packageError $?
	else echo "You do have the kernel-syms package..."
	fi
	if [[ -z `rpm -qa gcc` ]]; then
		echo "Installing gcc..."
		zypper --non-interactive install gcc
		packageError $?
	else echo "You do have the gcc package..."
	fi
	if [[ -z `rpm -qa patch` ]]; then
		echo "Installing patch..."
		zypper --non-interactive install patch
		packageError $?
	else echo "You do have the patch package..."
	fi
	if [[ -z `rpm -qa make` ]]; then
		echo "Installing make..."
		zypper --non-interactive install make
		packageError $?
	else echo "You do have the make package..."
	fi
}

install() {
	case $distro in
		"ubuntu")
		resolveDepsUbuntu
		;;

		"fedora")
		resolveDepsFedora
		;;

		"suse")
		resolveDepsSuse
	esac
	if [[ ! -e "$VMWARE_HOME/vmware-server-distrib" ]]; then
		echo Extracting the contents of $VMWARE_ARCHIVE
		tar zxf "$VMWARE_HOME/$VMWARE_ARCHIVE" -C "$VMWARE_HOME"
	fi
	if [ ! -r "$DIR_NAME/$PATCH" ]; then
		echo "File $DIR_NAME/$PATCH is missing!"
		echo "Did you delete it?"
		exit 1
	fi
	if [ ! -r "$DIR_NAME/$CONFIG_PATCH" ]; then
		echo "File $DIR_NAME/$CONFIG_PATCH is missing!"
		echo "Did you delete it?"
		exit 1
	fi
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
	patch --dry-run -N -p1 --directory="$VMWARE_HOME/vmware-server-distrib" -s < "$DIR_NAME/$PATCH"
	RESULT=$?
	if [ "0" != "$RESULT" ]; then
		echo "The patch cannot be applied. :("
		exit 1
	fi
	echo "Creating some simlinks for the newer kernels..."
	ln -s /usr/src/linux-headers-`uname -r`/include/generated/autoconf.h /usr/src/linux-headers-`uname -r`/include/linux/autoconf.h
	ln -s /usr/src/linux-headers-`uname -r`/include/generated/utsrelease.h /usr/src/linux-headers-`uname -r`/include/linux/utsrelease.h
	echo "Applying patch..."
	patch -N -p1 --directory="$VMWARE_HOME/vmware-server-distrib" -s < "$DIR_NAME/$PATCH"
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
	# Skip checking vmppuser and vsock modules (they don't compile and are not
	# critical)
	if [[ "vmppuser" != "$BASE" && "vsock" != "$BASE" ]]; then
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
	echo "Patching vmware-install.pl..."
	patch "$VMWARE_HOME/vmware-server-distrib/bin/vmware-config.pl" "$DIR_NAME/$CONFIG_PATCH"
	echo "Starting VMware Server original install script..."
	$VMWARE_HOME/vmware-server-distrib/vmware-install.pl
}

clean() {
	echo "Housekeeping..."
	rm -rf $VMWARE_HOME/vmware-server-distrib
	echo "Thank you for using the script!"
	echo -e "Patch provided by: \n\tRamon de Carvalho Valle"
	echo -e "\thttp://risesecurity.org"
	echo -e "\tupdated by sirusdv (http://ubuntuforums.org/member.php?u=1289848)"
	echo -e "Script author: \n\tRadu Cotescu"
	echo -e "\thttp://radu.cotescu.com"
}
params=$#
param=$1
check_usage params param
check_user
set_workspace
check_archive
check_distro
install

if [[ $distro == "fedora" ]]; then
	echo "On Fedora you must follow these steps in order to make VMware Server to work properly:"
	echo -e "\t1. edit /etc/services and replace the entry located on TCP/902 port with vmware-authd"
	echo -e "\t2. disable SELinux by editing the /etc/selinux/config file"
	echo -e "\t3. reboot your system"
fi

clean
exit 0

