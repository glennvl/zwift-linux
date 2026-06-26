# shellcheck shell=bash
set -uo pipefail

wait_until() {
    local condition="${1:?}"
    local timeout="${2:-20}"
    local delay="${3:-0.1}"
    local counter=1

    while ! eval "${condition}" && [[ ${counter} -le ${timeout} ]]; do
        msgbox debug "Waiting... (${counter}/${timeout})"
        sleep "${delay}"
        ((counter++))
    done

    eval "${condition}"
}
