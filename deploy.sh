#!/bin/bash

# Deploy script untuk VPS Linux
# Usage: ./deploy.sh

set -e

PROJECT_NAME="wa-bot"
DOMAIN="your-domain.com"  # Ganti dengan domain Anda

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_error "Jangan jalankan script ini sebagai root!"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    print_status "Installing system dependencies..."
    
    sudo apt update
    sudo apt install -y \
        docker.io \
        docker-compose \
        nginx \
        certbot \
        python3-certbot-nginx \
        curl \
        git \
        ufw
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    print_success "Dependencies installed"
}

# Setup firewall
setup_firewall() {
    print_status "Configuring firewall..."
    
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow 80
    sudo ufw allow 443
    sudo ufw --force enable
    
    print_success "Firewall configured"
}

# Setup nginx
setup_nginx() {
    print_status "Configuring Nginx..."
    
    # Backup original nginx config
    sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    
    # Copy our nginx configs
    sudo cp nginx-main.conf /etc/nginx/nginx.conf
    sudo cp nginx-vps.conf /etc/nginx/sites-available/$PROJECT_NAME
    
    # Update domain in nginx config
    sudo sed -i "s/your-domain.com/$DOMAIN/g" /etc/nginx/sites-available/$PROJECT_NAME
    
    # Enable site
    sudo ln -sf /etc/nginx/sites-available/$PROJECT_NAME /etc/nginx/sites-enabled/
    
    # Remove default site
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx config
    sudo nginx -t
    
    # Start and enable nginx
    sudo systemctl start nginx
    sudo systemctl enable nginx
    
    print_success "Nginx configured"
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    print_status "Setting up SSL certificate..."
    
    # Get SSL certificate
    sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
    
    # Auto-renewal
    sudo systemctl enable certbot.timer
    
    print_success "SSL certificate installed"
}

# Deploy application
deploy_app() {
    print_status "Deploying wa-bot application..."
    
    # Copy production environment
    cp .env.production .env
    
    # Build and start container
    docker-compose down || true
    docker-compose build --no-cache
    docker-compose up -d
    
    # Wait for container to be ready
    print_status "Waiting for application to start..."
    sleep 30
    
    # Check if app is running
    if curl -f http://localhost:5000/ > /dev/null 2>&1; then
        print_success "Application is running"
    else
        print_error "Application failed to start"
        docker-compose logs
        exit 1
    fi
}

# Setup log rotation
setup_logrotate() {
    print_status "Setting up log rotation..."
    
    sudo tee /etc/logrotate.d/wa-bot > /dev/null <<EOF
$PWD/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        docker-compose restart wa-bot || true
    endscript
}
EOF
    
    print_success "Log rotation configured"
}

# Create systemd service for auto-start
setup_systemd() {
    print_status "Setting up systemd service..."
    
    sudo tee /etc/systemd/system/wa-bot.service > /dev/null <<EOF
[Unit]
Description=WhatsApp Bot
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$PWD
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable wa-bot
    
    print_success "Systemd service configured"
}

# Main deployment function
main() {
    print_status "Starting wa-bot deployment on VPS..."
    
    check_root
    
    # Check if domain is set
    if [ "$DOMAIN" = "your-domain.com" ]; then
        print_error "Please update DOMAIN variable in deploy.sh"
        exit 1
    fi
    
    install_dependencies
    setup_firewall
    setup_nginx
    deploy_app
    setup_logrotate
    setup_systemd
    
    print_success "Deployment completed!"
    print_status "Your wa-bot is now running at: http://$DOMAIN"
    print_warning "To enable HTTPS, run: sudo ./deploy.sh ssl"
    print_status "To view logs: docker-compose logs -f"
    print_status "To restart: sudo systemctl restart wa-bot"
}

# Handle SSL setup separately
if [ "$1" = "ssl" ]; then
    setup_ssl
    print_status "Updating nginx configuration for HTTPS..."
    sudo sed -i 's/#.*return 301 https/return 301 https/' /etc/nginx/sites-available/$PROJECT_NAME
    sudo sed -i 's/# server {/server {/' /etc/nginx/sites-available/$PROJECT_NAME
    sudo sed -i 's/# }/}/' /etc/nginx/sites-available/$PROJECT_NAME
    sudo nginx -s reload
    print_success "HTTPS enabled!"
    exit 0
fi

# Run main deployment
main