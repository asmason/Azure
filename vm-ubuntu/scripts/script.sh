#!/bin/sh
sudo apt update
sudo apt install moreutils -y

# == To run this script
# wget https://asmprdsamgt1.blob.core.windows.net/deployment//setup.sh
# chmod u+x setup.sh
# ./setup.sh

echo
echo "--- Configuration: general server settings ---"
echo

#VPNHOST=$0
VPNHOST=vmp1wss1
DNS=vmp1wss1
CN=asmvmp1wss1.northeurope.cloudapp.azure.com

VPNHOSTIP=$(dig -4 +short "$VPNHOST")
VPNHOSTPIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
VPNIPPOOL="172.18.6.0/24"
ETH0ORSIMILAR=$(ip route get 8.8.8.8 | awk -- '{printf $5}')
IP=$(ifdata -pa $ETH0ORSIMILAR)

echo
echo "Network interface: ${ETH0ORSIMILAR}"
echo "External IP: ${IP}"

echo
echo "--- Updating and installing software ---"
echo

# 1 Install strongSwan

sudo apt-get install strongswan strongswan-pki libcharon-extra-plugins -y
sudo apt-get upgrade 

cd /
sudo mkdir -p pki/private
sudo mkdir -p pki/certs
sudo mkdir -p pki/cacerts
# TODO change permissions to be more secure
sudo chmod -R 777 /pki

# 2 Create CA
# create root key
sudo ipsec pki --gen --type rsa --size 4096 --outform pem > /pki/private/ca-key.pem
# create root CA
sudo ipsec pki --self --ca --lifetime 3650 --in /pki/private/ca-key.pem --type rsa --dn "CN=VPN root CA" --outform pem > /pki/cacerts/ca-cert.pem
# create server key
sudo ipsec pki --gen --type rsa --size 4096 --outform pem > /pki/private/server-key.pem

# 3 Create certificate for VPN server
sudo ipsec pki --pub --in /pki/private/server-key.pem --type rsa \
    | ipsec pki --issue --lifetime 1825 \
        --cacert /pki/cacerts/ca-cert.pem \
        --cakey /pki/private/ca-key.pem \
        --dn "CN=${CN}" --san "${IP}" \
        --flag serverAuth --flag ikeIntermediate --outform pem \
    >  /pki/certs/server-cert.pem

