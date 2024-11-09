#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

source config.sh

############################################################################################
## Generate Firewall config
############################################################################################

echo "[NETCONF] INFO: Generate firewall rules"

FIREWALL_FOLDER=./gen.firewall.iptables/

FIREWALL_FOLDER=$FIREWALL_FOLDER/sbin/
SYSTEMD_LIBRARY=$FIREWALL_FOLDER/lib/systemd/system

mkdir -p $SYSTEMD_LIBRARY $FIREWALL_FOLDER
    
cat > ${FIREWALL_FOLDER}/firewall_router.down.sh << EOF
#!/usr/bin/env bash
set -eu -o pipefail

###
### Disable Routing
###

echo 0 > /proc/sys/net/ipv4/ip_forward

###
### Security Tuning
###

# Keep security tuning if set

###
### IPTable setup
###

IPTABLES=/usr/sbin/iptables
ILAN=$LANIFACE
IWAN=$WEBIFACE
ILO=lo
LAN=$LANNET
IPWAN=\$(ip addr show \$IWAN | grep -Po 'inet \K[\d.]+')

# Purge
\$IPTABLES -F
\$IPTABLES -X
\$IPTABLES -Z

\$IPTABLES -t filter -F INPUT
\$IPTABLES -t filter -F FORWARD
\$IPTABLES -t filter -F OUTPUT

\$IPTABLES -t nat -F PREROUTING
\$IPTABLES -t nat -F OUTPUT
\$IPTABLES -t nat -F POSTROUTING

# Default: drop
\$IPTABLES -t filter -P INPUT   DROP
\$IPTABLES -t filter -P FORWARD DROP
\$IPTABLES -t filter -P OUTPUT  DROP
\$IPTABLES -t nat -P PREROUTING  ACCEPT
\$IPTABLES -t nat -P OUTPUT      ACCEPT
\$IPTABLES -t nat -P POSTROUTING ACCEPT

# Allow loopback
\$IPTABLES -A INPUT -i \$ILO -j ACCEPT
\$IPTABLES -A OUTPUT -o \$ILO -j ACCEPT

# Drop invalid packets
\$IPTABLES -A INPUT   -m state --state INVALID -j DROP
\$IPTABLES -A OUTPUT  -m state --state INVALID -j DROP
\$IPTABLES -A FORWARD -m state --state INVALID -j DROP

# Allow answers
\$IPTABLES -A INPUT   -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPTABLES -A OUTPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outgoing trafic from the router
\$IPTABLES -A OUTPUT -j ACCEPT

# Allow ping (in & out)
\$IPTABLES -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
\$IPTABLES -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

# Allow SSH only, from anywhere
\$IPTABLES -A INPUT -m state --state NEW -p Tcp --dport 22 -j ACCEPT

EOF
cat > ${FIREWALL_FOLDER}/firewall_router.up.sh << EOF
#!/usr/bin/env bash
set -eu -o pipefail

###
### Enable Routing
###

echo 1 > /proc/sys/net/ipv4/ip_forward

set +e
lsmod | grep "nf_nat_ftp" &> /dev/null
RES=\$?
set -e
if [ \$RES != 0 ]; then
  # note: will fail on LXC, need to run this on host
  set +e
  (
    modprobe nf_nat_ftp
    modprobe nf_conntrack_ftp
  ) &> /dev/null
  set -e
  # silently fail to keep main functionalities up
fi

###
### Security Tuning
###

# Enable broadcast echo protection
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# Enable TCP syn cookie protection
echo 1 > /proc/sys/net/ipv4/tcp_syncookies

# Store packets with impossible addresses
# Actually disabled
echo 0 > /proc/sys/net/ipv4/conf/all/log_martians

# Ignore ICMP bogus error responses
echo 1 > /proc/sys/net/ipv4/icmp_ignore_bogus_error_responses

# Enable IP spoofing protection
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter

# Disable ICMP redirects
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects

# Disable Source Routed
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route

###
### IPTable setup
###

IPTABLES=/usr/sbin/iptables
ILAN=$LANIFACE
IWAN=$WEBIFACE
ILO=lo
LAN=$LANNET
IPWAN=\$(ip addr show \$IWAN | grep -Po 'inet \K[\d.]+')

# Purge
\$IPTABLES -F
\$IPTABLES -X
\$IPTABLES -Z

\$IPTABLES -t filter -F INPUT
\$IPTABLES -t filter -F FORWARD
\$IPTABLES -t filter -F OUTPUT

\$IPTABLES -t nat -F PREROUTING
\$IPTABLES -t nat -F OUTPUT
\$IPTABLES -t nat -F POSTROUTING

# Default: drop
\$IPTABLES -t filter -P INPUT   DROP
\$IPTABLES -t filter -P FORWARD DROP
\$IPTABLES -t filter -P OUTPUT  DROP
\$IPTABLES -t nat -P PREROUTING  ACCEPT
\$IPTABLES -t nat -P OUTPUT      ACCEPT
\$IPTABLES -t nat -P POSTROUTING ACCEPT

# Enable NAT
\$IPTABLES -t nat -A POSTROUTING -s \$LAN -o \$IWAN -j MASQUERADE

# Allow loopback
\$IPTABLES -A INPUT -i \$ILO -j ACCEPT
\$IPTABLES -A OUTPUT -o \$ILO -j ACCEPT

