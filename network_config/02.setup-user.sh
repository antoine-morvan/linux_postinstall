#!/usr/bin/env bash
set -eu -o pipefail

[ "$(whoami)" != root ] && echo "[NETCONF] ERROR: must run as root" && exit 1

[ ! -f config.sh ] && echo "[NETCONF] ERROR: Could not locate 'config.sh'" && exit 1
source config.sh

set +e
cat /etc/passwd | grep ^${SUDOUSER}: &> /dev/null
RES=$?
set -e
[ $RES == 0 ] && echo "[NETCONF] WARNING: user '${SUDOUSER}' already exists in '/etc/passwd'." && exit 0
[ $RES != 0 ] && useradd \
    -d /home/${SUDOUSER} \
    -m \
    ${SUDOUSER}

exit 0
