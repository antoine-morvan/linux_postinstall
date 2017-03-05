#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Wine"
echo ""

#wine1.7
PACKS=" winetricks mpg123 libopenal1 libwine-openal"

NAME=liquorix
if [ ! -e /etc/apt/source.list.d/$NAME.list ]; then
	REPO="deb http://liquorix.net/debian sid main\ndeb-src http://liquorix.net/debian sid main"
	add_repo "$NAME" "$REPO"
	update
	add_unauth_keyring "liquorix-keyring"
fi

update
upgrade
install_packs "$PACKS"

exit


winecfg

(cd ~/.wine && winetricks d3dx9 vcrun2008 corefonts tahoma directplay directmusic l3codecx dsound winxp sound=alsa videomemorysize=2048 ddr=opengl)
