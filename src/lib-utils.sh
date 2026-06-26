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

is_empty_directory() {
    local directory="${1:?}"
    if [[ ! -d ${directory} ]]; then
        msgbox error "${directory} is not a directory"
        exit 1
    fi
    local contents
    ! contents="$(ls -A "${directory}" 2> /dev/null)" || [[ -z ${contents} ]]
}
