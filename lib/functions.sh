#!/bin/bash -
#title          :functions.sh
#description    :Generic helper functions
#author         :Cody Bunch
#date           :04/13/2017
#version        :
#usage          :. ./lib/functions.sh
#notes          :Provides color logging, arrows and other generic functions
#============================================================================

#
# Arrows, Checks, and such
#
function e_header()   { echo -e "\n\033[1m$@\033[0m"; }
function e_success()  { echo -e " \033[1;32m✔\033[0m  $@"; }
function e_error()    { echo -e " \033[1;31m✖\033[0m  $@"; }
function e_arrow()    { echo -e " \033[1;34m➜\033[0m  $@"; }


#
# first_run
# Installs us as an init script on first run
# @return
#
first_run() {
    e_arrow "${FUNCNAME[0]}"
    if ! [[ -f /etc/init.d/install_kiosk ]]; then {
echo '#! /bin/sh

### BEGIN INIT INFO
# Provides:          install_kiosk
# Required-Start:
# Should-Start:
# Should-Stop:
# Required-Stop:
# Default-Start:
# Default-Stop:
# Short-Description:
# Description:
### END INIT INFO

PATH=/sbin:/bin:/usr/sbin:/usr/bin

case "$1" in
    start)
        /path/to/update/script
        ;;
    stop|restart|reload)
        ;;
esac' | sudo tee -a /etc/init.d/install_kiosk
        sudo chmod +x /etc/init.d/install_kiosk
        sudo update-rc.d install_kiosk defaults \
            || e_error "Unable to install reboot service"; exit 99
    } fi
}


#
# install_unifi
# Installs the UBNT Unifi controller
# @return
#
function install_unifi() {
    e_arrow "${FUNCNAME[0]}"
    ubnt=(unifi)

    e_arrow "Adding ubnt apt repo"
    echo "deb http://www.ubnt.com/downloads/unifi/debian unifi5 ubiquiti" \
        | sudo tee -a /etc/apt/sources.list.d/100-ubnt.list \
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 06E85760C0A52C50

    e_arrow "Installing UniFi"
    install_utilities "${ubnt[@]}"

    e_arrow "Disabling redundant Mongo"
    echo 'ENABLE_MONGODB=no' \
        | sudo tee -a /etc/mongodb.conf > /dev/null

    e_arrow "Installing better snappy-java"
    cd /usr/lib/unifi/lib || exit
    sudo rm snappy-java-1.0.5.jar
    sudo wget http://central.maven.org/maven2/org/xerial/snappy/snappy-java/1.1.2.6/snappy-java-1.1.2.6.jar
    sudo ln -s snappy-java-1.1.2.6.jar snappy-java-1.0.5.jar
}


#
# clean_up
# Removes the init script and performs other cleanup
# @return
#
clean_up() {
    e_arrow "${FUNCNAME[0]}"

    e_arrow "Stopping installer service"
    sudo service install_kiosk stop \
        || e_error "Failed to stop service"; exit 99

    e_arrow "Removing installer service"
    sudo update-rc.d install_kiosk remove \
        || e_error "Failed to remove service"; exit 99

    sudo rm -f /etc/init.d/install_kiosk \
        || e_error "Failed to remove script"; exit 99

    e_arrow "Cleaning up apt packages"
    sudo apt-get -y remove dkms
    sudo apt-get -y autoremove
    sudo apt-get -y clean

    e_arrow "Cleanup temp files"
    sudo rm -rf /tmp/* \
        || e_error "Failed to remove temp files"; exit 99

    e_arrow "Zero out freespace"
    dd if=/dev/zero of=/EMPTY bs=1M \
        || e_error "Failed to zero free space"; exit 99
    rm -f /EMPTY
}


#
# install_utilities PACKAGES
# apt installs packages from an array
# @param    Array of packages
# @return
#
function install_utilities() {
    local param=$1; shift
    local upgrade=$2; shift
    e_arrow "${FUNCNAME[0]}"

    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update -qq

    if $upgrade; then {
        sudo DEBIAN_FRONTEND=noninteractive apt-get -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            upgrade
    } fi

    if [[ "$(declare -p param)" =~ "decclare -a" ]]; then {
        sudo DEBIAN_FRONTEND=noninteractive apt-get -y \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold" \
            install "${param[@]}"
        sudo apt-get clean
    } else {
        e_error "$param is not an array."
    } fi
}


#
# install_screen_before_reboot
# Attempts to install the adafruit screen
# @return
#
function install_screen_before_reboot() {
    e_arrow "${FUNCNAME[0]}"
    curl -SLs https://apt.adafruit.com/add-pin | sudo bash
    sudo apt-get install -y raspberrypi-bootloader adafruit-pitft-helper raspberrypi-kernel
}


#
# do_reboot
# reboot the thing
# @return
#
do_reboot() {
    e_arrow "Rebooting in 10 seconds."
    sudo shutdown -r 10
}


#
# install_screen_after_reboot
# Runs after reboot to finish configuring the screen
# @param    screen_size
# @return
#
function install_screen_after_reboot() {
    local param=$1; shift
    e_arrow "${FUNCNAME[0]}"
    if ! sudo adafruit-pitft-helper -t "${param}" -u /home/hypriot; then {
        e_error "Unable to install screen"
    } fi
}


#
# configure_wifi
# Configures wifi
# @return
#
function configure_wifi() {
    e_arrow "${FUNCNAME[0]}"
    local ssid=$1; shift
    local wifi_pass=$2; shift

echo "
network={
    ssid=${ssid}
    psk=${wifi_pass}
}
" | sudo tee -a /etc/wpa_supplicant/wpa_supplicant.conf

}


#
# setup_kiosk
# Installs and configures our Kiosk mode
# @return
#
function setup_kiosk() {
    e_arrow "${FUNCNAME[0]}"
    unifi_url=$1; shift
    screen_packages=(
        xserver-xorg
        xinit
        xserver-xorg-video-fbdev
        lxde-core
        lxappearance
        lightdm
        matchbox
        chromium-browser
        )

    e_arrow "Installing dependancies"
    install_utilities "${screen_packages[@]}"

e_arrow "Setup Kiosk startup script"
echo "#!/bin/bash
xset +dpms
xset s blank
xset 0 0 120
openbox-session &
while true; do
  /usr/bin/chromium-browser \\
    --no-touch-pinch \\
    --kiosk \\
    --no-first-run \\
    --disable-3d-apis \\
    --disable-breakpad \\
    --disable-crash-reporter \\
    --disable-infobars \\
    --disable-session-crashed-bubble \\
    --disable-translate \\
    --no-sandbox \
    ${unifi_url}
done" | sudo tee -a /opt/unifi_kiosk.sh
    sudo /bin/chmod +x /opt/unifi_kiosk.sh

e_arrow "Creating Systemd Unit for Kiosk"
echo "[Unit]
Description=Start Unifi Kiosk
Wants=unifi_kiosk.service
After=unifi_kiosk.service
[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/bin/startx /etc/X11/Xsession /opt/unifi_kiosk.sh
# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=300
[Install]
WantedBy=multi-user.target
" | sudo tee -a /lib/systemd/system/unifi_kiosk.service

    /bin/ln -s /lib/systemd/system/unifi_kiosk.service /etc/systemd/system/unifi_kiosk.target.wants/unifi_kiosk.service

    e_arrow "  Allowing Unifi to start an xsession"
    /bin/sed -i "s/allowed_users=console/allowed_users=anybody/" /etc/X11/Xwrapper.config
}