#!/bin/bash

# Update packages and install ZeroTier and iptables-persistent
sudo apt install -y iptables-persistent

# Add ZeroTier repository and install
curl -s https://install.zerotier.com | sudo bash

# Prompt the user for the Network ID
while true; do
    read -p "Enter your Network ID: " NETWORK_ID
    if [[ $NETWORK_ID =~ ^[0-9a-f]{16}$ ]]; then
        break
    else
        echo "Invalid Network ID. Please enter a valid 16-character Network ID."
    fi
done

# Join the ZeroTier network
sudo zerotier-cli join $NETWORK_ID
JOIN_STATUS=$?

if [ $JOIN_STATUS -ne 0 ]; then
    echo "Failed to join the ZeroTier network. Please check your Network ID and try again."
    exit 1
fi

# Get the Node ID
NODE_ID=$(sudo zerotier-cli info | grep '200 info' | awk '{print $3}')

# Inform the user
echo "ZeroTier is installed and joined the network."
echo "Please authorize the device with Node ID: $NODE_ID in ZeroTier Central."
echo "After authorization, press any key to continue..."

# Wait for the user to press a key
read -n 1 -s -r -p ""

# Get the ZeroTier interface and IP address
ZT_INTERFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep '^zt')
ZT_IP=$(ip -4 addr show $ZT_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}(/\d+)?' | awk -F'/' '{print $1}')

# Enable IP forwarding
sudo sysctl -w net.ipv4.ip_forward=1
sudo sh -c "echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf"

# Set up NAT
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o $ZT_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -i $ZT_INTERFACE -o eth0 -j ACCEPT

# Save iptables rules
sudo netfilter-persistent save

echo "ZeroTier is configured as an Exit Node."
echo "Please configure the route 0.0.0.0/0 via $ZT_IP in ZeroTier Central."