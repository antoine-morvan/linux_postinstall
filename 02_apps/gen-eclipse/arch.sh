#!/bin/bash -eu
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

upgrade
install_packs openjdk8-src jdk8-openjdk

mkdir -p /usr/local/bin/
retry "wget -q -O /usr/local/bin/gen-eclipse ${SETUP_SCRIPT_LOCATION}/02_apps/gen-eclipse/gen-eclipse-caller"
chmod +x /usr/local/bin/gen-eclipse

exit 0
