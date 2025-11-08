# Complete Testing Guide

This guide walks you through testing the entire workflow: building containers, pushing to registries, and deploying to AWS.

## 🔐 Prerequisites

### 1. Docker Hub Login

```bash
docker login
# Enter your Docker Hub username: ishumilin
# Enter your password: [your password]
```

### 2. GitHub Container Registry Login

```bash
# First, create a GitHub Personal Access Token with 'write:packages' permission
# Then login:
echo $GITHUB_TOKEN | docker login ghcr.io -u ishumilin --password-stdin

# Or manually:
docker login ghcr.io
# Username: ishumilin
# Password: [your GitHub token]
```

### 3. AWS CLI Configuration

```bash
aws configure
# AWS Access Key ID: [your key]
# AWS Secret Access Key: [your secret]
# Default region name: eu-west-1
# Default output format: json
```

## 🔨 Step 1: Build and Push Docker Images

### Build the Container

```bash
cd amnezia-containers
./build.sh
```

**What this does:**
- Builds ARM64 Docker image for AmneziaWG
- Tags with `arm64` and `latest`
- Pushes to Docker Hub: `ishumilin/amnezia-awg:latest`
- Pushes to GHCR: `ghcr.io/ishumilin/amnezia-awg:latest`

**Expected output:**
```
==========================================
Building Amnezia ARM64 Containers
==========================================

Building Amnezia AWG container...
[+] Building ...
✓ Amnezia AWG container built and pushed

==========================================
Build Complete!
==========================================

Images pushed to:
  - docker.io/ishumilin/amnezia-awg:latest
  - docker.io/ishumilin/amnezia-awg:arm64
  - ghcr.io/ishumilin/amnezia-awg:latest
  - ghcr.io/ishumilin/amnezia-awg:arm64
```

### Verify Images Were Pushed

```bash
# Check Docker Hub
docker pull ishumilin/amnezia-awg:latest

# Check GHCR
docker pull ghcr.io/ishumilin/amnezia-awg:latest

# Verify architecture
docker inspect ishumilin/amnezia-awg:latest | grep Architecture
# Should show: "Architecture": "arm64"
```

## 🧪 Step 2: Test Locally (Optional)

Before deploying to AWS, test the container locally:

```bash
cd amnezia-containers

# Start the container
docker-compose up -d

# Check if it's running
docker ps | grep amnezia

# Check logs
docker logs amnezia-awg

# Stop the container
docker-compose down
```

## ☁️ Step 3: Deploy to AWS

### Dry Run First (Recommended)

```bash
cd /Users/eliazar/Projects/dev/private/amnezia

# Preview what will be created
./deploy-to-aws.sh --dry-run
```

### Actual Deployment

```bash
# Deploy to AWS
./deploy-to-aws.sh

# Or with custom options:
./deploy-to-aws.sh \
  --region us-east-1 \
  --instance-type t4g.micro \
  --allow-ssh-from $(curl -s https://checkip.amazonaws.com)/32
```

**What this does:**
1. Creates security group with ports:
   - SSH (22/tcp) - from your IP or 0.0.0.0/0
   - AmneziaWG (33911/udp) - from anywhere
2. Creates SSH key pair (saves to `~/.ssh/amnezia-vpn-key.pem`)
3. Launches t4g.small EC2 instance
4. Waits for instance to be ready
5. Copies `setup-amnezia-arm64.sh` to instance
6. Runs setup script on instance
7. Provides connection details

## 📱 Step 4: Connect with Amnezia VPN App

### Download the App

- **iOS**: https://apps.apple.com/app/amnezia-vpn/id1600529900
- **Android**: https://play.google.com/store/apps/details?id=org.amnezia.vpn
- **Desktop**: https://github.com/amnezia-vpn/amnezia-client/releases

### Configure in App

1. Open Amnezia VPN app
2. Click "Add server" or "+"
3. Select "I have the data to connect"
4. Enter server details:
   - **IP**: [from deployment output]
   - **SSH Port**: 22
   - **Username**: ubuntu
   - **SSH Key**: Browse to `~/.ssh/amnezia-vpn-key.pem`