# Drop invalid packets
\$IPTABLES -A INPUT   -m state --state INVALID -j DROP
\$IPTABLES -A OUTPUT  -m state --state INVALID -j DROP
\$IPTABLES -A FORWARD -m state --state INVALID -j DROP

# Allow answers
\$IPTABLES -A INPUT   -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
\$IPTABLES -A OUTPUT  -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow outgoing trafic from the router
\$IPTABLES -A OUTPUT -j ACCEPT
\$IPTABLES -t nat -A OUTPUT -j ACCEPT

# Allow from LAN to routeur
\$IPTABLES -A INPUT -m state --state NEW -i \$ILAN -j ACCEPT
\$IPTABLES -A OUTPUT -m state --state NEW -o \$ILAN -j ACCEPT

# Allow FORWARD from LAN to WAN
\$IPTABLES -A FORWARD -m state --state NEW -i \$ILAN -o \$IWAN -j ACCEPT

# Allow FORWARD from LAN to LAN
\$IPTABLES -A FORWARD -m state --state NEW -i \$ILAN -o \$ILAN -j ACCEPT

# Allow ping (in & out)
\$IPTABLES -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
\$IPTABLES -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT

### GW bindings ###
\$IPTABLES -A INPUT -m state --state NEW -i \$IWAN -p Tcp --dport 22 -j ACCEPT # allow ssh
# \$IPTABLES -A INPUT -m state --state NEW -i \$IWAN -p Tcp --dport 2222 -j ACCEPT
# \$IPTABLES -A INPUT -m state --state NEW -i \$IWAN -p Tcp --dport 8080 -j ACCEPT

### NAT bindings ###

# # Comment: Allow WAN on port \$PORT_WAN to reach \$IP on port \$PORT_LAN
# # TODO: check if working ...
# IP=172.30.255.209
# PORT_WAN=49612
# PORT_LAN=49612
# \$IPTABLES -A FORWARD -d \$IP -p tcp --dport \$PORT_LAN -j ACCEPT
# \$IPTABLES -t nat -A PREROUTING -d \$IPWAN -p tcp --dport \$PORT_WAN -j DNAT --to-destination \$IP:\$PORT_LAN

# # Comment: example with multiple ports/protocols
# \$IPTABLES -A FORWARD -d \$IP -p tcp --dport 27015:27032 -j ACCEPT
# \$IPTABLES -A FORWARD -d \$IP -p udp --dport 27015:27032 -j ACCEPT
# \$IPTABLES -t nat -A PREROUTING -d \$IPWAN -p tcp --dport 27015:27032 -j DNAT --to-destination \$IP
# \$IPTABLES -t nat -A PREROUTING -d \$IPWAN -p tcp --dport 27015:27032 -j DNAT --to-destination \$IP

EOF
# TODO: nat bindings from file

for NAT_RULE in $NAT_LIST; do
  HOST=$(echo $NAT_RULE | cut -d'#' -f1)
  HOST=$(lookup_ip $HOST)

  # echo $HOST
  for portmap in $(echo $NAT_RULE | cut -d'#' -f2- | tr "#" "\n"); do
    PROTO=$(echo $portmap | cut -d'/' -f2)
    case $PROTO in
      u|udp|U|UDP|Udp) PROTO=udp ;;
      *) PROTO=tcp ;;
    esac
    OUTSIDE_RANGE=$(echo $portmap | cut -d':' -f1)
    case $OUTSIDE_RANGE in
      *[0-9]-[0-9]*) : ;;
      *)
        OUTSIDE_RANGE="${OUTSIDE_RANGE}-${OUTSIDE_RANGE}"
        ;;
    esac
    INSIDE_RANGE=$(echo $portmap | cut -d':' -f2 | cut -d'/' -f1)
    case $INSIDE_RANGE in
      "") INSIDE_RANGE=$OUTSIDE_RANGE ;;
      *[0-9]-[0-9]*) : ;;
      *)
        INSIDE_RANGE="${INSIDE_RANGE}-${INSIDE_RANGE}"
        ;;
    esac
    # echo " - $OUTSIDE_RANGE - $INSIDE_RANGE /$PROTO"
    cat >> ${FIREWALL_FOLDER}/firewall_router.up.sh << EOF
HOST="$HOST"
PORT_WAN="$(echo $OUTSIDE_RANGE | tr '-' ':')"
# PORT_LAN="$(echo $INSIDE_RANGE | tr '-' ':')"
PORT_LAN=$INSIDE_RANGE
PROTO="$PROTO"

\$IPTABLES -A FORWARD -d \$HOST -p \$PROTO --dport \$PORT_LAN -j ACCEPT
\$IPTABLES -t nat -A PREROUTING -d \$IPWAN -p \$PROTO --dport \$PORT_WAN -j DNAT --to-destination \${HOST}:\${PORT_LAN}
EOF
  done
done

cat > ${SYSTEMD_LIBRARY}/firewall_router.service << EOF
[Unit]
Description=Firewall
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/sbin/firewall_router.up.sh
ExecStop=/usr/sbin/firewall_router.down.sh

[Install]
WantedBy=multi-user.target
EOF

# if [ "$GEN_CONFIG" != "YES" ]; then
#   chmod +x /usr/sbin/firewall_router.down.sh
#   chmod +x /usr/sbin/firewall_router.up.sh

#   systemctl enable firewall_router
# fi

############################################################################################
## Exit
############################################################################################
echo "[NETCONF] INFO: Generate firewall Done."
exit 0
