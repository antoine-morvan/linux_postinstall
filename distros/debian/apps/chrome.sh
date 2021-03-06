#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Chrome"
echo ""


NAME=google-chrome
PACKS=google-chrome-stable
REPO="deb http://dl.google.com/linux/chrome/deb/ stable main"
SIGNINGKEY="https://dl-ssl.google.com/linux/linux_signing_key.pub"

add_repo "$NAME" "$REPO" "$SIGNINGKEY"

update
upgrade
install_packs $PACKS

[ -e /etc/apt/sources.list.d/$NAME.list ] && rm /etc/apt/sources.list.d/$NAME.list