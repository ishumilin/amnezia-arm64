#!/bin/bash

#############################################################################
# Amnezia VPN AWS Deployment Script (ARM64 Support)
# 
# This script deploys Amnezia VPN on AWS EC2 ARM64 instances (t4g family)
# Run from your LOCAL machine (not on the server)
#
# ARM64 SUPPORT:
#   The official Amnezia VPN app only provides x86_64 Docker images.
#   This deployment uses custom ARM64 images (ishumilin/amnezia-*)
#   with a local Docker registry to intercept and serve ARM64 images.
#
# Usage: ./deploy-to-aws.sh [OPTIONS]
#
# Requirements:
#   - AWS CLI installed and configured
#   - SSH client
#   - Internet connection
#   - setup-amnezia-arm64.sh in the same directory
#############################################################################

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
DEFAULT_REGION="eu-west-1"
DEFAULT_INSTANCE_TYPE="t4g.small"
DEFAULT_KEY_NAME="amnezia-vpn-key"
DEFAULT_VOLUME_SIZE="8"
DEFAULT_INSTANCE_NAME="Amnezia-VPN-Server"

# Configuration variables (can be overridden by command-line args)
AWS_REGION="${AWS_REGION:-$DEFAULT_REGION}"
INSTANCE_TYPE="${INSTANCE_TYPE:-$DEFAULT_INSTANCE_TYPE}"
KEY_NAME="${KEY_NAME:-$DEFAULT_KEY_NAME}"
VOLUME_SIZE="${VOLUME_SIZE:-$DEFAULT_VOLUME_SIZE}"
INSTANCE_NAME="${INSTANCE_NAME:-$DEFAULT_INSTANCE_NAME}"
ALLOW_SSH_FROM=""
DRY_RUN=false
DESTROY=false

# Resource tracking
SECURITY_GROUP_ID=""
INSTANCE_ID=""
PUBLIC_IP=""

#############################################################################
# Helper Functions
#############################################################################

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

show_help() {
    cat << EOF
Amnezia VPN AWS Deployment Script

Usage: $0 [OPTIONS]

Options:
    --region REGION          AWS region (default: eu-west-1)
    --instance-type TYPE     Instance type (default: t4g.small)
    --key-name NAME          SSH key pair name (default: amnezia-vpn-key)
    --volume-size SIZE       Root volume size in GB (default: 20)
    --instance-name NAME     Instance name tag (default: Amnezia-VPN-Server)
    --allow-ssh-from CIDR    SSH access CIDR (default: your current IP)
    --dry-run                Show what would be created without creating
    --destroy                Destroy all created resources
    --help                   Show this help message

Examples:
    # Basic deployment
    $0

    # Custom region and instance type
    $0 --region us-east-1 --instance-type t4g.micro

    # Destroy resources
    $0 --destroy

    # Dry run
    $0 --dry-run

EOF
    exit 0
}

#############################################################################
# Prerequisite Checks
#############################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install it first:"
        echo "  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    print_success "AWS CLI installed: $(aws --version | cut -d' ' -f1)"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Run: aws configure"
        exit 1
    fi
    local aws_account=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS credentials configured (Account: $aws_account)"
    
    # Check SSH
    if ! command -v ssh &> /dev/null; then
        print_error "SSH client not found"
        exit 1
    fi
    print_success "SSH client available"
    
    # Check jq (optional but helpful)
    if ! command -v jq &> /dev/null; then
        print_warning "jq not installed (optional, but recommended for better output)"
    else
        print_success "jq installed"
    fi
    
    echo ""
}

#############################################################################
# Get Current IP
#############################################################################

