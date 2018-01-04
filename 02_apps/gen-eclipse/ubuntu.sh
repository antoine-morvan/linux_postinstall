#!/bin/bash -eu

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

upgrade
install_packs openjdk-8-jdk openjdk-8-source

mkdir -p /usr/local/bin/
retry "wget -q -O /usr/local/bin/gen-eclipse ${SETUP_SCRIPT_LOCATION}/02_apps/gen-eclipse/gen-eclipse-caller"
chmod +x /usr/local/bin/gen-eclipse

exit 0
