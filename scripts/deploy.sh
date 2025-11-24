#!/bin/bash

# WA-Bot Deployment Script for Linux VPS
# Usage: ./deploy.sh [init|start|stop|restart|update|logs|backup|ssl]

set -e

# Configuration
PROJECT_NAME="wa-bot"
COMPOSE_FILE="docker-compose.yml"
BACKUP_DIR="/opt/backups/wa-bot"
DOMAIN="${DOMAIN:-your-domain.com}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. Consider using a non-root user with sudo privileges."
    fi
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running. Please start Docker service."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Initialize system for first deployment
init_system() {
    log_info "Initializing system for wa-bot deployment..."
    
    # Create necessary directories
    sudo mkdir -p /opt/wa-bot/{ssl,backups,logs}
    sudo mkdir -p /var/www/html/.well-known/acme-challenge
    
    # Set permissions
    sudo chown -R $USER:$USER /opt/wa-bot
    sudo chmod -R 755 /opt/wa-bot
    
    # Create .env if it doesn't exist
    if [[ ! -f .env ]]; then
        log_warning "Creating .env from template"
        cp .env.example .env
        log_warning "Please edit .env file with your configuration before continuing"
        nano .env
    fi
    
    # Install additional tools
    log_info "Installing additional tools..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y curl wget nano htop fail2ban ufw
    elif command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum install -y curl wget nano htop fail2ban firewalld
    fi
    
    # Configure firewall
    configure_firewall
    
    log_success "System initialization completed"
}

