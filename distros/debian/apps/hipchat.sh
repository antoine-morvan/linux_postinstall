#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup hipchat"
echo ""


PACKS="hipchat"

NAME=hipchat
REPO="deb http://downloads.hipchat.com/linux/apt stable main"
SIGNINGKEY="https://www.hipchat.com/keys/hipchat-linux.key"
add_repo "$NAME" "$REPO" "$SIGNINGKEY"

update
upgrade
install_packs "$PACKS"
