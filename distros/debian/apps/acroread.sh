#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Acrobat Reader"
echo ""


PACKS="acroread"

NAME=multimedia
if [ ! -e /etc/apt/source.list.d/$NAME.list ]; then
	REPO="deb http://www.deb-multimedia.org jessie main non-free"
	add_repo "$NAME" "$REPO"
	update
	add_unauth_keyring "deb-multimedia-keyring"
fi

update
upgrade
install_packs $PACKS


