# WA-Bot VPS Deployment Guide

Panduan lengkap untuk deploy wa-bot di VPS Linux dengan Docker dan Nginx.

## 🚀 Prerequisites

### VPS Requirements
- Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- Minimum 1GB RAM, 1 CPU Core
- 10GB+ storage space
- Domain name yang sudah pointing ke VPS

### Software Requirements
- Docker & Docker Compose (akan diinstall otomatis)
- Nginx (akan diinstall otomatis)
- Git

## 📦 Quick Deployment

### 1. Clone Repository
```bash
git clone <repository-url>
cd wa-bot
```

### 2. Update Configuration
```bash
# Edit domain di deploy.sh
nano deploy.sh
# Ganti 'your-domain.com' dengan domain Anda

# Edit environment variables
cp .env.production .env
nano .env
# Update TELEGRAM_BOT_TOKEN dan TELEGRAM_RECEIVER_ID
```

### 3. Make Script Executable & Deploy
```bash
chmod +x deploy.sh
sudo ./deploy.sh
```

### 4. Setup SSL (Opsional tapi Direkomendasikan)
```bash
sudo ./deploy.sh ssl
```

## 🔧 Manual Setup (Step by Step)

### 1. Install Dependencies
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
sudo apt install -y docker.io docker-compose

# Install Nginx
sudo apt install -y nginx

# Install Certbot untuk SSL
sudo apt install -y certbot python3-certbot-nginx

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### 2. Setup Firewall
```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### 3. Configure Nginx
```bash
# Copy nginx configs
sudo cp nginx-main.conf /etc/nginx/nginx.conf
sudo cp nginx-vps.conf /etc/nginx/sites-available/wa-bot

# Update domain dalam config
sudo sed -i 's/your-domain.com/yourdomain.com/g' /etc/nginx/sites-available/wa-bot

# Enable site
sudo ln -s /etc/nginx/sites-available/wa-bot /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and restart nginx
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx
```

### 4. Deploy Application
```bash
# Setup environment
cp .env.production .env
# Edit .env dengan konfigurasi Anda

# Build dan start container
docker-compose build
docker-compose up -d

# Check status
docker-compose logs -f
```

### 5. Setup SSL Certificate
```bash
# Get Let's Encrypt certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Enable HTTPS redirect di nginx config
sudo nano /etc/nginx/sites-available/wa-bot
# Uncomment HTTPS server block dan HTTP redirect

sudo systemctl reload nginx
```

## 🔄 Management Commands

### Application Management
```bash
# Start application
docker-compose up -d

# Stop application
docker-compose down

# Restart application
docker-compose restart

# View logs
docker-compose logs -f wa-bot

# Update application
git pull origin main
docker-compose build --no-cache
docker-compose up -d
```

### System Service Management
```bash
# Create systemd service untuk auto-start
sudo tee /etc/systemd/system/wa-bot.service > /dev/null <<EOF
[Unit]
Description=WhatsApp Bot
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable wa-bot
sudo systemctl start wa-bot
```

### Nginx Management
```bash
# Test nginx configuration
sudo nginx -t

# Reload nginx
sudo systemctl reload nginx

# Restart nginx
sudo systemctl restart nginx

# View nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 📊 Monitoring & Maintenance

### Health Checks
```bash
# Check application health
curl http://localhost:5000/
curl https://yourdomain.com/health

# Check container status
docker-compose ps

# Check system resources
docker stats wa-bot-app
```

### Log Management
```bash
# Application logs
docker-compose logs --tail=100 -f wa-bot

# Nginx logs
sudo tail -f /var/log/nginx/access.log

# System logs
sudo journalctl -u wa-bot -f
```

### Backup WhatsApp Sessions
```bash
# Create backup
docker-compose exec wa-bot tar czf /tmp/wa-sessions.tar.gz .wwebjs_auth/
docker cp wa-bot-app:/tmp/wa-sessions.tar.gz ./backup-$(date +%Y%m%d).tar.gz

# Restore backup
docker cp ./backup-20231201.tar.gz wa-bot-app:/tmp/
docker-compose exec wa-bot tar xzf /tmp/backup-20231201.tar.gz
docker-compose restart wa-bot
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Container Won't Start
```bash
# Check logs
docker-compose logs wa-bot

# Common causes:
# - Port 5000 already in use
# - Incorrect environment variables
# - Insufficient permissions
```

#### 2. WhatsApp Connection Issues
```bash
# Check Chrome/Puppeteer logs
docker-compose logs wa-bot | grep -i chrome

# Reset WhatsApp session
docker-compose down
docker volume rm wa-bot_wa-sessions
docker-compose up -d
```

#### 3. Nginx Configuration Issues
```bash
# Test nginx config
sudo nginx -t

# Check nginx status
sudo systemctl status nginx

# Common fixes:
# - Check domain name in config
# - Verify SSL certificate paths
# - Check firewall settings
```

#### 4. SSL Certificate Issues
```bash
# Renew certificate manually
sudo certbot renew

# Test certificate
sudo certbot certificates

# Check certificate auto-renewal
sudo systemctl status certbot.timer
```

### Performance Optimization

#### 1. Container Resources
```bash
# Limit container resources dalam docker-compose.yml
services:
  wa-bot:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
```

#### 2. Nginx Caching
```bash
# Add to nginx config
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

## 🔐 Security Best Practices

### 1. Update Sistem Regularly
```bash
# Setup auto-updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### 2. Monitor Failed Login Attempts
```bash
# Install fail2ban
sudo apt install fail2ban

# Create jail for nginx
sudo nano /etc/fail2ban/jail.local
```

### 3. Secure SSH
```bash
# Disable password authentication
sudo nano /etc/ssh/sshd_config
# Set: PasswordAuthentication no
sudo systemctl restart sshd
```

### 4. Regular Backups
```bash
# Create automated backup script
#!/bin/bash
DATE=$(date +%Y%m%d)
docker-compose exec wa-bot tar czf /tmp/wa-sessions-$DATE.tar.gz .wwebjs_auth/
docker cp wa-bot-app:/tmp/wa-sessions-$DATE.tar.gz /backup/
# Upload to cloud storage
```

## 📞 Support

Jika mengalami masalah:

1. Periksa logs: `docker-compose logs -f`
2. Restart aplikasi: `docker-compose restart`
3. Check status sistem: `systemctl status wa-bot`
4. Verifikasi port dan firewall: `netstat -tlnp | grep :5000`

## 🚀 Production Checklist

- [ ] Domain sudah pointing ke VPS
- [ ] SSL certificate terinstall
- [ ] Firewall dikonfigurasi dengan benar
- [ ] Environment variables sudah diset
- [ ] Backup strategy sudah disiapkan
- [ ] Monitoring sudah aktif
- [ ] Auto-update diaktifkan
- [ ] Log rotation dikonfigurasi