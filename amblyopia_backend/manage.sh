#!/usr/bin/env bash
# Quick management commands for Amblyopia Care System
SVC="amblyopia"
case "${1:-help}" in
    start)   sudo systemctl start  "$SVC" && echo "Started" ;;
    stop)    sudo systemctl stop   "$SVC" && echo "Stopped" ;;
    restart) sudo systemctl restart "$SVC" && echo "Restarted" ;;
    status)  sudo systemctl status "$SVC" ;;
    logs)    tail -f /home/anandhu/projects/amblyopia_backend/logs/backend.log ;;
    errors)  tail -f /home/anandhu/projects/amblyopia_backend/logs/backend_error.log ;;
    health)  curl -s http://localhost:8000/health | python3 -m json.tool ;;
    *)
        echo "Usage: bash manage.sh [start|stop|restart|status|logs|errors|health]"
        ;;
esac
