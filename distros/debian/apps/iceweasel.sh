#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Iceweasel"
echo ""

PACKS="iceweasel iceweasel-l10n-fr xul-ext-adblock-plus xul-ext-flashblock xul-ext-noscript xul-ext-useragentswitcher flashplugin-nonfree"

NAME=mozilla
if [ ! -e /etc/apt/source.list.d/$NAME.list ]; then
	REPO="deb http://mozilla.debian.net/ jessie-backports iceweasel-release"
	add_repo "$NAME" "$REPO"
	update
	add_unauth_keyring "pkg-mozilla-archive-keyring"
fi

update
upgrade
install_packs "$PACKS"


