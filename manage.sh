#!/bin/bash

# Simple management script untuk wa-bot di VPS
# Usage: ./manage.sh [start|stop|restart|logs|update|backup]

PROJECT_NAME="wa-bot"

case "$1" in
    start)
        echo "Starting wa-bot..."
        docker-compose up -d
        echo "wa-bot started"
        ;;
    stop)
        echo "Stopping wa-bot..."
        docker-compose down
        echo "wa-bot stopped"
        ;;
    restart)
        echo "Restarting wa-bot..."
        docker-compose restart
        echo "wa-bot restarted"
        ;;
    logs)
        echo "Showing logs..."
        docker-compose logs -f wa-bot
        ;;
    update)
        echo "Updating wa-bot..."
        git pull origin main
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
        echo "wa-bot updated"
        ;;
    backup)
        DATE=$(date +%Y%m%d-%H%M%S)
        echo "Creating backup..."
        docker-compose exec wa-bot tar czf /tmp/wa-sessions-$DATE.tar.gz .wwebjs_auth/
        docker cp wa-bot-app:/tmp/wa-sessions-$DATE.tar.gz ./backup-$DATE.tar.gz
        echo "Backup created: backup-$DATE.tar.gz"
        ;;
    status)
        echo "Checking status..."
        docker-compose ps
        curl -s http://localhost:5000/ > /dev/null && echo "App is running" || echo "App is not responding"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|update|backup|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start wa-bot container"
        echo "  stop    - Stop wa-bot container"
        echo "  restart - Restart wa-bot container"
        echo "  logs    - Show live logs"
        echo "  update  - Pull latest code and rebuild"
        echo "  backup  - Backup WhatsApp session data"
        echo "  status  - Check container and app status"
        exit 1
        ;;
esac