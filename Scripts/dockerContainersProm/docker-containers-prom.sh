#!/bin/bash
# Publishes container state for node_exporter's textfile collector (read by Prometheus, Grafana and Hermes).
set -euo pipefail
out=/var/lib/prometheus/node-exporter/docker_containers.prom
tmp=$(mktemp "$out.XXXXXX")
trap 'rm -f "$tmp"' EXIT
{
    echo "# HELP docker_container_running 1 if the container is running."
    echo "# TYPE docker_container_running gauge"
    echo "# HELP docker_container_healthy Healthcheck result: 1 healthy, 0 unhealthy, 0.5 starting. Absent without a healthcheck."
    echo "# TYPE docker_container_healthy gauge"
    echo "# HELP docker_container_restart_count Times Docker restarted the container."
    echo "# TYPE docker_container_restart_count gauge"
    echo "# HELP docker_container_started_time_seconds When the container last started (unix time)."
    echo "# TYPE docker_container_started_time_seconds gauge"
    ids=$(docker ps -aq)
    [[ -n "$ids" ]] && docker inspect --format \
        '{{.Name}}|{{.Config.Image}}|{{.State.Status}}|{{.HostConfig.RestartPolicy.Name}}|{{if .State.Health}}{{.State.Health.Status}}{{end}}|{{.RestartCount}}|{{.State.StartedAt}}' $ids |
    while IFS='|' read -r name image state policy health restarts started; do
        l="name=\"${name#/}\",image=\"${image//\"/}\",state=\"$state\",restart_policy=\"${policy:-no}\""
        echo "docker_container_running{$l} $([[ $state == running ]] && echo 1 || echo 0)"
        case "$health" in
            healthy) echo "docker_container_healthy{name=\"${name#/}\"} 1" ;;
            unhealthy) echo "docker_container_healthy{name=\"${name#/}\"} 0" ;;
            starting) echo "docker_container_healthy{name=\"${name#/}\"} 0.5" ;;
        esac
        echo "docker_container_restart_count{name=\"${name#/}\"} $restarts"
        echo "docker_container_started_time_seconds{name=\"${name#/}\"} $(date -d "$started" +%s 2>/dev/null || echo 0)"
    done
    echo "docker_containers_last_scrape_time_seconds $(date +%s)"
} > "$tmp"
chmod 644 "$tmp"
mv "$tmp" "$out"
trap - EXIT
