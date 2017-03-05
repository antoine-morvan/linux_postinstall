#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Truecrypt"
echo ""


PACKS="truecrypt"

NAME=notesalexp
if [ ! -e /etc/apt/source.list.d/$NAME.list ]; then
	REPO="deb http://notesalexp.org/debian/jessie/ jessie main"
	add_repo "$NAME" "$REPO" "http://notesalexp.org/debian/alexp_key.asc"
fi

update
upgrade
install_packs $PACKS
