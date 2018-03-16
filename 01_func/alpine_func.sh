#!/bin/ash -eu

# retry the given command until it succeed.
# $1 : a command as string
function retry {
	[ "$LOGCNT" == "" ] && export LOGCNT=0
	LOGCNT=$((LOGCNT+1))
	LOGFILE="retry_mainlog_$LOGCNT.log"
	MSG="Error executing '$1', logging in '$LOGFILE'. Retrying in 5s."
	$1 >> $LOGFILE 2>> $LOGFILE
	while [ "$?" != "0" ]; do
		echo $MSG
		sleep 5
    LOGCNT=$((LOGCNT+1))
		LOGFILE="retry_mainlog_$LOGCNT.log"
		MSG="Error executing '$1', logging in '$LOGFILE'. Retrying in 5s."
		$1 >> $LOGFILE 2>> $LOGFILE
	done
}

function pause {
	if [ "$ENABLE_PAUSE" == "YES" ]; then
		read -p " [ Press Enter ] ... $@"
	else
		echo " [ Pause skiped ] ... $@"
	fi
}

function upgrade {
	echo "   Upgrade"
  apk update
  apk upgrade
}
function install_packs {
	PACKS=$@
	echo "   Installing packages [$PACKS]"
	[ "$PACKS" == "" ] && echo "Warning : package list is empty" && return
	if [ "$ENABLE_PAUSE" == "YES" ]; then
		for package in $PACKS; do
			#pause "pacman --noconfirm -S $package"
			retry "apk add $package"
		done
	else 
		retry "apk add $PACKS"
	fi
}

function dl_and_execute {
	SCRIPT_LOCATION=$1
	SCRIPT_FILE=`mktemp --suffix=.sh`
	pause "dl and execute $1 with arguments ${@:2}"
	retry "wget --no-cache -q -O ${SCRIPT_FILE} ${SCRIPT_LOCATION}"
	chmod +x ${SCRIPT_FILE}
	${SCRIPT_FILE} ${@:2}
	rm ${SCRIPT_FILE}
}
