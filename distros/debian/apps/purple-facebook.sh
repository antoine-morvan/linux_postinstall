#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Setup Purple Facebook"
echo ""

PACKS="purple-facebook"

NAME=jgeboski
REPO="deb http://download.opensuse.org/repositories/home:/jgeboski/Debian_8.0 ./"
SIGNINGKEY="https://jgeboski.github.io/obs.key"
add_repo "$NAME" "$REPO" "$SIGNINGKEY"

update
upgrade
install_packs "$PACKS"
