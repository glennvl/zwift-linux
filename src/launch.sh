#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
readonly SCRIPT_DIR

source "${SCRIPT_DIR}/lib-logging.sh"
source "${SCRIPT_DIR}/lib-wine.sh"

readonly ZWIFT_USERNAME="${ZWIFT_USERNAME:-}"
readonly ZWIFT_PASSWORD="${ZWIFT_PASSWORD:-}"
readonly ZWIFT_OVERRIDE_RESOLUTION="${ZWIFT_OVERRIDE_RESOLUTION:-}"
readonly ZWIFT_NO_GAMEMODE="${ZWIFT_NO_GAMEMODE:-0}"

readonly WINE_USER_HOME="/home/user/.wine/drive_c/users/user"
readonly ZWIFT_HOME="/home/user/.wine/drive_c/Program Files (x86)/Zwift"
readonly ZWIFT_DOCS="${WINE_USER_HOME}/AppData/Local/Zwift"
readonly ZWIFT_PREFS="${ZWIFT_DOCS}/prefs.xml"

###########################
##### Configure Zwift #####

# Create array for zwift arguments
declare -a zwift_args
zwift_args=()

if [[ ! -d ${ZWIFT_HOME} ]] || ! cd "${ZWIFT_HOME}"; then
    msgbox error "Directory ${ZWIFT_HOME} does not exist. Has Zwift been installed?"
    exit 1
fi

if [[ -n ${ZWIFT_OVERRIDE_RESOLUTION} ]]; then
    if [[ -f ${ZWIFT_PREFS} ]]; then
        msgbox info "Setting zwift resolution to ${ZWIFT_OVERRIDE_RESOLUTION}."
        updated_prefs="$(awk -v resolution="${ZWIFT_OVERRIDE_RESOLUTION}" '{
            gsub(/<USER_RESOLUTION_PREF>.*<\/USER_RESOLUTION_PREF>/,
                 "<USER_RESOLUTION_PREF>" resolution "</USER_RESOLUTION_PREF>")
        } 1' "${ZWIFT_PREFS}")"
        echo "${updated_prefs}" > "${ZWIFT_PREFS}"
    else
        msgbox warning "Preferences file does not exist yet. Resolution ${ZWIFT_OVERRIDE_RESOLUTION} cannot be set."
    fi
fi

if [[ -n ${ZWIFT_USERNAME} ]] && [[ -n ${ZWIFT_PASSWORD} ]]; then
    msgbox info "Authenticating with Zwift"
    if auth_token="$(/opt/netbrain/zwift/authenticate.sh)"; then
        zwift_args+=(--token="${auth_token}")
    else
        msgbox warning "Authentication failed, manual login will be required"
    fi
fi

##########################################
##### Automatically stop wine server #####

cleanup() {
    msgbox info "Stopping wine server"
    wineserver -k || true
}

trap cleanup EXIT

##################################
##### Start Zwift using wine #####

# The Zwift launcher is not fully functional in wine:
# - It cannot show the login page (1)
# - It cannot launch Zwift (2)
# - If Zwift itself is started independently, it will automatically start the launcher (3)
# Workaround for (1):
# 1. Manually invoke the Zwift API to login and obtain an authentication token using the zwift-auth.sh script
# 2. Pass the authentication token to ZwiftApp.exe using the --token=... argument
# Workaround for (2) and (3):
# 1. Start the launcher ZwiftLauncher.exe in the background using SilentLaunch
# 2. Obtain the launcher wine process id
# 3. Use runfromprocess to launch ZwiftApp.exe with the launcher process as parent
# 4. Kill ZwiftLauncher.exe

msgbox info "Starting Zwift launcher using wine"

if ! wine start ZwiftLauncher.exe SilentLaunch || ! wait_until_wine_task_started ZwiftLauncher.exe; then
    msgbox error "Failed to start Zwift launcher using wine!"
    exit 1
fi

if ! launcher_pid="$(wine_task_pid ZwiftLauncher.exe)"; then
    msgbox error "Unable to get launcher process id. Did it crash?"
    exit 1
fi

msgbox ok "Zwift launcher started using wine"
msgbox info "Starting Zwift using wine"

declare -a zwift_cmd

if [[ ${ZWIFT_NO_GAMEMODE} -eq 1 ]]; then
    msgbox info "Not using gamemode"
    zwift_cmd=(wine start /exec /opt/run-from.exe "${launcher_pid}" ZwiftApp.exe "${zwift_args[@]}")
else
    msgbox info "Using gamemode"
    zwift_cmd=(/usr/games/gamemoderun wine /opt/run-from.exe "${launcher_pid}" ZwiftApp.exe "${zwift_args[@]}")
fi

if ! "${zwift_cmd[@]}" || ! wait_until_wine_task_started ZwiftApp.exe; then
    msgbox error "Failed to start Zwift using wine!"
    exit 1
fi

msgbox info "Killing Zwift launcher and background tasks"
kill_wine_tasks ZwiftLauncher.exe ZwiftWindowsCrashHandler.exe MicrosoftEdgeUpdate.exe

msgbox ok "Zwift started using wine"

##################################
##### Wait for Zwift to exit #####

counter=1
while is_wine_task_running ZwiftApp.exe; do
    msgbox debug "Waiting for Zwift to exit... ($((counter++)))"
    sleep 5
done

msgbox info "Zwift closed, exiting"
