#!/bin/bash -eu

echo "[CONKY] setup conky"

export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/

CONFFILE=/etc/conky/koubi_conky.conf
CONFDIR=`dirname $CONFFILE`
export LOGCNT=0

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

mkdir -p $CONFDIR
retry "wget $SETUP_SCRIPT_LOCATION/02_apps/conky/koubi_conky.conf -O $CONFFILE"
#retry "wget http://koub.org/files/linux/02_apps/conky/conky.conf -O $CONFFILE"

echo "[CONKY] * Config file downloaded"

#PARTS=`mount | grep -v /sys | grep -v /proc | grep -v /run | grep -v tmpfs | grep -v cdrom | grep ^/`
PARTS=`cat /etc/fstab | grep -v "^#" | grep -v cdrom | grep -v swap | grep -v "//" | grep -v "[ \t]bind" | grep -v "^$" | cut -d" " -f 2`
echo "[CONKY] * parts configured"
[ "$PARTS" == "" ] && PARTS=`cat /etc/fstab | grep -v "^#" | grep -v cdrom | grep -v swap | grep -v "//" | grep -v "[ \t]bind" | grep -v "^$" | cut -f 2`
echo "[CONKY] * parts configured (v2)"
DISKS=`fdisk -l 2> /dev/null | grep Dis | grep -v mapper | grep /dev | grep -v "/dev/loo" | cut -d" " -f 2 | colrm 9 | colrm 1 5 | sort`
echo "[CONKY] * disks configured"
PRINTCONKY=""

#####################
#######	LVM #########
#####################

echo "[CONKY] * Config LVM"

LVS=`lvscan | cut -d"'" -f2`
VGS=`vgs | tail -n +2 | colrm 1 2 | cut -d" " -f 1`
PRINTCONKY=""
NEWPARTS=""

if [ "$LVS" != "" ]; then
	while read -r VG; do
		PRINTCONKY+="\${color grey}LVM Group \${color}$VG\${color grey} :\$color\n"
		I=0
		while read -r LV; do
			DMP=`ls -l $LV | cut -d">" -f 2`
			for PART in $PARTS; do
				MOUNTLINE=`mount | grep " $PART " | cut -d" " -f 1`
				[ -L $MOUNTLINE ] && MDMPCMD=`ls -l $MOUNTLINE | grep ">"` || MDMPCMD=""
				if [ "$MDMPCMD" != "" ]; then
					MDMP=`echo $MDMPCMD | cut -d">" -f 2`
					if [ "$MDMP" == "$DMP" ]; then
						I=$((I+1))
						PRINTCONKY+="   $PART  \$alignr\$color\${fs_free $PART}\${color grey}/\$color\${fs_size $PART} \${color}\${fs_bar 7,150 $PART}\n"
					fi
				else 
					NEWPARTS+=" $PART"
				fi
			done
		done <<< "$LVS"
	done <<< "$VGS"
  
	if [ "$I" == "0" ]; then
		PRINTCONKY=${PRINTCONKY%??}
		PRINTCONKY+=" none.\n"
	fi
fi
PARTS=`echo $NEWPARTS | xargs -n1 | sort -u | xargs`

echo "[CONKY] * Config LVM done"

##############################
#######	 PARTITIONS  #########
##############################

echo "[CONKY] * Config Partitions"

for DISK in $DISKS; do
	PRINTCONKY+="\${color grey}File systems on \$color/dev/$DISK \${color grey}: \$color(\${color orange}I/O : \${diskio /dev/$DISK}/s\$color)\n"
	I=0
	for PART in $PARTS; do
		DEVICE=`mount | grep " $PART " | cut -d" " -f 1`
		case "$DEVICE" in
			*/dev/mapper/*)
				DEVICE=`cryptsetup status $(basename $DEVICE) | grep device | colrm 1 11`
				;;
		esac
		if [ "`echo $DEVICE | grep $DISK`" == "$DEVICE" ]; then
			PRINTCONKY+="   $PART  \$alignr\$color\${fs_free $PART}\${color grey}/\$color\${fs_size $PART} \${color}\${fs_bar 7,150 $PART}\n"
			I=$((I+1))
		else
			UUIDPART=`ls -l /dev/disk/by-uuid/ | grep "$(basename $DEVICE)"`
			case $UUIDPART in
				*$DISK*)
					PRINTCONKY+="   $PART  \$alignr\$color\${fs_free $PART}\${color grey}/\$color\${fs_size $PART} \${color}\${fs_bar 7,150 $PART}\n"
					I=$((I+1))	
					;;
			esac
		fi
	done
	if [ "$I" == "0" ]; then
		PRINTCONKY=${PRINTCONKY%??}
		PRINTCONKY+=" none.\n"
	fi
done
PRINTCONKY=${PRINTCONKY%??}
sed -i -e "s#%%HDD%%#$PRINTCONKY#g" $CONFFILE

echo "[CONKY] * Config Partitions done"

############################
#######	PROCESSORS #########
############################

echo "[CONKY] * Config Processors"

NBPROC=`cat /proc/cpuinfo | grep processor | wc -l`
CPUS=" "
for (( i=1; i<=$NBPROC; i++ ))
do
	CPUS+="\${color grey}CPU0$i @\$color\${freq_g $i}\${color grey}GHz \${color}\${cpubar cpu$i 7,70}"
	if [[ "$((i % 2))" == "0" ]]; then
		CPUS+="\n "
	else
		CPUS+="\${alignr}"
	fi
done
if [ "$((NBPROC % 2))" == "0" ]; then
	CPUS=${CPUS%???}
else
	CPUS=${CPUS%?????????}
fi
sed -i -e "s#%%CPU%%#$CPUS#g" $CONFFILE

echo "[CONKY] * Config Processors done"

###########################
#######	 NETWORK  #########
###########################

echo "[CONKY] * Config Network"

NETDEVS=`ls /sys/class/net | grep -v "^lo$"`
NET=" "

for NETDEV in $NETDEVS; do
	NET+="\n\${if_up ${NETDEV}}"
	NET+="\${color red}NETWORK ${NETDEV^^} (\${addr ${NETDEV}}) \${hr 2}\$color\n"
	NET+=" \${color grey}Down: \$color\${downspeed ${NETDEV}}/s (\${totaldown ${NETDEV}})\${alignr}\${color grey}Up: \$color\${upspeed ${NETDEV}}/s (\${totalup ${NETDEV}})\n"
	NET+=" \${downspeedgraph ${NETDEV} 20,162 CCFF01 CCFF01}\$alignr\${upspeedgraph ${NETDEV} 20,162 FF4301 FF4301}\${else}"
	NET+="\${color red}NETWORK ${NETDEV^^} (DOWN) \${hr 2}\$color\${endif}"
done

sed -i -e "s#%%NET%%#$NET#g" $CONFFILE

echo "[CONKY] * Config Network done."
echo "[CONKY] end."

exit 
