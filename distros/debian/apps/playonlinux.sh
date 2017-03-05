#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Play on Linux"
echo ""

PACKS="playonlinux"

NAME=playonlinux
if [ ! -e /etc/apt/source.list.d/$NAME.list ]; then
	REPO="deb http://deb.playonlinux.com/ wheezy main"
	add_repo "$NAME" "$REPO" "http://deb.playonlinux.com/public.gpg"
fi

update
upgrade
install_packs $PACKS

exit