5. Select **AmneziaWG** protocol
6. Click "Install"

### What Happens Next

The app will:
1. Connect to your server via SSH
2. Pull the ARM64 Docker image (from local registry)
3. Generate VPN keys
4. Configure the container
5. Start the VPN service
6. Generate client configuration
7. Connect to VPN

## ✅ Step 5: Verify Everything Works

### On the Server

```bash
# SSH into the server
ssh -i ~/.ssh/amnezia-vpn-key.pem ubuntu@[SERVER_IP]

# Check Docker is running
sudo docker ps

# Check local registry
sudo docker ps | grep registry

# Check AWG container
sudo docker ps | grep amnezia-awg

# Check logs
sudo docker logs amnezia-awg

# Check network interface
ip addr show awg0
```

### On Your Device

1. **Connect to VPN** in Amnezia app
2. **Check connection status** - should show "Connected"
3. **Test internet** - browse a website
4. **Check IP address** - visit https://whatismyip.com
   - Should show your VPN server's IP
5. **Test speed** - run speed test

## 🧹 Step 6: Cleanup (When Done Testing)

### Destroy AWS Resources

```bash
./deploy-to-aws.sh --destroy
```

This will:
- Terminate EC2 instances
- Delete security groups
- Clean up resources

### Remove Local Images (Optional)

```bash
# Remove local images
docker rmi ishumilin/amnezia-awg:latest
docker rmi ghcr.io/ishumilin/amnezia-awg:latest

# Clean up build cache
docker builder prune
```

## 🐛 Troubleshooting

### Build Issues

**Problem**: Build fails with authentication error
```bash
# Solution: Login to registries
docker login
docker login ghcr.io
```

**Problem**: Build fails with "no space left on device"
```bash
# Solution: Clean up Docker
docker system prune -a
```

### Deployment Issues

**Problem**: SSH timeout during deployment
```bash
# Solution: Wait and retry, or check security group
aws ec2 describe-security-groups --group-ids [SG_ID]
```

**Problem**: Instance not accessible
```bash
# Solution: Check instance status
aws ec2 describe-instances --instance-ids [INSTANCE_ID]
```

### VPN Connection Issues

**Problem**: Can't connect to VPN
```bash
# Check server logs
ssh -i ~/.ssh/amnezia-vpn-key.pem ubuntu@[SERVER_IP]
sudo docker logs amnezia-awg
```

**Problem**: Connected but no internet
```bash
# Check routing on server
ssh -i ~/.ssh/amnezia-vpn-key.pem ubuntu@[SERVER_IP]
sudo iptables -L -n -v
```

## 📊 Success Criteria

✅ **Build Success:**
- Images built without errors
- Images pushed to Docker Hub
- Images pushed to GHCR
- Architecture is arm64

✅ **Deployment Success:**
- EC2 instance created
- Security groups configured
- SSH access works
- Setup script completed
- Docker registry running
- ARM64 images available

✅ **VPN Success:**
- Amnezia app connects to server
- Container deployed successfully
- VPN connection established
- Internet works through VPN
- IP address shows VPN server

## 📝 Testing Checklist

- [ ] Docker Hub login successful
- [ ] GHCR login successful
- [ ] AWS CLI configured
- [ ] Build script runs without errors
- [ ] Images pushed to Docker Hub
- [ ] Images pushed to GHCR
- [ ] Images verified as arm64
- [ ] Local test successful (optional)
- [ ] AWS dry-run successful
- [ ] AWS deployment successful
- [ ] SSH access to server works
- [ ] Docker registry running on server
- [ ] Amnezia app connects to server
- [ ] VPN container deployed
- [ ] VPN connection established
- [ ] Internet works through VPN
- [ ] Cleanup successful

## 🎉 Next Steps After Successful Test

1. **Update public repository**:
   ```bash
   cd public-dist
   git add .
   git commit -m "Tested and verified v1.0.0"
   git push origin main
   ```

2. **Tag release**:
   ```bash
   cd public-dist
   git tag v1.0.0
   git push --tags
   ```

3. **Update documentation** if needed

4. **Announce release** on GitHub

---

**Last Updated:** 2025-11-08  
**Tested By:** ishumilin
