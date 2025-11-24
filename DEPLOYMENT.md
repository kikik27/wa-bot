# WA-Bot Production Deployment Guide

Panduan lengkap untuk deploy WA-Bot ke VPS Linux dengan Docker dan Nginx.

## 🚀 Quick Start

### Instalasi Otomatis
```bash
curl -sSL https://raw.githubusercontent.com/your-repo/wa-bot/main/scripts/quick-install.sh | bash
```

### Instalasi Manual
```bash
# Clone repository
git clone https://github.com/your-username/wa-bot.git
cd wa-bot

# Copy dan edit environment file
cp .env.example .env
nano .env

# Make scripts executable
chmod +x scripts/*.sh

# Initialize system
./scripts/deploy.sh init

# Start services
./scripts/deploy.sh start
```

## 📋 Prasyarat

### Sistem Operasi
- Ubuntu 20.04+ / CentOS 8+ / Debian 11+
- Minimal 2GB RAM, 2 CPU cores
- 20GB+ storage

### Software Requirements
- Docker & Docker Compose
- Git
- Nginx (akan dijalankan dalam container)

## ⚙️ Konfigurasi

### 1. Environment Variables (.env)
```bash
# Domain configuration
DOMAIN=your-domain.com
SUBDOMAIN=www

# Application settings
NODE_ENV=production
PORT=5000
WA_SESSION_NAME=wa-bot-production

# Security
REDIS_PASSWORD=your_strong_redis_password
JWT_SECRET=your_jwt_secret_minimum_32_chars

# SSL/Email
LETSENCRYPT_EMAIL=admin@your-domain.com
EMAIL_FROM=noreply@your-domain.com
EMAIL_TO=admin@your-domain.com
```

### 2. Domain Setup
Pastikan domain Anda mengarah ke IP VPS:
```
A     @          YOUR_VPS_IP
A     www        YOUR_VPS_IP
```

### 3. Firewall Configuration
```bash
# Ubuntu/Debian
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# CentOS/RHEL
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload
```

## 🔧 Deployment Commands

### Basic Operations
```bash
# Start services
./scripts/deploy.sh start

# Stop services
./scripts/deploy.sh stop

# Restart services
./scripts/deploy.sh restart

# View logs
./scripts/deploy.sh logs

# Check status
./scripts/deploy.sh status
```

### SSL Setup
```bash
# Setup Let's Encrypt SSL
./scripts/deploy.sh ssl
```

### Maintenance
```bash
# Update application
./scripts/deploy.sh update

# Create backup
./scripts/deploy.sh backup

# View specific service logs
./scripts/deploy.sh logs nginx
./scripts/deploy.sh logs wa-bot
```

## 🏗️ Struktur Deployment

### Docker Services
```
wa-bot-app      # Main Node.js application
wa-bot-nginx    # Nginx reverse proxy
wa-bot-redis    # Redis for session storage
watchtower      # Auto-update containers (optional)
```

### Directory Structure
```
/opt/wa-bot/
├── ssl/                    # SSL certificates
├── backups/               # Application backups
└── logs/                  # Application logs

/var/www/html/
└── .well-known/           # Let's Encrypt challenge
```

### Docker Volumes
```
wa-bot_wa-sessions         # WhatsApp session data
wa-bot_app-logs           # Application logs
wa-bot_nginx-logs         # Nginx logs
wa-bot_redis-data         # Redis data
```

## 🔐 SSL/HTTPS Configuration

### Automatic SSL (Recommended)
```bash
# Edit .env first to set your domain
./scripts/deploy.sh ssl
```

### Manual SSL
```bash
# Generate self-signed certificate (development only)
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/private.key -out ssl/cert.pem

# Enable SSL configuration
mv nginx/conf.d/wa-bot-ssl.conf.disabled nginx/conf.d/wa-bot-ssl.conf
docker-compose restart nginx
```

## 📊 Monitoring & Maintenance

### Health Checks
```bash
# Application health
curl http://your-domain.com/health

# Service status
./scripts/deploy.sh status

# Container logs
docker logs wa-bot-app -f
```

### Automated Monitoring
Setup crontab for automated monitoring:
```bash
# Edit crontab
crontab -e

# Add monitoring (every 5 minutes)
*/5 * * * * /opt/wa-bot/scripts/monitor.sh

# Add backup (daily at 2 AM)
0 2 * * * /opt/wa-bot/scripts/deploy.sh backup
```

