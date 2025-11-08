# Amnezia AWG Container for ARM64
# Based on official Amnezia container structure

FROM ishumilin/amneziawg-go:arm64

# Install required dependencies
# Note: Do NOT install wireguard-tools as it may overwrite AmneziaWG binaries
# The base image (ishumilin/amneziawg-go:arm64) already includes all necessary AmneziaWG tools
RUN apk add --no-cache \
    dumb-init \
    iptables \
    ip6tables \
    iproute2 \
    bash

# Create Amnezia directory structure
RUN mkdir -p /opt/amnezia/awg

# Copy startup script
COPY start.sh /opt/amnezia/start.sh
RUN chmod +x /opt/amnezia/start.sh

# Set working directory
WORKDIR /opt/amnezia

# Expose WireGuard port
EXPOSE 33911/udp

# Add maintainer label
LABEL maintainer="AmneziaVPN"

# Use dumb-init as entrypoint
ENTRYPOINT ["dumb-init", "/opt/amnezia/start.sh"]
CMD [""]
