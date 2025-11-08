# Amnezia ARM64 Containers

Complete ARM64 Docker containers for Amnezia VPN, optimized for AWS Graviton processors.

## Available Images

### Docker Hub
- **amnezia-awg**: Complete AWG (AmneziaWG) container for ARM64

```bash
docker pull ishumilin/amnezia-awg:latest
```

### GitHub Container Registry

```bash
docker pull ghcr.io/ishumilin/amnezia-awg:latest
```

## Quick Start

### 1. Create Directory Structure

```bash
# Create directory structure
mkdir -p configs/awg

# Copy your WireGuard config
cp /path/to/your/wg0.conf configs/awg/
```

### 2. Deploy with Docker Compose

```bash
docker-compose up -d
```

## Directory Structure

```
amnezia-containers/
├── awg/
│   ├── Dockerfile          # AWG container definition
│   └── start.sh           # AWG startup script
├── configs/               # Your VPN configs go here
│   └── awg/
│       └── wg0.conf       # WireGuard config
├── docker-compose.yml     # Easy deployment
└── build.sh              # Build script
```

## Configuration

### AWG (AmneziaWG) Config

Place your `wg0.conf` in `configs/awg/`:

```ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.8.1.1/24
ListenPort = 33911
Jc = 3
Jmin = 50
Jmax = 1000
S1 = 86
S2 = 15
H1 = 1
H2 = 2
H3 = 3
H4 = 4

[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = 10.8.1.2/32
```

## Container Details

### AWG Container

- **Base**: `ishumilin/amneziawg-go:latest`
- **Port**: 33911/udp
- **Volumes**:
  - `/lib/modules` → `/lib/modules` (read-only)
  - `./configs/awg` → `/opt/amnezia/awg`
- **Capabilities**: NET_ADMIN, SYS_MODULE
- **Sysctls**:
  - `net.ipv4.conf.all.src_valid_mark=1`
  - `net.ipv4.ip_forward=1`

## Management

### View Logs

```bash
docker-compose logs -f amnezia-awg
```

### Restart Services

```bash
docker-compose restart
```

### Stop Services

```bash
docker-compose down
```

### Extract Config

```bash
# Extract AWG config
docker cp amnezia-awg:/opt/amnezia/awg/wg0.conf ./
```

## Troubleshooting

### Check Container Status

```bash
docker-compose ps
```

### AWG not working

```bash
# Check if config exists
ls -la configs/awg/wg0.conf

# Check container logs
docker-compose logs amnezia-awg

# Verify kernel module
lsmod | grep wireguard
```

### Port Already in Use

If port 33911 is already in use, modify `docker-compose.yml`:

```yaml
ports:
  - "YOUR_PORT:33911/udp"
```

## Building from Source

```bash
# Build and push to registries
./build.sh
```

This will build and push to both Docker Hub and GitHub Container Registry.

## Architecture

- **Platform**: linux/arm64 (aarch64)
- **Base Image**: Alpine Linux 3.19
- **Go Version**: 1.24.4
- **Docker Version**: 28.5.2+

## Performance

- **Image Size**: ~30 MB (compressed)
- **Memory Usage**: ~50-100 MB
- **CPU Usage**: Minimal (<5% on t4g.micro)

## Security

- Minimal attack surface with Alpine Linux
- No unnecessary packages
- Runs with required capabilities only
- Regular security updates

## Credits

- [AmneziaWG](https://github.com/amnezia-vpn/amneziawg-go) - MIT License
- [Amnezia VPN](https://github.com/amnezia-vpn) - Various licenses

## Links

- [Docker Hub - AWG](https://hub.docker.com/r/ishumilin/amnezia-awg)
- [GitHub Container Registry](https://github.com/ishumilin?tab=packages)
- [Main Repository](https://github.com/ishumilin/amnezia-arm64)

## License

MIT License - See LICENSE file for details
