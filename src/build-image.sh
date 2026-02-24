#!/usr/bin/env bash
set -uo pipefail

readonly DEBUG="${DEBUG:-0}"
if [[ ${DEBUG} -eq 1 ]]; then set -x; fi

if [[ -t 1 ]]; then
    readonly COLORED_OUTPUT_SUPPORTED="1"
    readonly COLOR_WHITE="\033[0;37m"
    readonly COLOR_RED="\033[0;31m"
    readonly COLOR_GREEN="\033[0;32m"
    readonly COLOR_BLUE="\033[0;34m"
    readonly COLOR_YELLOW="\033[0;33m"
    readonly STYLE_BOLD="\033[1m"
    readonly STYLE_UNDERLINE="\033[4m"
    readonly RESET_STYLE="\033[0m"
else
    readonly COLORED_OUTPUT_SUPPORTED="0"
    readonly COLOR_WHITE=""
    readonly COLOR_RED=""
    readonly COLOR_GREEN=""
    readonly COLOR_BLUE=""
    readonly COLOR_YELLOW=""
    readonly STYLE_BOLD=""
    readonly STYLE_UNDERLINE=""
    readonly RESET_STYLE=""
fi

TERMINAL_WIDTH="$(tput cols 2> /dev/null || echo 80)"
readonly TERMINAL_WIDTH

msgbox() {
    local type="${1:?}" # Type: info, ok, warning, error, viewport
    local msg="${2:-}"  # Message: the message to display

    case ${type} in
        info) echo -e "${COLOR_BLUE}[*] ${msg}${RESET_STYLE}" ;;
        ok) echo -e "${COLOR_GREEN}[✓] ${msg}${RESET_STYLE}" ;;
        warning) echo -e "${COLOR_YELLOW}[!] ${msg}${RESET_STYLE}" ;;
        error) echo -e "${COLOR_RED}[✗] ${msg}${RESET_STYLE}" >&2 ;;
        viewport) echo -e "${COLOR_WHITE}[•] ${msg}${RESET_STYLE}" ;;
        *) echo -e "${COLOR_WHITE}[*] ${msg}${RESET_STYLE}" ;;
    esac
}

viewport() {
    local max_rows="${1:-20}"
    local temp_file
    temp_file="$(mktemp -q /tmp/viewport-XXXXXXXXXX)" || return 1
    cat - > "${temp_file}" &
    local cat_pid="${!}"

    preprocess() {
        local start_time processed_lines=0
        start_time="$(date +%s.%N)"

        preprocess_lines() {
            local total_lines to_read=0 line now elapsed_time
            total_lines="$(wc -l < "${temp_file}" || echo 0)"
            [[ ${total_lines} -gt ${processed_lines} ]] && to_read="$((total_lines - processed_lines))"
            tail -n "${to_read}" "${temp_file}" 2> /dev/null | while IFS= read -r line; do
                now="$(date +%s.%N)"
                elapsed_time="$(awk -v s="${start_time}" -v n="${now}" 'BEGIN{printf "%.1f", n - s}')"
                printf '[%ss] %s\n' "${elapsed_time}" "${line//\\/\\\\}"
            done
            processed_lines="${total_lines}"
        }

        while ps -p "${cat_pid}" > /dev/null 2>&1; do
            preprocess_lines
            sleep 0.05
        done
        preprocess_lines
    }

    viewportify() {
        local last_printed=0 buffer="" line total to_show buffer_line
        local max_width="$((TERMINAL_WIDTH - 4))"
        while IFS= read -r line; do
            for i in $(seq 0 "${max_width}" "${#line}"); do
                buffer+="${line:i:max_width}"$'\n'
            done
            total="$(printf '%s' "${buffer}" | wc -l || echo 0)"
            to_show="${max_rows}"
            [[ ${total} -lt ${max_rows} ]] && to_show="${total}"
            [[ ${last_printed} -gt 0 ]] && printf '\033[%dA' "${last_printed}"
            printf '%s' "${buffer}" | tail -n "${to_show}" | while IFS= read -r buffer_line; do
                buffer_line="$(msgbox viewport "${buffer_line}")"
                printf '\033[2K%s\r\n' "${buffer_line%?}"
            done
            last_printed="${to_show:-0}"
        done
    }

    preprocess | viewportify &
    local pipeline_pid="${!}"
    wait "${cat_pid}" 2> /dev/null || true
    wait "${pipeline_pid}" 2> /dev/null || true
    rm -f "${temp_file}"
}

command_exists() {
    local cmd="${1:?}"
    local cmd_path
    cmd_path="$(command -v "${cmd}" 2> /dev/null)" && [[ -x ${cmd_path} ]]
}

echo -e "${COLOR_YELLOW}[!] ${STYLE_BOLD}Easily Zwift on linux!${RESET_STYLE}"
echo -e "${COLOR_YELLOW}[!] ${STYLE_UNDERLINE}https://github.com/netbrain/zwift${RESET_STYLE}"

