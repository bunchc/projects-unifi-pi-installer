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
    if ! [[ -f /etc/init.d/install_kiosk ]]; then {
        e_header "Beginning Installation"
        first_run
        install_utilities true "${APT_PACKAGES[@]}"
        install_unifi
        configure_wifi "${SSID}" "${WIFI_PASS}"
        install_screen_before_reboot
        e_arrow "Rebooting to complete installation"
        do_reboot
    } else {
        install_screen_after_reboot "${SCREEN_SIZE}"
        settup_kiosk "${UNIFI_URL}"
        clean_up
        e_success "Installation complete, rebooting into kiosk mode"
        do_reboot
    } fi
}


#
# Start the install
#
case "$DBG" in
    debug )
        e_arrow "Debugging enabled. Logging to $LOGFILE"
        e_arrow "Starting bootstrap"
        set -e -u -x
        time { main "$@"; } 2>&1 | tee -a "$LOGFILE"
        ;;
    log )
        e_arrow "Logging output to $LOGFILE"
        e_arrow "Starting bootstrap"
        time { main "$@"; } 2>&1 | tee -a "$LOGFILE"
        ;;
    * )
        e_arrow "Starting bootstrap"
        main "$@"
        ;;
esac