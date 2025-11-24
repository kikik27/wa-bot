# WA-Bot Docker & Nginx Setup

Konfigurasi lengkap untuk deployment WA-Bot di VPS Linux menggunakan Docker dan Nginx.

## 🚀 Quick Deploy di VPS Linux

### 1. Clone Repository
```bash
git clone https://github.com/your-username/wa-bot.git
cd wa-bot
```

### 2. Setup Environment
```bash
cp .env.example .env
nano .env  # Edit sesuai konfigurasi Anda
```

### 3. Deploy
```bash
chmod +x scripts/*.sh
./scripts/deploy.sh init
./scripts/deploy.sh start
```

### 4. Setup SSL (Opsional)
```bash
./scripts/deploy.sh ssl
```

## 📁 Struktur File

```
wa-bot/
├── Dockerfile                 # Container aplikasi utama
├── docker-compose.yml         # Produksi compose
├── docker-compose.dev.yml     # Development compose
├── .env.example              # Template environment
├── .dockerignore             # Docker ignore rules
├── nginx/
│   ├── nginx.conf           # Main nginx config
│   ├── nginx.dev.conf       # Development nginx config
│   └── conf.d/
│       ├── wa-bot.conf      # HTTP configuration
│       └── wa-bot-ssl.conf.disabled  # HTTPS config (disabled by default)
├── scripts/
│   ├── deploy.sh           # Main deployment script
│   ├── quick-install.sh    # Quick installation
│   └── monitor.sh          # Monitoring script
└── ssl/                    # SSL certificates directory
```

## 🔧 Services

### Docker Containers
- **wa-bot-app**: Aplikasi Node.js utama
- **wa-bot-nginx**: Nginx reverse proxy
- **wa-bot-redis**: Redis untuk session storage
- **watchtower**: Auto-update containers (opsional)

### Ports
- **80**: HTTP (Nginx)
- **443**: HTTPS (Nginx)
- **5000**: App container (internal)

## ⚙️ Konfigurasi

### Environment Variables (.env)
```bash
# Domain
DOMAIN=your-domain.com

# App Settings
NODE_ENV=production
PORT=5000
WA_SESSION_NAME=wa-bot-production

# Security
REDIS_PASSWORD=strong_password_here
JWT_SECRET=your_secret_key_here

# SSL
LETSENCRYPT_EMAIL=admin@your-domain.com
```

### Nginx Configuration
- Rate limiting: 10 req/s
- Gzip compression enabled
- Security headers configured
- Health check endpoint: `/health`
- SSL ready (uncomment SSL config)

## 📋 Commands

```bash
# Deployment
./scripts/deploy.sh init      # Initialize system
./scripts/deploy.sh start     # Start services
./scripts/deploy.sh stop      # Stop services
./scripts/deploy.sh restart   # Restart services
./scripts/deploy.sh ssl       # Setup SSL certificate

# Maintenance
./scripts/deploy.sh update    # Update application
./scripts/deploy.sh backup    # Create backup
./scripts/deploy.sh logs      # View logs
./scripts/deploy.sh status    # Check status

# Development
docker-compose -f docker-compose.dev.yml up -d  # Start dev environment
```

## 🔐 SSL Setup

### Automatic (Let's Encrypt)
```bash
# Set domain in .env first
./scripts/deploy.sh ssl
```

### Manual
```bash
# Generate self-signed (development)
mkdir -p ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/private.key -out ssl/cert.pem

# Enable SSL config
mv nginx/conf.d/wa-bot-ssl.conf.disabled nginx/conf.d/wa-bot-ssl.conf
docker-compose restart nginx
```

## 📊 Monitoring

### Health Check
```bash
curl http://your-domain.com/health
```

### Logs
```bash
./scripts/deploy.sh logs          # All services
./scripts/deploy.sh logs nginx    # Nginx only
./scripts/deploy.sh logs wa-bot   # App only
```

### Resource Usage
```bash
./scripts/deploy.sh status
docker stats
```

### Automated Monitoring
```bash
# Add to crontab
crontab -e

# Monitor every 5 minutes
*/5 * * * * /opt/wa-bot/scripts/monitor.sh

# Backup daily at 2 AM
0 2 * * * /opt/wa-bot/scripts/deploy.sh backup
```

## 🚨 Troubleshooting

### WhatsApp Connection Issues
```bash
# Check logs
docker logs wa-bot-app -f

# Restart container
docker restart wa-bot-app

# Clear session (requires QR re-scan)
docker volume rm wa-bot_wa-sessions
```

### Nginx 502 Error
```bash
# Check app container
docker ps | grep wa-bot-app

# Test app directly
curl http://localhost:5000/

# Restart all services
docker-compose restart
```

### SSL Issues
```bash
# Check certificate
openssl x509 -in ssl/cert.pem -text -noout

# Renew Let's Encrypt
sudo certbot renew
docker-compose restart nginx
```

## 🔄 Backup & Update

### Backup
```bash
# Automatic backup
./scripts/deploy.sh backup

# Manual backup
docker run --rm \
  -v wa-bot_wa-sessions:/source \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/sessions-$(date +%Y%m%d).tar.gz -C /source .
```

### Update
```bash
# Automatic update
./scripts/deploy.sh update

# Manual update
git pull origin main
docker-compose build --no-cache
docker-compose up -d
```

## 🛡️ Security

### Firewall
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

### Security Headers
Nginx automatically adds:
- X-Frame-Options
- X-XSS-Protection
- X-Content-Type-Options
- Strict-Transport-Security (HTTPS only)
- Referrer-Policy

## 📝 Production Checklist

- [ ] Domain configured and pointing to VPS
- [ ] .env file configured with production values
- [ ] Firewall configured
- [ ] SSL certificate installed
- [ ] Monitoring setup
- [ ] Backup schedule configured
- [ ] Log rotation configured
- [ ] Health checks working

## 💡 Tips

1. **Resource Requirements**: Minimal 2GB RAM, 2 CPU cores
2. **Storage**: 20GB+ recommended for logs and sessions
3. **Domain**: Ensure DNS propagation before SSL setup
4. **Monitoring**: Setup alerts for disk space and memory usage
5. **Backup**: Test restore procedures regularly

## 🔗 Useful Links

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Let's Encrypt](https://letsencrypt.org/)
- [WhatsApp Web.js Documentation](https://wwebjs.dev/)

---

**Note**: Ganti `your-username` dan `your-domain.com` dengan nilai yang sesuai untuk deployment Anda.