msgbox info "Preparing to build Zwift image"

################################
##### Initialize variables #####

# Initialize system environment variables
readonly DISPLAY="${DISPLAY:-}"
readonly XAUTHORITY="${XAUTHORITY:-}"

# Initialize script constants
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
ZWIFT_UID="${UID}"
ZWIFT_GID="$(id -g)"
readonly SCRIPT_DIR ZWIFT_UID ZWIFT_GID

# Initialize CONTAINER_TOOL: Use podman if available
msgbox info "Looking for container tool"
CONTAINER_TOOL="${CONTAINER_TOOL:-}"
if [[ -z ${CONTAINER_TOOL} ]]; then
    if command_exists podman; then
        CONTAINER_TOOL="podman"
    else
        CONTAINER_TOOL="docker"
    fi
fi
readonly CONTAINER_TOOL
if command_exists "${CONTAINER_TOOL}"; then
    msgbox ok "Found container tool: ${CONTAINER_TOOL}"
else
    msgbox error "Container tool ${CONTAINER_TOOL} not found"
    msgbox error "  To install podman, see: https://podman.io/docs/installation"
    msgbox error "  To install docker, see: https://docs.docker.com/get-started/get-docker/"
    exit 1
fi

# Update information based on container tool
if [[ ${CONTAINER_TOOL} == "podman" ]]; then
    readonly BUILD_NAME="zwift"
    readonly IMAGE="localhost/zwift"
else
    readonly BUILD_NAME="netbrain/zwift"
    readonly IMAGE="netbrain/zwift"
fi
msgbox info "Image will be called ${IMAGE}"

###############################
##### Basic configuration #####

# Create array for container arguments
declare -a container_args
container_args=(
    -it
    --network bridge
    --name zwift
    --security-opt label=type:container_runtime_t
    --hostname "${HOSTNAME}"

    -e DEBUG="${DEBUG}"
    -e COLORED_OUTPUT="${COLORED_OUTPUT_SUPPORTED}"
    -e DISPLAY="${DISPLAY}"
    -e CONTAINER_TOOL="${CONTAINER_TOOL}"
    -e ZWIFT_UID="${ZWIFT_UID}"
    -e ZWIFT_GID="${ZWIFT_GID}"

    -v /tmp/.X11-unix:/tmp/.X11-unix
    -v "/run/user/${UID}:/run/user/${ZWIFT_UID}"
)

if [[ ${CONTAINER_TOOL} == "podman" ]]; then
    container_args+=(--userns "keep-id:uid=${ZWIFT_UID},gid=${ZWIFT_GID}")
fi

if [[ -n ${XAUTHORITY} ]]; then
    container_args+=(-e XAUTHORITY="${XAUTHORITY}")
fi

# Check for proprietary nvidia driver and set correct device to use
if [[ -f "/proc/driver/nvidia/version" ]]; then
    if [[ ${CONTAINER_TOOL} == "podman" ]]; then
        container_args+=(--device="nvidia.com/gpu=all")
    else
        container_args+=(--gpus="all")
    fi
else
    container_args+=(--device="/dev/dri:/dev/dri")
fi

#############################################
##### Build container and install Zwift #####

cleanup_invoked=0
cleanup() {
    if [[ ${cleanup_invoked} -ne 1 ]]; then
        msgbox info "Checking for temporary container"
        if ${CONTAINER_TOOL} container rm zwift > /dev/null 2>&1; then
            msgbox ok "Removed temporary container"
        else
            msgbox info "No temporary container to remove"
        fi
        cleanup_invoked=1
    fi
}

trap cleanup EXIT

msgbox info "Building image ${IMAGE}"
if ${CONTAINER_TOOL} build --force-rm -t "${BUILD_NAME}" "${SCRIPT_DIR}" |& viewport; then
    msgbox ok "Successfully built image ${IMAGE}"
else
    msgbox error "Failed to build image"
    exit 1
fi

msgbox info "Launching temporary container to install Zwift"
if ${CONTAINER_TOOL} run "${container_args[@]}" "${IMAGE}:latest" "${@}" |& viewport; then
    msgbox ok "Successfully installed Zwift in container"
else
    msgbox error "Failed to start container"
    exit 1
fi

msgbox info "Updating image with changes from temporary container"
if ${CONTAINER_TOOL} commit zwift "${BUILD_NAME}:latest" |& viewport; then
    msgbox ok "Tagged Zwift container as ${IMAGE}:latest"
else
    msgbox error "Failed to commit container changes to image"
    exit 1
fi

cleanup

########################
##### Launch Zwift #####

export IMAGE
export DONT_CHECK=1
export DONT_PULL=1
export ZWIFT_FG=1

"${SCRIPT_DIR}/zwift.sh"
