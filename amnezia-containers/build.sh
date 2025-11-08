#!/bin/bash

# Build script for Amnezia ARM64 containers
# This script builds complete Amnezia containers for ARM64 architecture

set -e

DOCKER_USERNAME="ishumilin"
GHCR_USERNAME="ishumilin"

echo "=========================================="
echo "Building Amnezia ARM64 Containers"
echo "=========================================="

# Build AWG container
echo ""
echo "Building Amnezia AWG container..."
cd awg
docker buildx build --platform linux/arm64 \
    -t ${DOCKER_USERNAME}/amnezia-awg:arm64 \
    -t ${DOCKER_USERNAME}/amnezia-awg:latest \
    -t ghcr.io/${GHCR_USERNAME}/amnezia-awg:arm64 \
    -t ghcr.io/${GHCR_USERNAME}/amnezia-awg:latest \
    --push \
    .
cd ..

echo "✓ Amnezia AWG container built and pushed"

echo ""
echo "=========================================="
echo "Build Complete!"
echo "=========================================="
echo ""
echo "Images pushed to:"
echo "  - docker.io/${DOCKER_USERNAME}/amnezia-awg:latest"
echo "  - docker.io/${DOCKER_USERNAME}/amnezia-awg:arm64"
echo "  - ghcr.io/${GHCR_USERNAME}/amnezia-awg:latest"
echo "  - ghcr.io/${GHCR_USERNAME}/amnezia-awg:arm64"
echo ""
echo "These containers work exactly like the official Amnezia containers!"
echo "Just mount your configs and run with docker-compose."