### Log Management
Logs automatically rotate and clean up old files. Manual cleanup:
```bash
# Clean old Docker images
docker system prune -f

# Clean application logs
find /var/log -name "*wa-bot*" -type f -mtime +7 -delete
```

## 🔄 Updates & Backup

### Application Updates
```bash
# Automatic update (preserves data)
./scripts/deploy.sh update

# Manual update
git pull origin main
docker-compose build --no-cache
docker-compose up -d
```

### Backup & Restore
```bash
# Create backup
./scripts/deploy.sh backup

# Manual backup restore
BACKUP_PATH="/opt/backups/wa-bot/20241124_120000"
docker run --rm \
  -v wa-bot_wa-sessions:/target \
  -v "$BACKUP_PATH":/backup \
  alpine tar xzf /backup/wa-sessions.tar.gz -C /target
```

## 🚨 Troubleshooting

### Common Issues

#### WhatsApp Connection Failed
```bash
# Check container logs
docker logs wa-bot-app -f

# Restart WhatsApp service
docker restart wa-bot-app

# Clear session data (requires re-scan)
docker volume rm wa-bot_wa-sessions
```

#### Nginx 502 Bad Gateway
```bash
# Check if app container is running
docker ps | grep wa-bot-app

# Check app health
curl http://localhost:5000/

# Restart services
docker-compose restart
```

#### SSL Certificate Issues
```bash
# Check certificate validity
openssl x509 -in ssl/cert.pem -text -noout

# Renew Let's Encrypt certificate
sudo certbot renew
docker-compose restart nginx
```

#### Out of Disk Space
```bash
# Clean Docker system
docker system prune -af --volumes

# Clean old backups
find /opt/backups -type f -mtime +30 -delete

# Clean application logs
truncate -s 0 /var/log/wa-bot-monitor.log
```

### Performance Optimization

#### Memory Issues
```bash
# Monitor memory usage
docker stats

# Limit container memory in docker-compose.yml
services:
  wa-bot:
    mem_limit: 512m
    mem_reservation: 256m
```

#### CPU Issues
```bash
# Monitor CPU usage
htop

# Limit container CPU
services:
  wa-bot:
    cpu_count: 1
    cpu_percent: 50
```

## 🔧 Advanced Configuration

### Custom Nginx Configuration
Edit `nginx/conf.d/wa-bot.conf` for custom settings:
- Rate limiting
- Additional security headers
- Custom error pages
- Load balancing (multiple app instances)

### Database Integration
Add database service to `docker-compose.yml`:
```yaml
postgres:
  image: postgres:15-alpine
  environment:
    POSTGRES_DB: wa_bot
    POSTGRES_USER: wa_bot_user
    POSTGRES_PASSWORD: ${DB_PASS}
  volumes:
    - postgres-data:/var/lib/postgresql/data
```

### Monitoring Integration
Add monitoring services:
```yaml
prometheus:
  image: prom/prometheus:latest
  volumes:
    - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml

grafana:
  image: grafana/grafana:latest
  ports:
    - "3000:3000"
```

## 📝 Production Checklist

### Security
- [ ] Firewall configured and enabled
- [ ] SSL certificate installed and auto-renewal setup
- [ ] Strong passwords for all services
- [ ] Non-root user for deployment
- [ ] Fail2ban installed and configured
- [ ] Regular security updates enabled

### Performance
- [ ] Sufficient server resources allocated
- [ ] Docker resources limited appropriately
- [ ] Log rotation configured
- [ ] Monitoring setup and alerts configured

### Backup
- [ ] Automated backup scheduled
- [ ] Backup restoration tested
- [ ] Off-site backup storage configured
- [ ] Recovery procedures documented

### Monitoring
- [ ] Health check endpoints working
- [ ] Log aggregation setup
- [ ] Alert notifications configured
- [ ] Performance metrics tracked

## 📞 Support

### Getting Help
1. Check logs: `./scripts/deploy.sh logs`
2. Verify configuration: `./scripts/deploy.sh status`
3. Review troubleshooting section
4. Submit issue with logs and configuration

### Useful Commands
```bash
# View all containers
docker ps -a

# Check resource usage
docker stats

# Network troubleshooting
docker network ls
docker network inspect wa-bot_wa-bot-network

# Volume management
docker volume ls
docker volume inspect wa-bot_wa-sessions
```