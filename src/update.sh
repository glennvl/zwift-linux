#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
readonly SCRIPT_DIR

source "${SCRIPT_DIR}/lib-logging.sh"
source "${SCRIPT_DIR}/lib-utils.sh"
source "${SCRIPT_DIR}/lib-wine.sh"

readonly WINE_USER_HOME="${WINE_USER_HOME:?}"
readonly ZWIFT_DATA_DIR="${ZWIFT_DATA_DIR:?}"
readonly ZWIFT_INSTALL_DIR="${ZWIFT_INSTALL_DIR:?}"

get_current_version() {
    # if Zwift_ver_cur_filename.txt exists, it holds the true current version filename
    # if it does not exist, use Zwift_ver_cur.xml as fallback
    # if neither exist or contain a valid version, use undefined (Zwift not installed)

    local version_filename="Zwift_ver_cur.xml"
    if [[ -f "${ZWIFT_INSTALL_DIR}/Zwift_ver_cur_filename.txt" ]]; then
        version_filename="$(tr '\0' '\n' < "${ZWIFT_INSTALL_DIR}/Zwift_ver_cur_filename.txt")"
    fi

    grep -oP 'sversion="\K.*?(?=\s)' "${ZWIFT_INSTALL_DIR}/${version_filename}" 2> /dev/null | cut -f 1 -d ' ' || echo "none"
}

get_latest_version() {
    wget --no-cache --quiet -O - https://cdn.zwift.com/gameassets/Zwift_Updates_Root/Zwift_ver_cur.xml \
        | grep -oP 'sversion="\K.*?(?=")' | cut -f 1 -d ' ' \
        || return 1
}

update_zwift_using_launcher() {
    local zwift_latest_version
    if ! zwift_latest_version="$(get_latest_version)"; then
        msgbox error "Unable to retrieve latest Zwift version number"
        return 1
    fi

    local zwift_current_version
    zwift_current_version="$(get_current_version)"
    if [[ ${zwift_current_version} == "${zwift_latest_version}" ]]; then
        msgbox ok "Nothing to do, already at latest version ${zwift_latest_version}"
        return 0
    fi

    msgbox info "Updating Zwift from version ${zwift_current_version} to ${zwift_latest_version}"

    msgbox info "Starting Zwift launcher using wine"
    local zwift_wine_dir
    if ! zwift_wine_dir="$(winepath -w "${ZWIFT_INSTALL_DIR}")" || [[ -z ${zwift_wine_dir} ]]; then
        msgbox error "Failed to convert Zwift installation path to win32 path for wine"
        exit 1
    else
        msgbox debug "Zwift installation wine path is: ${zwift_wine_dir}"
    fi
    if ! wine start /d "${zwift_wine_dir}" ZwiftLauncher.exe SilentLaunch; then
        msgbox error "Failed to start Zwift launcher using wine!"
        return 1
    fi
    msgbox ok "Zwift launcher started using wine"

    local counter=1
    local max_iterations=60 # 60 * 5s = 5 minutes max
    local zwift_original_version="${zwift_current_version}"

    # also stop if launcher exits before update finishes, so we don't hang forever
    while [[ ${zwift_current_version} == "${zwift_original_version}" ]] && [[ ${counter} -le ${max_iterations} ]] && is_wine_task_running ZwiftLauncher.exe; do
        msgbox info "Updating Zwift... (${counter}/${max_iterations})"
        msgbox debug "Current version: ${zwift_current_version}; Latest version: ${zwift_latest_version}"
        sleep 5
        zwift_current_version="$(get_current_version)"
        ((counter++))
    done

    # if launcher exited unexpectedly or update timeout, Zwift is still at the old version
    if [[ ${zwift_current_version} == "${zwift_original_version}" ]]; then
        if [[ ${counter} -gt ${max_iterations} ]]; then
            msgbox error "Update timed out after $((counter * 5)) seconds"
        else
            msgbox error "Launcher exited unexpectedly, update did not complete"
        fi
        return 1
    fi

    # zwift updated to unexpected version?
    if [[ ${zwift_current_version} != "${zwift_latest_version}" ]]; then
        msgbox error "Zwift updated to unexpected version (Expected: ${zwift_latest_version}, Actual: ${zwift_current_version})"
        return 1
    fi

    msgbox ok "Zwift updated to version ${zwift_current_version}"
}

install_zwift() {
    # prevent wine from installing mono and gecko
    msgbox info "Initializing wine"
    WINEDLLOVERRIDES="mscoree,mshtml=" wineboot -u || return 1

    msgbox info "Installing prerequisites using winetricks"
    winetricks -q corefonts dotnet48 d3dcompiler_47 || return 1

    msgbox info "Downloading and installing webview2"
    wget -O /tmp/webview2-setup.exe https://go.microsoft.com/fwlink/p/?LinkId=2124703 || return 1
    wine /tmp/webview2-setup.exe /silent /install || return 1

    msgbox info "Enabling Wayland support"
    wine reg.exe add HKCU\\Software\\Wine\\Drivers /f /v Graphics /d x11,wayland || return 1

    msgbox info "Downloading and installing Zwift"
    wget -O /tmp/ZwiftSetup.exe https://cdn.zwift.com/app/ZwiftSetup.exe || return 1
    wine /tmp/ZwiftSetup.exe /SP- /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /NOCANCEL || return 1
}

#########################################
##### Automatically cleanup on exit #####

cleanup() {
    msgbox info "Stopping wine server"
    wineserver -k || true # important, Zwift launcher won't stop until wine server is killed

    msgbox info "Removing installation artifacts"
    rm -f -- "/tmp/ZwiftSetup.exe" || true
    rm -f -- "/tmp/webview2-setup.exe" || true
    rm -rf -- "${WINE_USER_HOME}/Downloads/Zwift" || true
    rm -rf -- "/home/user/.cache/wine*" || true
    rm -rf -- "${ZWIFT_DATA_DIR:?}/*" || true
}

trap cleanup EXIT

###################################
##### Install or update Zwift #####

if [[ ${1:-} == "--install" ]]; then
    msgbox info "Installing Zwift..."
    if [[ -f "${ZWIFT_INSTALL_DIR}/ZwiftLauncher.exe" ]]; then
        msgbox warning "Zwift is already installed, skipping"
    elif ! install_zwift; then
        msgbox error "Failed to install Zwift!"
        exit 1
    fi
fi

msgbox info "Updating Zwift..."

if ! [[ -f "${ZWIFT_INSTALL_DIR}/ZwiftLauncher.exe" ]]; then
    msgbox error "ZwiftLauncher.exe not found. Is Zwift installed?"
    exit 1
fi

if ! update_zwift_using_launcher; then
    msgbox error "Failed to update Zwift!"
    exit 1
fi
