# shellcheck shell=bash

wine_task_info() {
    local task_name="${1:?}"
    wine tasklist /fo list /fi "IMAGENAME eq ${task_name}"
}

wine_task_pid() {
    local task_name="${1:?}"
    local task_info
    task_info="$(wine_task_info "${task_name}")" && grep -m1 -Po '^PID:[\t ]*\K[0-9]+' <<< "${task_info}"
}

is_wine_task_running() {
    local task_name="${1:?}"
    local task_info
    task_info="$(wine_task_info "${task_name}")" && [[ -n ${task_info} ]]
}

kill_wine_tasks() {
    for task in "${@}"; do
        msgbox debug "Killing wine task '${task}'"
        wine taskkill /f /im "${task}" > /dev/null 2>&1 || true
    done
}

wait_until_wine_task_started() {
    local task_name="${1:?}"
    msgbox info "Waiting for ${task_name} to start..."
    wait_until "is_wine_task_running ${task_name}"
}