# Configure firewall
configure_firewall() {
    log_info "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian
        sudo ufw --force reset
        sudo ufw default deny incoming
        sudo ufw default allow outgoing
        sudo ufw allow ssh
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        sudo ufw --force enable
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL
        sudo systemctl enable firewalld
        sudo systemctl start firewalld
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --reload
    fi
    
    log_success "Firewall configured"
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    log_info "Setting up SSL certificate with Let's Encrypt..."
    
    # Check if domain is configured
    if [[ "$DOMAIN" == "your-domain.com" ]]; then
        log_error "Please configure your domain in .env file first"
        exit 1
    fi
    
    # Install certbot
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y certbot
    elif command -v yum &> /dev/null; then
        sudo yum install -y epel-release
        sudo yum install -y certbot
    fi
    
    # Stop nginx temporarily
    docker-compose stop nginx 2>/dev/null || true
    
    # Generate certificate
    sudo certbot certonly --standalone \
        --agree-tos \
        --no-eff-email \
        --email "${LETSENCRYPT_EMAIL:-admin@$DOMAIN}" \
        -d "$DOMAIN" \
        -d "www.$DOMAIN"
    
    # Copy certificates to project ssl directory
    sudo cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem ./ssl/cert.pem
    sudo cp /etc/letsencrypt/live/$DOMAIN/privkey.pem ./ssl/private.key
    sudo chown $USER:$USER ./ssl/*
    
    # Enable SSL configuration
    if [[ -f nginx/conf.d/wa-bot-ssl.conf.disabled ]]; then
        mv nginx/conf.d/wa-bot-ssl.conf.disabled nginx/conf.d/wa-bot-ssl.conf
        # Update domain in SSL config
        sed -i "s/your-domain.com/$DOMAIN/g" nginx/conf.d/wa-bot-ssl.conf
        sed -i "s/your-domain.com/$DOMAIN/g" nginx/conf.d/wa-bot.conf
    fi
    
    # Setup auto-renewal
    (sudo crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'docker-compose restart nginx'") | sudo crontab -
    
    log_success "SSL certificate installed and configured"
}

# Build and start services
start_services() {
    log_info "Starting wa-bot services..."
    
    # Pull latest images
    docker-compose pull
    
    # Build application image
    docker-compose build --no-cache
    
    # Start services
    docker-compose up -d
    
    # Wait for services to be healthy
    log_info "Waiting for services to be ready..."
    sleep 30
    
    # Check service health
    check_health
    
    log_success "Services started successfully"
}

# Stop services
stop_services() {
    log_info "Stopping wa-bot services..."
    docker-compose down
    log_success "Services stopped"
}

# Restart services
restart_services() {
    log_info "Restarting wa-bot services..."
    docker-compose restart
    sleep 30
    check_health
    log_success "Services restarted successfully"
}

# Update application
update_application() {
    log_info "Updating wa-bot application..."
    
    # Backup current data
    backup_data
    
    # Pull latest code (if using git)
    if [[ -d .git ]]; then
        git pull origin main
    fi
    
    # Rebuild and restart
    docker-compose down
    docker-compose pull
    docker-compose build --no-cache
    docker-compose up -d
    
    # Wait and check health
    sleep 30
    check_health
    
    log_success "Application updated successfully"
}

# Check service health
check_health() {
    log_info "Checking service health..."
    
    # Check if containers are running
    if ! docker-compose ps | grep -q "Up"; then
        log_error "Some services are not running"
        docker-compose logs
        exit 1
    fi
    
    # Check application health
    for i in {1..10}; do
        if curl -f http://localhost/health &>/dev/null; then
            log_success "Application is healthy"
            return 0
        fi
        log_info "Waiting for application... (attempt $i/10)"
        sleep 5
    done
    
    log_warning "Application health check failed, but services are running"
    log_info "You may need to check logs: docker-compose logs"
}

# View logs
view_logs() {
    local service=${1:-}
    if [[ -n "$service" ]]; then
        docker-compose logs -f "$service"
    else
        docker-compose logs -f
    fi
}

# Backup data
backup_data() {
    log_info "Creating backup..."
    
    local backup_timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/$backup_timestamp"
    
    mkdir -p "$backup_path"
    
    # Backup WhatsApp sessions
    if docker volume ls | grep -q wa-sessions; then
        docker run --rm \
            -v wa-bot_wa-sessions:/source:ro \
            -v "$backup_path":/backup \
            alpine tar czf /backup/wa-sessions.tar.gz -C /source .
    fi
    
    # Backup application logs
    if docker volume ls | grep -q app-logs; then
        docker run --rm \
            -v wa-bot_app-logs:/source:ro \
            -v "$backup_path":/backup \
            alpine tar czf /backup/app-logs.tar.gz -C /source .
    fi
    
    # Backup configuration
    cp .env "$backup_path/"
    cp -r nginx/ "$backup_path/"
    
    # Create backup info
    echo "Backup created: $(date)" > "$backup_path/backup_info.txt"
    echo "Git commit: $(git rev-parse HEAD 2>/dev/null || echo 'N/A')" >> "$backup_path/backup_info.txt"
    
    # Clean old backups (keep last 7 days)
    find "$BACKUP_DIR" -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    
    log_success "Backup created at $backup_path"
}

# Show status
show_status() {
    log_info "WA-Bot Service Status:"
    echo
    docker-compose ps
    echo
    log_info "Resource Usage:"
    docker stats --no-stream
    echo
    log_info "Recent Logs:"
    docker-compose logs --tail=20
}

# Show help
show_help() {
    cat << EOF
WA-Bot VPS Deployment Script

Usage: $0 [COMMAND]

Commands:
  init      Initialize system for first deployment
  start     Start all services
  stop      Stop all services
  restart   Restart all services
  update    Update application and restart
  ssl       Setup SSL certificate with Let's Encrypt
  logs      View logs (add service name for specific service)
  backup    Create backup of data and configuration
  status    Show service status and resource usage
  help      Show this help message

Examples:
  $0 init               # First time setup
  $0 start              # Start all services
  $0 logs nginx         # View nginx logs
  $0 backup             # Create backup
  $0 ssl                # Setup SSL certificate

Environment Variables:
  DOMAIN                # Your domain name
  LETSENCRYPT_EMAIL     # Email for Let's Encrypt
EOF
}

# Main script
case "${1:-help}" in
    init)
        check_root
        check_prerequisites
        init_system
        ;;
    start)
        check_prerequisites
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    update)
        update_application
        ;;
    ssl)
        setup_ssl
        ;;
    logs)
        view_logs "$2"
        ;;
    backup)
        backup_data
        ;;
    status)
        show_status
        ;;
    help|--help|-h|*)
        show_help
        ;;
esac