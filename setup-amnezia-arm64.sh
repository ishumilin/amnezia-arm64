#!/bin/bash

# Amnezia VPN ARM64 Setup Script
# 
# IMPORTANT: This script is for Amnezia VPN (https://amnezia.org)
#            NOT for standalone AmneziaWG protocol implementations
#            Requires the official Amnezia VPN app from https://amnezia.org/downloads
#
# PURPOSE:
#   The Amnezia VPN app expects x86_64 Docker images (amneziavpn/amnezia-wg, etc.)
#   which don't work on ARM64 servers. This script sets up a local Docker registry
#   that intercepts image pulls and serves ARM64-compatible images instead.
#
# HOW IT WORKS:
#   1. Pulls ARM64 images from Docker Hub (ishumilin/amnezia-*)
#   2. Sets up local Docker registry on localhost:5000
#   3. Re-tags ARM64 images with official names (amneziavpn/*)
#   4. Configures Docker to use local registry as mirror
#   5. When Amnezia app pulls images, Docker serves ARM64 versions transparently

set -e  # Exit on error

echo "=========================================="
echo "  Amnezia VPN ARM64 Setup Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "⚠️  Please do not run this script as root"
    echo "   Run as a regular user with sudo privileges"
    exit 1
fi

# Check if Docker is installed, if not install it
if ! command -v docker &> /dev/null; then
    echo "📦 Docker is not installed. Installing Docker..."
    echo ""
    
    # Update package index
    echo "   Updating package index..."
    sudo apt-get update -qq
    
    # Install prerequisites
    echo "   Installing prerequisites..."
    sudo apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    echo "   Adding Docker GPG key..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up Docker repository
    echo "   Setting up Docker repository..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    echo "   Installing Docker Engine..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    echo "✅ Docker installed successfully"
    echo ""
else
    echo "✅ Docker is already installed"
    echo ""
fi

# Check if user can run Docker, if not add to docker group
if ! docker ps &> /dev/null 2>&1; then
    echo "🔧 Adding user to docker group..."
    sudo usermod -aG docker $USER
    echo "✅ User added to docker group"
    echo ""
    echo "ℹ️  Using sudo for Docker commands in this session..."
    echo "   (Group membership will be active in new sessions)"
    echo ""
    USE_SUDO="sudo"
else
    echo "✅ Docker is accessible"
    echo ""
    USE_SUDO=""
fi

# Pull ARM64 images
echo "📥 Pulling ARM64 image from Docker Hub..."
echo "   This may take a few minutes..."
$USE_SUDO docker pull ishumilin/amnezia-awg:latest
echo "✅ Image pulled successfully"
echo ""

# Set up local Docker registry
echo "🔧 Setting up local Docker registry..."
if $USE_SUDO docker ps -a | grep -q "registry"; then
    echo "   Registry container already exists, removing..."
    $USE_SUDO docker stop registry 2>/dev/null || true
    $USE_SUDO docker rm registry 2>/dev/null || true
fi

$USE_SUDO docker run -d -p 5000:5000 --restart=always --name registry registry:2
echo "✅ Local registry started"
echo ""

# Push ARM64 image to local registry
echo "📤 Pushing image to local registry..."
$USE_SUDO docker tag ishumilin/amnezia-awg:latest localhost:5000/amneziavpn/amnezia-wg:latest
$USE_SUDO docker push localhost:5000/amneziavpn/amnezia-wg:latest
echo "✅ Image pushed to local registry"
echo ""

# Configure Docker to use local registry
echo "⚙️  Configuring Docker daemon..."
sudo mkdir -p /etc/docker

# Backup existing daemon.json if it exists
if [ -f /etc/docker/daemon.json ]; then
    echo "   Backing up existing daemon.json..."
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
fi

sudo bash -c 'cat > /etc/docker/daemon.json << "EOF"
{
  "insecure-registries": ["localhost:5000"],
  "registry-mirrors": ["http://localhost:5000"]
}
EOF'
echo "✅ Docker daemon configured"
echo ""

# Restart Docker to apply changes
echo "🔄 Restarting Docker service..."
sudo systemctl restart docker
echo "✅ Docker restarted"
echo ""

# Wait for Docker to be ready
echo "⏳ Waiting for Docker to be ready..."
sleep 5

# Restart local registry (it was stopped by Docker restart)
echo "🔄 Restarting local registry..."
$USE_SUDO docker start registry
sleep 2
echo "✅ Registry restarted"
echo ""

# Re-push image after Docker restart
echo "📤 Re-pushing image to local registry..."
$USE_SUDO docker tag ishumilin/amnezia-awg:latest localhost:5000/amneziavpn/amnezia-wg:latest
$USE_SUDO docker push localhost:5000/amneziavpn/amnezia-wg:latest
echo "✅ Image re-pushed successfully"
echo ""

# Verify setup
echo "🔍 Verifying setup..."
echo ""
echo "Docker images:"
$USE_SUDO docker images | grep -E "amnezia|registry" || echo "No images found"
echo ""
echo "Local registry contents:"
curl -s http://localhost:5000/v2/_catalog | python3 -m json.tool 2>/dev/null || echo "Registry catalog: $(curl -s http://localhost:5000/v2/_catalog)"
echo ""


echo "=========================================="
echo "  ✅ Setup Complete!"
echo "=========================================="
echo ""
echo "Your ARM64 server is now ready for Amnezia VPN app deployment."
echo ""
echo "🎯 What was configured:"
echo "   - Docker installed and configured"
echo "   - Local registry running on localhost:5000"
echo "   - ARM64 images pulled from Docker Hub (ishumilin/amnezia-*)"
echo "   - Images re-tagged and pushed to local registry"
echo "   - Docker configured to use local registry as mirror"
echo ""
echo "💡 How it works:"
echo "   When Amnezia app tries to pull official images (amneziavpn/*)"
echo "   Docker will serve our ARM64 images from the local registry instead!"
echo ""
echo "📱 Next steps:"
echo "   1. Open Amnezia VPN app on your device"
echo "   2. Click 'Add server' or '+'"
echo "   3. Select 'I have the data to connect'"
echo "   4. Enter server details:"
echo "      - IP: $(hostname -I | awk '{print $1}')"
echo "      - SSH port: 22"
echo "      - Username: $USER"
echo "      - Password or SSH key"
echo "   5. Select AmneziaWG protocol"
echo "   6. Click 'Install'"
echo ""
echo "🎉 The app will use your local ARM64 images automatically!"
echo ""
echo "📝 Notes:"
echo "   - Local registry runs on localhost:5000"
echo "   - Registry will auto-start on system reboot"
echo "   - Backup of old daemon.json saved (if existed)"
echo ""
echo "🔧 Troubleshooting:"
echo "   - Check registry: sudo docker ps | grep registry"
echo "   - View logs: sudo docker logs registry"
echo "   - Restart registry: sudo docker restart registry"
echo ""