get_current_ip() {
    local ip=$(curl -s https://checkip.amazonaws.com)
    if [ -z "$ip" ]; then
        ip=$(curl -s https://api.ipify.org)
    fi
    echo "$ip"
}

#############################################################################
# Get Latest Ubuntu ARM64 AMI
#############################################################################

get_ubuntu_ami() {
    print_info "Finding latest Ubuntu 22.04 ARM64 AMI in $AWS_REGION..." >&2
    
    local ami_id=$(aws ec2 describe-images \
        --region "$AWS_REGION" \
        --owners 099720109477 \
        --filters \
            "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*" \
            "Name=state,Values=available" \
            "Name=architecture,Values=arm64" \
        --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
        --output text)
    
    if [ -z "$ami_id" ] || [ "$ami_id" == "None" ]; then
        print_error "Could not find Ubuntu 22.04 ARM64 AMI" >&2
        exit 1
    fi
    
    print_success "Found AMI: $ami_id" >&2
    echo "$ami_id"
}

#############################################################################
# Create Security Group
#############################################################################

create_security_group() {
    print_header "Creating Security Group"
    
    local sg_name="amnezia-vpn-sg-$(date +%s)"
    local sg_description="Security group for Amnezia VPN server"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would create security group: $sg_name"
        SECURITY_GROUP_ID="sg-dryrun123"
        return
    fi
    
    # Create security group
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --region "$AWS_REGION" \
        --group-name "$sg_name" \
        --description "$sg_description" \
        --query 'GroupId' \
        --output text)
    
    print_success "Created security group: $SECURITY_GROUP_ID"
    
    # Get current IP if not specified
    if [ -z "$ALLOW_SSH_FROM" ]; then
        ALLOW_SSH_FROM="0.0.0.0/0"
        print_info "Allowing SSH from anywhere (0.0.0.0/0)"
        print_warning "For better security, use: --allow-ssh-from YOUR_IP/32"
    fi
    
    # Add SSH rule
    aws ec2 authorize-security-group-ingress \
        --region "$AWS_REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 22 \
        --cidr "$ALLOW_SSH_FROM" \
        --group-name "$sg_name" > /dev/null
    print_success "Added SSH rule (22/tcp from $ALLOW_SSH_FROM)"
    
    # Add AmneziaWG rule
    aws ec2 authorize-security-group-ingress \
        --region "$AWS_REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol udp \
        --port 33911 \
        --cidr 0.0.0.0/0 \
        --group-name "$sg_name" > /dev/null
    print_success "Added AmneziaWG rule (33911/udp from anywhere)"
    
    # Tag security group
    aws ec2 create-tags \
        --region "$AWS_REGION" \
        --resources "$SECURITY_GROUP_ID" \
        --tags "Key=Name,Value=amnezia-vpn-sg" "Key=Project,Value=AmneziaVPN" > /dev/null
    
    echo ""
}

#############################################################################
# Create or Import SSH Key Pair
#############################################################################

setup_ssh_key() {
    print_header "Setting Up SSH Key Pair"
    
    local key_file="$HOME/.ssh/${KEY_NAME}.pem"
    
    # Check if key already exists in AWS
    if aws ec2 describe-key-pairs --region "$AWS_REGION" --key-names "$KEY_NAME" &> /dev/null; then
        print_info "Key pair '$KEY_NAME' already exists in AWS"
        
        if [ -f "$key_file" ]; then
            print_success "Local key file found: $key_file"
        else
            print_warning "Key exists in AWS but not found locally at: $key_file"
            print_warning "You may need to specify an existing key or create a new one"
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            print_info "[DRY RUN] Would create key pair: $KEY_NAME"
            return
        fi
        
        print_info "Creating new key pair: $KEY_NAME"
        
        # Create key pair and save to file
        aws ec2 create-key-pair \
            --region "$AWS_REGION" \
            --key-name "$KEY_NAME" \
            --query 'KeyMaterial' \
            --output text > "$key_file"
        
        chmod 600 "$key_file"
        print_success "Created and saved key pair to: $key_file"
    fi
    
    echo ""
}

#############################################################################
# Launch EC2 Instance
#############################################################################

launch_instance() {
    print_header "Launching EC2 Instance"
    
    local ami_id=$(get_ubuntu_ami)
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would launch instance with:"
        echo "  Region: $AWS_REGION"
        echo "  Instance Type: $INSTANCE_TYPE"
        echo "  AMI: $ami_id"
        echo "  Key Name: $KEY_NAME"
        echo "  Security Group: $SECURITY_GROUP_ID"
        echo "  Volume Size: ${VOLUME_SIZE}GB"
        INSTANCE_ID="i-dryrun123"
        PUBLIC_IP="1.2.3.4"
        return
    fi
    
    print_info "Launching $INSTANCE_TYPE instance..."
    print_info "Using AMI: $ami_id"
    print_info "Security Group: $SECURITY_GROUP_ID"
    
    # Launch instance (using AMI default volume size)
    INSTANCE_ID=$(aws ec2 run-instances \
        --region "$AWS_REGION" \
        --image-id "$ami_id" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SECURITY_GROUP_ID" \
        --query 'Instances[0].InstanceId' \
        --output text)
    
    # Check if instance ID is valid
    if [[ ! "$INSTANCE_ID" =~ ^i-[0-9a-f]+$ ]]; then
        print_error "Failed to launch instance: $INSTANCE_ID"
        exit 1
    fi
    
    print_success "Instance launched: $INSTANCE_ID"
    
    # Add tags to instance
    aws ec2 create-tags \
        --region "$AWS_REGION" \
        --resources "$INSTANCE_ID" \
        --tags "Key=Name,Value=AmneziaVPN-Server" "Key=Project,Value=AmneziaVPN" > /dev/null
    print_success "Tags added to instance"
    
    # Wait for instance to be running
    print_info "Waiting for instance to be running..."
    aws ec2 wait instance-running --region "$AWS_REGION" --instance-ids "$INSTANCE_ID"
    print_success "Instance is running"
    
    # Get public IP
    PUBLIC_IP=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    print_success "Public IP: $PUBLIC_IP"
    
    # Wait for SSH to be available
    print_info "Waiting for SSH to be available (this may take 1-2 minutes)..."
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$HOME/.ssh/${KEY_NAME}.pem" ubuntu@"$PUBLIC_IP" "echo 'SSH ready'" &> /dev/null; then
            print_success "SSH is available"
            break
        fi
        attempt=$((attempt + 1))
        sleep 10
    done
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "SSH did not become available in time"
        exit 1
    fi
    
    echo ""
}

#############################################################################
# Deploy Amnezia VPN
#############################################################################

deploy_amnezia() {
    print_header "Deploying Amnezia VPN"
    
    if [ "$DRY_RUN" = true ]; then
        print_info "[DRY RUN] Would deploy Amnezia VPN to instance"
        return
    fi
    
    local key_file="$HOME/.ssh/${KEY_NAME}.pem"
    local max_retries=3
    local retry_delay=10
    
    # Copy setup script to instance with retry logic
    print_info "Copying setup script to instance..."
    local copy_success=false
    for ((i=1; i<=max_retries; i++)); do
        if scp -o StrictHostKeyChecking=no -o ConnectTimeout=30 -i "$key_file" setup-amnezia-arm64.sh ubuntu@"$PUBLIC_IP":~/ > /dev/null 2>&1; then
            copy_success=true
            break
        else
            if [ $i -lt $max_retries ]; then
                print_warning "Copy failed (attempt $i/$max_retries), retrying in ${retry_delay}s..."
                sleep $retry_delay
            fi
        fi
    done
    
    if [ "$copy_success" = false ]; then
        print_error "Failed to copy setup script after $max_retries attempts"
        print_info "You can manually run: scp -i $key_file setup-amnezia-arm64.sh ubuntu@$PUBLIC_IP:~/"
        exit 1
    fi
    print_success "Setup script copied"
    
    # Make script executable and run it with retry logic
    print_info "Running setup script on instance..."
    local run_success=false
    for ((i=1; i<=max_retries; i++)); do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 -i "$key_file" ubuntu@"$PUBLIC_IP" "chmod +x setup-amnezia-arm64.sh && ./setup-amnezia-arm64.sh" 2>&1; then
            run_success=true
            break
        else
            if [ $i -lt $max_retries ]; then
                print_warning "Setup script execution failed (attempt $i/$max_retries), retrying in ${retry_delay}s..."
                sleep $retry_delay
            fi
        fi
    done
    
    if [ "$run_success" = false ]; then
        print_error "Failed to run setup script after $max_retries attempts"
        print_info "You can manually run: ssh -i $key_file ubuntu@$PUBLIC_IP './setup-amnezia-arm64.sh'"
        exit 1
    fi
    
    print_success "Amnezia VPN deployed successfully!"
    
    echo ""
}

#############################################################################
# Show Connection Info
#############################################################################

show_connection_info() {
    print_header "Connection Information"
    
    echo -e "${GREEN}✓ Deployment Complete!${NC}"
    echo ""
    echo "Instance Details:"
    echo "  Instance ID: $INSTANCE_ID"
    echo "  Public IP: $PUBLIC_IP"
    echo "  Region: $AWS_REGION"
    echo "  Instance Type: $INSTANCE_TYPE"
    echo ""
    echo "SSH Connection:"
    echo "  ssh -i ~/.ssh/${KEY_NAME}.pem ubuntu@$PUBLIC_IP"
    echo ""
    echo "Next Steps:"
    echo "  1. Download Amnezia VPN app from https://amnezia.org/downloads"
    echo "  2. Open the app and click 'Add server'"
    echo "  3. Select 'I have the data to connect'"
    echo "  4. Enter connection details:"
    echo "     - IP: $PUBLIC_IP"
    echo "     - SSH Port: 22"
    echo "     - Username: ubuntu"
    echo "     - SSH Key: ~/.ssh/${KEY_NAME}.pem"
    echo "  5. Select protocols (AmneziaWG recommended)"
    echo "  6. Click 'Install'"
    echo ""
    echo "💰 Estimated Monthly Cost: ~\$15-19"
    echo ""
}

#############################################################################
# Show Cost Estimate
#############################################################################

show_cost_estimate() {
    print_header "Cost Estimate"
    
    echo "Monthly costs for $INSTANCE_TYPE in $AWS_REGION:"
    echo ""
    echo "  Instance (t4g.small):     ~\$12/month"
    echo "  Storage (${VOLUME_SIZE}GB gp3):      ~\$2/month"
    echo "  Data transfer:            ~\$1-5/month (varies)"
    echo "  ─────────────────────────────────────"
    echo "  Total:                    ~\$15-19/month"
    echo ""
    echo "Note: Actual costs may vary based on usage and data transfer."
    echo ""
}

#############################################################################
# Destroy Resources
#############################################################################

destroy_resources() {
    print_header "Destroying Resources"
    
    print_warning "This will destroy all Amnezia VPN resources in $AWS_REGION"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Destruction cancelled"
        exit 0
    fi
    
    # Find instances with AmneziaVPN tag
    local instances=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Project,Values=AmneziaVPN" "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text)
    
    if [ -n "$instances" ]; then
        print_info "Terminating instances: $instances"
        aws ec2 terminate-instances --region "$AWS_REGION" --instance-ids $instances > /dev/null
        print_success "Instances terminated"
        
        # Wait for termination
        print_info "Waiting for instances to terminate..."
        aws ec2 wait instance-terminated --region "$AWS_REGION" --instance-ids $instances
        print_success "Instances terminated"
    else
        print_info "No instances found"
    fi
    
    # Find and delete security groups
    local security_groups=$(aws ec2 describe-security-groups \
        --region "$AWS_REGION" \
        --filters "Name=tag:Project,Values=AmneziaVPN" \
        --query 'SecurityGroups[].GroupId' \
        --output text)
    
    if [ -n "$security_groups" ]; then
        for sg in $security_groups; do
            print_info "Deleting security group: $sg"
            aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$sg" 2>/dev/null || print_warning "Could not delete $sg (may be in use)"
        done
    else
        print_info "No security groups found"
    fi
    
    print_success "Cleanup complete"
    echo ""
}

#############################################################################
# Parse Command Line Arguments
#############################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --region)
                AWS_REGION="$2"
                shift 2
                ;;
            --instance-type)
                INSTANCE_TYPE="$2"
                shift 2
                ;;
            --key-name)
                KEY_NAME="$2"
                shift 2
                ;;
            --volume-size)
                VOLUME_SIZE="$2"
                shift 2
                ;;
            --instance-name)
                INSTANCE_NAME="$2"
                shift 2
                ;;
            --allow-ssh-from)
                ALLOW_SSH_FROM="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --destroy)
                DESTROY=true
                shift
                ;;
            --help)
                show_help
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                ;;
        esac
    done
}

#############################################################################
# Main Function
#############################################################################

main() {
    parse_args "$@"
    
    # Show banner
    echo ""
    print_header "Amnezia VPN AWS Deployment"
    echo ""
    
    # Handle destroy mode
    if [ "$DESTROY" = true ]; then
        destroy_resources
        exit 0
    fi
    
    # Show configuration
    echo "Configuration:"
    echo "  Region: $AWS_REGION"
    echo "  Instance Type: $INSTANCE_TYPE"
    echo "  Key Name: $KEY_NAME"
    echo "  Volume Size: ${VOLUME_SIZE}GB"
    echo "  Instance Name: $INSTANCE_NAME"
    if [ "$DRY_RUN" = true ]; then
        echo "  Mode: DRY RUN"
    fi
    echo ""
    
    # Run deployment
    check_prerequisites
    show_cost_estimate
    
    if [ "$DRY_RUN" = false ]; then
        read -p "Continue with deployment? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            print_info "Deployment cancelled"
            exit 0
        fi
        echo ""
    fi
    
    create_security_group
    setup_ssh_key
    launch_instance
    deploy_amnezia
    show_connection_info
    
    print_success "All done! 🎉"
}

# Run main function
main "$@"
