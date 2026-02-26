#!/bin/bash
set -e

# Run this as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

USERNAME=phire
SWAP_SIZE="1G"

# ask for password for new user
read -s -p "Enter password for new user $USERNAME: " PASSWORD
echo

# ---------------------------
# Update and Install Base Packages
# ---------------------------
echo "Updating system..."
apt update && apt upgrade -y

# ---------------------------
# Install essential packages
# ---------------------------
echo "Installing base packages..."
apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    unattended-upgrades \
    htop \
    git

# ---------------------------------------------------------------------------------------------------------------------
# Add Swap (Critical for 1GB)
# ---------------------------------------------------------------------------------------------------------------------
if [ ! -f /swapfile ]; then
    echo "Creating swap..."
    fallocate -l $SWAP_SIZE /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Lower swappiness (better for small RAM)
sysctl vm.swappiness=10
echo "vm.swappiness=10" >> /etc/sysctl.conf

# ---------------------------------------------------------------------------------------------------------------------
# Install Docker (Official)
# ---------------------------------------------------------------------------------------------------------------------
echo "Installing Docker..."

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# ---------------------------------------------------------------------------------------------------------------------
# Install Docker Compose Standalone
# ---------------------------------------------------------------------------------------------------------------------
echo "Installing Docker Compose standalone binary..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create symbolic link for 'docker compose' to work with standalone
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Docker Memory Protection
mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

systemctl enable docker
systemctl restart docker

# ---------------------------------------------------------------------------------------------------------------------
# Create user
# ---------------------------------------------------------------------------------------------------------------------

useradd -m -s /bin/bash $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
usermod -aG sudo $USERNAME
usermod -aG docker $USERNAME

# Lock root
passwd -l root

# ---------------------------------------------------------------------------------------------------------------------
# Setup UFW Firewall
# ---------------------------------------------------------------------------------------------------------------------
echo "Setting up UFW firewall..."
apt install -y ufw

# Allow SSH (critical - don't lock yourself out!)
ufw allow 22/tcp

# Allow HTTPS
ufw allow 443/tcp

# Enable UFW
ufw --force enable

echo "UFW firewall enabled with ports 22 and 443 allowed"

# ---------------------------------------------------------------------------------------------------------------------
# Verify Installation
# ---------------------------------------------------------------------------------------------------------------------
echo "Verifying installation..."
docker --version
docker-compose --version
docker compose version
git --version

# Enable auto security updates
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "Server is ready"
