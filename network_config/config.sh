
# the iface of the "outside"
WEBIFACE=eth0
# the iface of the LAN it will serve
LANIFACE=lo

# network and mask of the LAN
DOMAIN_NAME=diablan

LANNET=172.30.255.0/24
SERVERLANIP=172.30.255.254
DHCP_RANGE=172.30.255.10:172.30.255.200

SUDOUSER=koubi

# overide hostname: if set, change hostname
# HOSTNAME_OVERRIDE="gwtest"