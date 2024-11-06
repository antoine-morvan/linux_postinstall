#!/usr/bin/env bash
set -eu -o pipefail

[ "$(whoami)" != root ] && echo "[NETCONF] ERROR: must run as root" && exit 1

# source config
[ -f config.sh ] && source config.sh
SUDOUSER=${SUDOUSER:-"admin"}

set +e
cat /etc/passwd | grep ^${SUDOUSER}: &> /dev/null
RES=$?
set -e
[ $RES == 0 ] && echo "[NETCONF] WARNING: user '${SUDOUSER}' already exists in '/etc/passwd'." && exit 0

echo "[NETCONF] INFO: Creating user '${SUDOUSER}' with password '${SUDOUSER}'"

useradd \
    -d /home/${SUDOUSER} \
    -U \
    -s /bin/bash  \
    -m \
    ${SUDOUSER}
echo -en "${SUDOUSER}\n${SUDOUSER}\n" | passwd ${SUDOUSER} &> /dev/null

exit 0
