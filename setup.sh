#!/bin/bash
# This script makes certain assumptions.
# 1) That you're using ArchLinux. If you use another OS, sorry, don't care. Don't @me.
# 2) That you use yay as your archlinux user repository helper
# 3) That you use Bash
# 4) You're not stupid enough to run this script as root.
# 5) You understand why wg-easy systemd service is setup to run as root (it needs up/down WG network interfaces)
# 6) You intend to run this on a VM
# 7) That you're lazy

# Pre-reqs; cleanup
sudo systemctl disable wg-easy --now
sudo rm -rf /usr/lib/systemd/system/wg-easy.service
sudo rm -rf /etc/systemd/system/multi-user.target.wants/wg-easy.service
sudo rm -rf /opt/wg-easy/

# Step 1. Install NVM, Wireguard Tools
yay -S --needed nvm wireguard-tools tcpdump --noconfirm

# Step 2. Source needed stuff
source /usr/share/nvm/init-nvm.sh

# Step 3. Install Node 14. Give it that latest NPM and run package installation
nvm install 14 --latest-npm
cd src && npm ci --production
cd ../

# Step 4. Move to /opt/wg-easy
sudo mv src/ /opt/wg-easy/

# Step 5. Add main connected interface name
if [ ! -f wg-easy.env ]; then
    echo "You do not have a wg-easy.env file setup. I've created a dummy one for you. Please edit and re-run."
    TCPDUMP_INTERFACES=$(tcpdump --list-interfaces | cut -d'.' -f2 | cut -d' ' -f1)
    DEVICE_INTERFACE_LIST=${TCPDUMP_INTERFACES[0]}
    DEVICE_INTERFACE=($DEVICE_INTERFACE_LIST)
    ESCAPED_REPLACE=$(printf '%s\n' "$DEVICE_INTERFACE" | sed -e 's/[\/&]/\\&/g')
    sed -i 's/DEVICE_NAME/'${ESCAPED_REPLACE}'/g' wg-easy.env.dist
    cp wg-easy.env.dist wg-easy.env
    exit
fi
sudo cp wg-easy.env /opt/wg-easy/wg-easy.env

# Step 6. Reset
git reset --hard

# Step 7. Move wg-easy.service into the appropriate path
NODE_PATH=$(which node)
ESCAPED_REPLACE=$(printf '%s\n' "$NODE_PATH" | sed -e 's/[\/&]/\\&/g')
sed -i 's/NODE_PATH/'${ESCAPED_REPLACE}'/g' wg-easy.service
sudo cp wg-easy.service /usr/lib/systemd/system/wg-easy.service

# Step 8. Run it!
sudo cp wg.conf /etc/sysctl.d/wg.conf
sudo sysctl --system
sudo systemctl enable wg-easy --now
