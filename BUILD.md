# Amnezia VPN ARM64 - Build Documentation

This repository contains the build infrastructure for creating ARM64 Docker images for Amnezia VPN.

## 🎯 Purpose

This is the **private build repository** for maintaining and building ARM64 Docker images. The public-facing deployment repository is separate and contains only the deployment scripts and user documentation.

## 📁 Repository Structure

```
amnezia-arm64-build/
├── BUILD.md                    # This file - build documentation
├── README.md                   # Original project README
├── CHANGELOG.md                # Version history
├── LICENSE                     # MIT License
│
├── amneziawg-go/              # AmneziaWG daemon source code
│   ├── Dockerfile             # Build configuration
│   └── ...                    # Go source files
│
├── amneziawg-tools/           # AmneziaWG CLI tools source code
│   ├── src/                   # C source files
│   └── ...                    # Build scripts
│
├── amnezia-containers/        # Docker container definitions
│   ├── awg/                   # AmneziaWG container
│   │   ├── Dockerfile         # Container build file
│   │   └── start.sh           # Container startup script
│   ├── build.sh               # Build and push script
│   └── docker-compose.yml     # Local testing
│
└── public-dist/               # Public distribution files
    ├── README.md              # User-facing documentation
    ├── CHANGELOG.md           # Version history
    ├── LICENSE                # MIT License
    ├── deploy-to-aws.sh       # AWS deployment script
    ├── setup-amnezia-arm64.sh # Server setup script
    └── .gitignore             # Public repo gitignore
```

## 🔨 Building Docker Images

### Prerequisites

- Docker with buildx support
- Docker Hub account (or GitHub Container Registry)
- ARM64 build environment (or use buildx for cross-compilation)

### Build Process

1. **Build AmneziaWG daemon** (if needed):
   ```bash
   cd amneziawg-go
   make
   ```

2. **Build AmneziaWG tools** (if needed):
   ```bash
   cd amneziawg-tools/src
   make
   ```

3. **Build and push Docker images**:
   ```bash
   cd amnezia-containers
   ./build.sh
   ```

   This will:
   - Build ARM64 Docker image for AmneziaWG
   - Tag with version and latest
   - Push to Docker Hub: `ishumilin/amnezia-awg:latest`
   - Push to GHCR: `ghcr.io/ishumilin/amnezia-awg:latest`

### Manual Build

If you need to build manually:

```bash
cd amnezia-containers/awg

# Build for ARM64
docker buildx build --platform linux/arm64 \
    -t ishumilin/amnezia-awg:arm64 \
    -t ishumilin/amnezia-awg:latest \
    --push \
    .
```

## 🧪 Testing Locally

Use docker-compose for local testing:

```bash
cd amnezia-containers
docker-compose up -d
```

This will start the AmneziaWG container locally for testing.

## 📦 Image Registry

Images are published to:
- **Docker Hub**: `ishumilin/amnezia-awg:latest`
- **GitHub Container Registry**: `ghcr.io/ishumilin/amnezia-awg:latest`

## 🔄 Release Process

1. **Update version** in relevant files
2. **Build images** using `build.sh`
3. **Test images** locally with docker-compose
4. **Push to registries** (done automatically by build.sh)
5. **Update CHANGELOG.md** with changes
6. **Copy public files** to `public-dist/`
7. **Push to public repository**

## 📝 Public Distribution

The `public-dist/` directory contains files for the public repository:
- User-facing documentation
- Deployment scripts
- Setup scripts

To update the public repository:

```bash
# Copy updated files to public-dist/
cp README.md LICENSE CHANGELOG.md deploy-to-aws.sh setup-amnezia-arm64.sh public-dist/

# Then push public-dist/ contents to the public repository
```

## 🔐 Security Notes

- Never commit Docker Hub credentials
- Keep build secrets in environment variables
- This repository should remain private
- Only deployment scripts go to public repository

## 🛠️ Maintenance

### Updating Source Code

1. **AmneziaWG daemon** (`amneziawg-go/`):
   - Pull latest from upstream: https://github.com/amnezia-vpn/amneziawg-go
   - Apply any ARM64-specific patches if needed
   - Rebuild and test

2. **AmneziaWG tools** (`amneziawg-tools/`):
   - Pull latest from upstream: https://github.com/amnezia-vpn/amneziawg-tools
   - Rebuild for ARM64
   - Test key generation and configuration

### Updating Docker Images

1. Update Dockerfile if needed
2. Update start.sh scripts if needed
3. Rebuild images
4. Test thoroughly
5. Push to registries

## 📚 References

- [Amnezia VPN](https://amnezia.org)
- [AmneziaWG Go](https://github.com/amnezia-vpn/amneziawg-go)
- [AmneziaWG Tools](https://github.com/amnezia-vpn/amneziawg-tools)
- [Docker Buildx](https://docs.docker.com/buildx/working-with-buildx/)

## 🤝 Contributing

This is a private build repository. For public contributions, direct users to the public deployment repository.