# copy all certs 
sudo cp -r /pki/* /etc/ipsec.d/

# 4 Configure strongSwan
# iOS/Mac with appropriate configuration profiles use AES_GCM_16_256/PRF_HMAC_SHA2_256/ECP_521 
# Windows 10 uses AES_CBC_256/HMAC_SHA2_256_128/PRF_HMAC_SHA2_256/ECP_384 
# Windows: Set-ItemProperty -Path HKLM:\System\CurrentControlSet\Services\Rasman\Parameters -Name NegotiateDH2048_AES256 -Type DWord -Value 1 -Force
sudo mv /etc/ipsec.conf /etc/ipsec.conf.original
echo "config setup
  strictcrlpolicy=yes
  uniqueids=never
conn roadwarrior
  auto=add
  compress=no
  type=tunnel
  keyexchange=ikev2
  fragmentation=yes
  forceencaps=yes
  dpdaction=clear
  dpddelay=300s
  rekey=no
  left=%any
  leftid=@${VPNHOSTIP}
  leftcert=server-cert.pem
  leftsendcert=always
  leftsubnet=172.18.0.0/16 
  right=%any
  rightid=%any
  rightauth=eap-mschapv2
  eap_identity=%any
  rightdns=8.8.8.8,8.8.4.4
  rightsourceip=${VPNIPPOOL}
  rightsendcert=never
" > /etc/ipsec.conf

sudo mv /etc/ipsec.secrets /etc/ipsec.secrets.original
echo ': RSA "server-key.pem"
user1 : EAP "password1"
user2 : EAP "password2"
' > /etc/ipsec.secrets

sudo systemctl restart strongswan

# Edit sysctl.conf file
sudo mv /etc/sysctl.conf /etc/sysctl.conf.original
cp /etc/sysctl.conf /tmp/
sudo cat >> /tmp/sysctl.conf << EOF
net.ipv4.ip_forward = 1 
net.ipv4.conf.all.accept_redirects = 0 
net.ipv4.conf.all.send_redirects = 0
EOF
sudo cp /tmp/sysctl.conf /etc/
sudo sysctl -p /etc/sysctl.conf
sudo rm /tmp/sysctl.conf

echo
echo "--- Configuring firewall ---"
echo

# Enabled UFW and add firewall rules
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw allow 500,4500/udp
sudo ufw allow 1701/udp
sudo ufw allow to "$VPNHOSTIP" proto esp
sudo ufw allow to "$VPNHOSTIP" from 0.0.0.0/0 proto esp
sudo ufw allow to "$VPNHOSTIP" proto ah
sudo ufw allow to "$VPNHOSTIP" from 0.0.0.0/0 proto ah
sudo ufw disable
sudo ufw enable

sudo ufw status
ip route | grep default

# Need to put the CA cert on the client machine(s) (Computer Account on Windows, in Trusted Root Certification Authorities). Save as ca-cert.pem
#cat /etc/ipsec.d/cacerts/ca-cert.pem

# Edit before.rules file
sudo mv /etc/ufw/before.rules /etc/ufw/before.rules.original
echo "# rules.before
#
# Rules that should be run before the ufw command line added rules. Custom
# rules should be added to one of these chains:
#   ufw-before-input
#   ufw-before-output
#   ufw-before-forward
#

# Added for StrongSwan
*nat
-A POSTROUTING -s ${VPNIPPOOL} -o eth0 -m policy --pol ipsec --dir out -j ACCEPT
-A POSTROUTING -s ${VPNIPPOOL} -o eth0 -j MASQUERADE
COMMIT

*mangle
-A FORWARD --match policy --pol ipsec --dir in -s ${VPNIPPOOL} -o eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
COMMIT

# Don't delete these required lines, otherwise there will be errors
*filter
:ufw-before-input - [0:0]
:ufw-before-output - [0:0]
:ufw-before-forward - [0:0]
:ufw-not-local - [0:0]
# End required lines

# Added for StrongSwan
-A ufw-before-forward --match policy --pol ipsec --dir in --proto esp -s ${VPNIPPOOL} -j ACCEPT
-A ufw-before-forward --match policy --pol ipsec --dir out --proto esp -d ${VPNIPPOOL} -j ACCEPT

# allow all on loopback
-A ufw-before-input -i lo -j ACCEPT
-A ufw-before-output -o lo -j ACCEPT

# quickly process packets for which we already have a connection
-A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# drop INVALID packets (logs these in loglevel medium and higher)
-A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny
-A ufw-before-input -m conntrack --ctstate INVALID -j DROP

# ok icmp codes for INPUT
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-input -p icmp --icmp-type echo-request -j ACCEPT

# ok icmp code for FORWARD
-A ufw-before-forward -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT

# allow dhcp client to work
-A ufw-before-input -p udp --sport 67 --dport 68 -j ACCEPT

#
# ufw-not-local
#
-A ufw-before-input -j ufw-not-local

# if LOCAL, RETURN
-A ufw-not-local -m addrtype --dst-type LOCAL -j RETURN

# if MULTICAST, RETURN
-A ufw-not-local -m addrtype --dst-type MULTICAST -j RETURN

# if BROADCAST, RETURN
-A ufw-not-local -m addrtype --dst-type BROADCAST -j RETURN

# all other non-local packets are dropped
-A ufw-not-local -m limit --limit 3/min --limit-burst 10 -j ufw-logging-deny
-A ufw-not-local -j DROP

# allow MULTICAST mDNS for service discovery (be sure the MULTICAST line above
# is uncommented)
-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT

# allow MULTICAST UPnP for service discovery (be sure the MULTICAST line above
# is uncommented)
-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT

# don't delete the 'COMMIT' line or these rules won't be processed
COMMIT" > /etc/ufw/before.rules
sudo ufw disable
sudo ufw enable
