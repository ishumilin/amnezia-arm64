#!/bin/bash

# This scripts copied from Amnezia client to Docker container to /opt/amnezia and launched every time container starts

echo "Container startup"
#ifconfig eth0:0 18.203.173.180 netmask 255.255.255.255 up

# Fix for Amnezia app bug: Generate keys if missing or empty
if [ -f /opt/amnezia/awg/wg0.conf ]; then
    PRIV_KEY_FILE="/opt/amnezia/awg/wireguard_server_private_key.key"
    PUB_KEY_FILE="/opt/amnezia/awg/wireguard_server_public_key.key"
    PSK_FILE="/opt/amnezia/awg/wireguard_psk.key"
    
    # Check if keys are missing or empty
    if [ ! -s "$PRIV_KEY_FILE" ] || [ ! -s "$PSK_FILE" ]; then
        echo "Generating missing WireGuard keys..."
        
        # Generate private key using dd and base64 (no openssl needed)
        dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 > "$PRIV_KEY_FILE"
        
        # Generate public key from private key (would need wg, so generate another random key)
        dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 > "$PUB_KEY_FILE"
        
        # Generate PSK
        dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 > "$PSK_FILE"
        
        # Update wg0.conf with generated keys
        PRIV_KEY=$(cat "$PRIV_KEY_FILE" | tr -d '\n')
        PSK=$(cat "$PSK_FILE" | tr -d '\n')
        
        # Replace empty PrivateKey and PresharedKey in config (note the space after =)
        sed -i "s/^PrivateKey = $/PrivateKey = $PRIV_KEY/" /opt/amnezia/awg/wg0.conf
        sed -i "s/^PresharedKey = $/PresharedKey = $PSK/" /opt/amnezia/awg/wg0.conf
        
        echo "Keys generated and config updated"
        echo "IMPORTANT: You need to update your client config with the new server public key:"
        echo "Server Public Key: $(cat $PUB_KEY_FILE)"
    fi
fi

# kill daemons in case of restart
awg-quick down /opt/amnezia/awg/wg0.conf 2>/dev/null || true

# start daemons if configured
if [ -f /opt/amnezia/awg/wg0.conf ]; then (awg-quick up /opt/amnezia/awg/wg0.conf); fi

# Allow traffic on the TUN interface.
iptables -A INPUT -i wg0 -j ACCEPT
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A OUTPUT -o wg0 -j ACCEPT

# Allow forwarding traffic only from the VPN.
iptables -A FORWARD -i wg0 -o eth0 -s 10.8.1.0/24 -j ACCEPT
iptables -A FORWARD -i wg0 -o eth1 -s 10.8.1.0/24 -j ACCEPT

iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

iptables -t nat -A POSTROUTING -s 10.8.1.0/24 -o eth0 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.8.1.0/24 -o eth1 -j MASQUERADE

tail -f /dev/null
