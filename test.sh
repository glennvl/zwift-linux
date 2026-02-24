#!/usr/bin/env bash
set -euo pipefail

if [[ -t 1 ]]; then
    readonly COLOR_WHITE="\033[0;37m"
    readonly COLOR_RED="\033[0;31m"
    readonly COLOR_GREEN="\033[0;32m"
    readonly COLOR_BLUE="\033[0;34m"
    readonly COLOR_YELLOW="\033[0;33m"
    readonly RESET_STYLE="\033[0m"
else
    readonly COLOR_WHITE=""
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_BLUE=""
    readonly COLOR_YELLOW=""
    readonly RESET_STYLE=""
fi

msgbox() {
    local type="${1:?}" # Type: info, ok, warning, error, viewport
    local msg="${2:-}"  # Message: the message to display
    local tag="${3:-}"  # Tag: used for viewport

    case ${type} in
        info) echo -e "${COLOR_BLUE}[*] ${msg}${RESET_STYLE}" ;;
        ok) echo -e "${COLOR_GREEN}[✓] ${msg}${RESET_STYLE}" ;;
        warning) echo -e "${COLOR_YELLOW}[!] ${msg}${RESET_STYLE}" ;;
        error) echo -e "${COLOR_RED}[✗] ${msg}${RESET_STYLE}" >&2 ;;
        viewport) echo -e "${COLOR_WHITE}[${tag}] ${msg}${RESET_STYLE}" ;;
        *) echo -e "${COLOR_WHITE}[*] ${msg}${RESET_STYLE}" ;;
    esac
}

viewport() {
    local rows="${1:-20}"

    local start_time
    start_time="$(date +%s.%N)"

    local temp_file
    temp_file="$(mktemp -q /tmp/viewport-XXXXXXXXXX)" || return 1

    cat - > "${temp_file}" &
    local bg_pid="${!}"

    local last_printed=0
    draw_viewport_lines() {
        local total to_show line now elapsed_time
        total="$(wc -l < "${temp_file}" || echo 0)"
        if [[ ${total} -lt ${rows} ]]; then
            to_show="${total}"
        else
            to_show="${rows}"
        fi
        if [[ ${last_printed} -gt 0 ]]; then
            printf '\033[%dA' "${last_printed}"
        fi
        if [[ ${to_show} -gt 0 ]]; then
            now="$(date +%s.%N)"
            elapsed_time="$(awk -v s="${start_time}" -v n="${now}" 'BEGIN{printf "%.1f", n - s}')"
            tail -n "${to_show}" "${temp_file}" | while IFS= read -r line; do
                printf '\033[2K\r'
                msgbox viewport "${line//$'\r'/}" "${elapsed_time}s"
            done
        fi
        last_printed=${to_show:-0}
    }

    while ps -p "${bg_pid}" > /dev/null 2>&1; do
        draw_viewport_lines
        sleep 0.1
    done
    draw_viewport_lines

    rm -f "${temp_file}"
}

echo "begin"

for i in $(seq 1 1000); do
    echo "this is line ${i}"
    sleep 0.01
done | viewport 20

echo "end"
