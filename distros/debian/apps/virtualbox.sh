#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup VirtualBox"
echo ""


NAME=virtualbox
PACKS=virtualbox-5.0
REPO="deb http://download.virtualbox.org/virtualbox/debian jessie contrib"
SIGNINGKEY="https://www.virtualbox.org/download/oracle_vbox.asc"

add_repo "$NAME" "$REPO" "$SIGNINGKEY"

update
upgrade
install_packs $PACKS
