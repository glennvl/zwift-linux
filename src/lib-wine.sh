# shellcheck shell=bash
set -uo pipefail

wine_task_info() {
    local task_name="${1:?}"
    wine tasklist /fo list /fi "IMAGENAME eq ${task_name}"
}

wine_task_pid() {
    local task_name="${1:?}"
    wine_task_info "${task_name}" | grep -m1 -Po '^PID:[\t ]*\K[0-9]+'
}

is_wine_task_running() {
    local task_name="${1:?}"
    [[ -n $(wine_task_info "${task_name}" || true) ]]
}

kill_wine_tasks() {
    for task in "${@}"; do
        msgbox debug "Killing wine task '${task}'"
        wine taskkill /f /im "${task}" > /dev/null 2>&1 || true
    done
}

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

wait_until_wine_task_started() {
    local task_name="${1:?}"
    msgbox info "Waiting for ${task_name} to start..."
    wait_until "is_wine_task_running ${task_name}"
}
