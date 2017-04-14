#!/bin/bash -
#title          :install.sh
#description    :Installs UniFi Controller and spawns a local kiosk to view it
#author         :Cody Bunch
#date           :04/13/2017
#version        :
#usage          :bash ./install.sh
#notes          :This script will install the UBNT UniFi controller, and TFT
#               :screen on a debian based rPI image.
#============================================================================

# Pull in some helpers
run_dir=$(dirname "$0")

declare functions="${*:-$run_dir/lib/**}"
for file in $functions; do {
    # shellcheck source=/dev/null
    . $file
} done

# shellcheck source=/dev/null
. "$run_dir/conf"


#
# main
# Performs the install
#
main() {
    if [[ -f /etc/init.d/install_kiosk ]]; then {
        e_header "Beginning Installation"
        first_run
        install_utilities "${APT_PACKAGES[@]}" true || e_error "Failed to install utilities"; exit 99
        install_unifi || e_error "Failed to install UniFi"; exit 99
        configure_wifi "${SSID}" "${WIFI_PASS}" || e_error "Failed to configure wifi"; exit 99
        install_screen_before_reboot || e_error "Failed to install screen"; exit 99
        e_arrow "Rebooting to complete installation"
        do_reboot
    } else {
        install_screen_after_reboot "${SCREEN_SIZE}" || e_error "Failed to install screen"; exit 99
        settup_kiosk "${UNIFI_URL}" || e_error "Unable to install domotz kiosk"; exit 99
        clean_up || e_error "Cleanup failed"; exit 99
        e_success "Installation complete, rebooting into kiosk mode"
        do_reboot
    } fi
}


#
# Start the install
#
case "$DBG" in
    debug )
        log "Debugging enabled. Logging to $LOGFILE" -c "red" -b -u
        log "Starting bootstrap" -c "blue"
        set -e -u -x
        time { main "$@"; } 2>&1 | tee -a "$LOGFILE"
        ;;
    log )
        log "Logging output to $LOGFILE" -c "yellow" -u
        log "Starting bootstrap" -c "blue"
        time { main "$@"; } 2>&1 | tee -a "$LOGFILE"
        ;;
    * )
        log "Starting bootstrap" -c "blue"
        main "$@"
        ;;
esac