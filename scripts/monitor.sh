#!/bin/bash

# Monitoring script for wa-bot
# Add to crontab: */5 * * * * /opt/wa-bot/scripts/monitor.sh

LOG_FILE="/var/log/wa-bot-monitor.log"
WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
EMAIL="${ADMIN_EMAIL:-admin@localhost}"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to send alert
send_alert() {
    local message="$1"
    log_message "ALERT: $message"
    
    # Send to Slack if webhook is configured
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 WA-Bot Alert: $message\"}" \
            "$WEBHOOK_URL" &>/dev/null
    fi
    
    # Send email
    echo "WA-Bot Alert: $message" | mail -s "WA-Bot Alert" "$EMAIL" 2>/dev/null || true
}

# Check if containers are running
check_containers() {
    local failed_containers=()
    
    for container in wa-bot-app wa-bot-nginx wa-bot-redis; do
        if ! docker ps --format "table {{.Names}}" | grep -q "$container"; then
            failed_containers+=("$container")
        fi
    done
    
    if [[ ${#failed_containers[@]} -gt 0 ]]; then
        send_alert "Containers not running: ${failed_containers[*]}"
        return 1
    fi
    
    return 0
}

# Check application health
check_health() {
    if ! curl -f -s http://localhost/health &>/dev/null; then
        send_alert "Application health check failed"
        return 1
    fi
    return 0
}

# Check disk space
check_disk_space() {
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $usage -gt 85 ]]; then
        send_alert "Disk space usage high: ${usage}%"
        return 1
    fi
    return 0
}

# Check memory usage
check_memory() {
    local memory_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
    if [[ $memory_usage -gt 90 ]]; then
        send_alert "Memory usage high: ${memory_usage}%"
        return 1
    fi
    return 0
}

# Clean up old logs
cleanup_logs() {
    # Clean application logs older than 7 days
    find /var/log -name "*wa-bot*" -type f -mtime +7 -delete 2>/dev/null || true
    
    # Clean Docker logs
    docker system prune -f --filter "until=168h" &>/dev/null || true
}

# Main monitoring
main() {
    log_message "Starting monitoring check"
    
    local checks_passed=0
    local total_checks=4
    
    check_containers && ((checks_passed++))
    check_health && ((checks_passed++))
    check_disk_space && ((checks_passed++))
    check_memory && ((checks_passed++))
    
    if [[ $checks_passed -eq $total_checks ]]; then
        log_message "All checks passed ($checks_passed/$total_checks)"
    else
        log_message "Some checks failed ($checks_passed/$total_checks)"
    fi
    
    # Cleanup on success
    if [[ $checks_passed -eq $total_checks ]]; then
        cleanup_logs
    fi
}

# Run main function
main