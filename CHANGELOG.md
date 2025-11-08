# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-11-08

### Added
- **ARM64 Support**: Complete ARM64 (aarch64) support for Amnezia VPN
  - Native ARM64 Docker images for AWS Graviton2/3 instances
  - Optimized for cost-effective deployment (~20% savings vs x86)
  
- **Docker Images**:
  - `ishumilin/amneziawg-go:latest` - Base ARM64 image with AmneziaWG Go implementation
  - `ishumilin/amnezia-awg:latest` - Complete Amnezia AWG container for ARM64
  - Multi-registry support (Docker Hub and GitHub Container Registry)
  
- **Deployment Tools**:
  - `deploy-to-aws.sh` - Automated AWS EC2 deployment script
    - Support for all AWS regions
    - Configurable instance types (t4g.micro, t4g.small, etc.)
    - Automatic security group creation
    - SSH key management
    - Cost estimation
    - Dry-run mode for testing
  - `setup-amnezia-arm64.sh` - Server setup script
    - Docker installation and configuration
    - Local registry setup for transparent image serving
    - Automatic image pulling and configuration
  
- **Build System**:
  - `amnezia-containers/build.sh` - Automated multi-platform build script
  - Support for building and pushing to multiple registries
  - ARM64-optimized Dockerfiles
  
- **Documentation**:
  - Comprehensive README with setup instructions
  - BUILD.md with detailed build instructions
  - TESTING_GUIDE.md with complete testing workflow
  - REPOSITORY_ORGANIZATION.md explaining project structure
  - API documentation and usage examples

### Features
- **Transparent Image Serving**: Local Docker registry configured to serve ARM64 images
  - Amnezia VPN app works without modifications
  - Automatic image substitution for official images
  - No changes needed to client configuration
  
- **AWS Integration**:
  - One-command deployment to AWS EC2
  - Support for AWS Graviton2/3 processors (t4g instances)
  - Automatic AMI selection for Ubuntu 22.04 ARM64
  - Security group configuration with proper ports
  - Cost-optimized instance selection
  
- **Production Ready**:
  - Tested and verified complete workflow
  - All images published to public registries
  - Comprehensive error handling
  - Detailed logging and monitoring support

### Technical Details
- **Base Image**: Alpine Linux 3.19 (ARM64)
- **Go Version**: 1.24.4
- **Docker Version**: 28.5.2+
- **Supported Protocols**: AmneziaWG
- **Architecture**: linux/arm64 (aarch64)

### Compatibility
- **AWS Instances**: t4g.micro, t4g.small, t4g.medium, and all Graviton-based instances
- **Operating Systems**: Ubuntu 22.04 LTS ARM64 (tested), other ARM64 Linux distributions (should work)
- **Amnezia VPN App**: All versions supporting custom server deployment
- **Docker**: 20.10+ (tested with 28.5.2)

### Performance
- **Image Sizes**:
  - Base image (amneziawg-go): ~9.4 MB
  - Main image (amnezia-awg): ~29.8 MB
- **Build Time**: ~40 seconds total
- **Deployment Time**: ~3-5 minutes (including server setup)

### Cost Savings
- **t4g.micro**: ~$6-9/month (vs ~$8-12 for t3.micro)
- **t4g.small**: ~$12-15/month (vs ~$15-19 for t3.small)
- Approximately 20% cost reduction compared to x86 instances

### Security
- Minimal attack surface with Alpine Linux base
- No unnecessary packages installed
- Security group with restricted access
- SSH key-based authentication only
- Regular security updates supported

### Known Limitations
- ARM64 only (x86 not supported in this build)
- Requires Docker 20.10 or newer
- AWS deployment script requires AWS CLI v2
- Local registry requires port 5000 to be available

### Credits
- Based on [Amnezia VPN](https://github.com/amnezia-vpn) project
- Uses [AmneziaWG](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module) protocol
- Built for AWS Graviton processors

---

## Release Notes

This is the first stable release of Amnezia VPN ARM64 support. All components have been tested and verified to work correctly with the official Amnezia VPN client applications.

### Upgrade Path
This is the initial release. No upgrade path needed.

### Breaking Changes
None (initial release).

### Deprecations
None.

---

[1.0.0]: https://github.com/ishumilin/amnezia-arm64/releases/tag/v1.0.0
