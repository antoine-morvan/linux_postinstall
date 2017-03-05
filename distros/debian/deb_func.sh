#!/bin/bash

# retry the given command until it succeed.
# $1 : a command as string
function retry {
	[ "$LOGCNT" == "" ] && export LOGCNT=0
	let LOGCNT++
	LOGFILE="retry_mainlog_$LOGCNT.log"
	MSG="Error executing '$1', logging in '$LOGFILE'. Retrying in 5s."
	$1 >> $LOGFILE 2>> $LOGFILE
	while [ "$?" != "0" ]; do
		echo $MSG
		sleep 5
		let LOGCNT++
		LOGFILE="retry_mainlog_$LOGCNT.log"
		MSG="Error executing '$1', logging in '$LOGFILE'. Retrying in 5s."
		$1 >> $LOGFILE 2>> $LOGFILE
	done
}

function pause {
	[ "$ENABLE_PAUSE" == "YES" ] && read -p " [ Press Enter ] ... $@" || echo -n ""
}

# add a given key to apt registry
# $1 : an URL to some .asc key
function add_key {
	KEY=$1
	echo "   Adding key [$KEY]"
	[ "$KEY" == "" ] && echo "   Warning : Key is empty" && return
	retry "wget -q -O /tmp/key $KEY"
	echo "" > /tmp/keylog
	apt-key add /tmp/key >> /tmp/keylog 2>> /tmp/keylog
	RES=$?
	[ $RES != 0 ] && cat /tmp/keylog
	rm /tmp/key /tmp/keylog
	return $RES
}
function add_unauth_keyring {
	KEYS="$@"
	echo "   Installing keyring packages [$KEYS]"
	[ "$KEYS" == "" ] && echo "Warning : package list is empty" && return
	retry "apt-get -y -d -q --allow-unauthenticated install $KEYS"
	apt-get -q -y --allow-unauthenticated install $KEYS > /dev/null 2> /dev/null
}

function add_repo {
	NAME=$1
	LOCATION=$2
	KEY=$3
	echo "   Adding Repo [$NAME : $LOCATION]"
	[ "$NAME" == "" ] && echo "Warning : Name is empty" && return
	[ "$LOCATION" == "" ] && echo "Warning : Location is empty" && return
	REPOFILE=/etc/apt/sources.list.d/$NAME.list
	[ -e $REPOFILE ] && echo "Error : Repository file already exists [$REPOFILE]" && return 1
	echo -e "$LOCATION" > $REPOFILE
	[ "$KEY" != "" ] && add_key $KEY
	return 0
}

function update {
	echo "   Update"
	retry "apt-get -q -y update"
}

function upgrade {
	echo "   Upgrade"
	echo "     >> download"
	retry "apt-get -q -y -d upgrade"
	echo "     >> install"
	apt-get -q -y upgrade > /dev/null 2> /dev/null
	echo "     >> done"
}

function dist_upgrade {
	echo "   Dist-Upgrade"
	echo "     >> download"
	retry "apt-get -q -y -d dist-upgrade"
	echo "     >> install"
	apt-get -q -y dist-upgrade > /dev/null 2> /dev/null
	echo "     >> done"
}

function install_packs {
	PACKS=$@
	echo "   Installing packages [$PACKS]"
	[ "$PACKS" == "" ] && echo "Warning : package list is empty" && return
	echo "     >> download"
	retry "apt-get -y -d -q install $PACKS"
	echo "     >> install"
	apt-get -q -y install $PACKS > /dev/null 2> /dev/null
	echo "     >> done"
}

function dl_and_execute {
	SCRIPT_LOCATION=$1
	SCRIPT_FILE=`mktemp --suffix=.sh`
	retry "wget -q -O ${SCRIPT_FILE} $SCRIPT_LOCATION"
	chmod +x ${SCRIPT_FILE}
	${SCRIPT_FILE}
	rm ${SCRIPT_FILE}
}

