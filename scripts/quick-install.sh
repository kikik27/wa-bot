#!/bin/bash

# Quick setup script for wa-bot on fresh Linux VPS
# Run: curl -sSL https://raw.githubusercontent.com/your-repo/wa-bot/main/scripts/quick-install.sh | bash

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log_error "Please run this script as a regular user with sudo privileges, not as root"
    exit 1
fi

log_info "Starting wa-bot quick installation..."

# Update system
log_info "Updating system packages..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y curl wget git nano htop fail2ban ufw
elif command -v yum &> /dev/null; then
    sudo yum update -y
    sudo yum install -y curl wget git nano htop fail2ban firewalld
else
    log_error "Unsupported package manager. Please install Docker manually."
    exit 1
fi

# Install Docker
log_info "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
fi

# Install Docker Compose
log_info "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Clone repository (if not already cloned)
if [[ ! -d wa-bot ]]; then
    log_info "Cloning wa-bot repository..."
    git clone https://github.com/your-username/wa-bot.git
    cd wa-bot
else
    log_info "Repository already exists, updating..."
    cd wa-bot
    git pull origin main
fi

# Setup environment
log_info "Setting up environment..."
if [[ ! -f .env ]]; then
    cp .env.example .env
    log_warning "Please edit the .env file with your configuration:"
    echo "  - Set your domain name"
    echo "  - Configure Telegram bot token (if needed)"
    echo "  - Set strong passwords"
    read -p "Press Enter to continue after editing .env file..."
    nano .env
fi

# Make scripts executable
chmod +x scripts/*.sh

# Configure firewall
log_info "Configuring firewall..."
if command -v ufw &> /dev/null; then
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw --force enable
fi

# Start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Initialize deployment
log_info "Initializing wa-bot deployment..."
./scripts/deploy.sh init

log_success "wa-bot installation completed!"
echo
log_info "Next steps:"
echo "1. Edit .env file: nano .env"
echo "2. Start services: ./scripts/deploy.sh start"
echo "3. Setup SSL: ./scripts/deploy.sh ssl"
echo "4. Check status: ./scripts/deploy.sh status"
echo
log_warning "You may need to log out and log back in for Docker group membership to take effect."