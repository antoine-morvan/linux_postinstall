#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Chromium"
echo ""

PACKS="chromium chromium-l10n chromium-inspector pepperflashplugin-nonfree"

update
upgrade
install_packs $PACKS
