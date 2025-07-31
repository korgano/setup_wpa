#!/bin/sh
#
# setup_wpa.sh
# Automates wpa_supplicant config, rc.d script, permissions, and rc.conf.local
# Usage: sh setup_wpa.sh

set -e

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

# 1) Create WPA supplicant config directory and file
mkdir -p /var/etc

cat << 'EOF' > /var/etc/wpa_supplicant_iwlwifi0_wlan0.conf
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=0
ap_scan=1
fast_reauth=1
network={
    ssid="Placeholder"
    scan_ssid=1
    priority=5
    key_mgmt=WPA-PSK
    psk="Placeholder"
    pairwise=CCMP TKIP
    group=CCMP TKIP
}
EOF

echo "Created /var/etc/wpa_supplicant_iwlwifi0_wlan0.conf"

# 2) Install the rc.d startup script
cat << 'EOF' > /etc/rc.d/wpa_supplicant
#!/bin/sh
#
# PROVIDE: wpa_supplicant
# REQUIRE: DAEMON NETWORKING if_iwlwifi
# KEYWORD: shutdown
#
# Add the following to /etc/rc.conf to enable this service:
#   wpa_supplicant_enable="YES"
#   wpa_supplicant_iface="iwlwifi0_wlan0"
#   wpa_supplicant_driver="bsd"
#   wpa_supplicant_conf="/var/etc/wpa_supplicant_iwlwifi0_wlan0.conf"
#

. /etc/rc.subr          # import rc_* functions
. /etc/network.subr     # import network helper functions

name="wpa_supplicant"
rcvar="wpa_supplicant_enable"

# load overrides from rc.conf, set defaults
load_rc_config $name

: ${wpa_supplicant_enable:="YES"}           # YES to start at boot
: ${wpa_supplicant_iface:="iwlwifi0_wlan0"} # logical WLAN interface
: ${wpa_supplicant_driver:="bsd"}          # driver backend
: ${wpa_supplicant_conf:="/var/etc/wpa_supplicant_iwlwifi0_wlan0.conf"}

# path to the wpa_supplicant binary
command="/usr/sbin/wpa_supplicant"

# pidfile lives under /var/run/<name>.<iface>.pid
pidfile="/var/run/${name}.${wpa_supplicant_iface}.pid"
logfile="/var/log/wpa_supplicant.log"

# arguments to wpa_supplicant, add debug flags (-dd) for verbose logging
command_args="-dd -B \
    -i ${wpa_supplicant_iface} \
    -D ${wpa_supplicant_driver} \
    -c ${wpa_supplicant_conf} \
    -P ${pidfile} \
    2>&1 | tee -a ${logfile}"

# override default actions
start_cmd="wpa_supplicant_start"
stop_cmd="wpa_supplicant_stop"
status_cmd="wpa_supplicant_status"

log() {
    echo "$(date '+%F %T') [${name}] $*"
}

#
# start: load driver, create interface, bring it up, then start daemon
#
wpa_supplicant_start()
{
    log "Starting wpa_supplicant service"
    
    # 1) Load the iwlwifi kernel module if not already present
    if ! kldstat -n if_iwlwifi > /dev/null 2>&1; then
        kldload if_iwlwifi \
            || err 1 "Unable to load if_iwlwifi kernel module"
    fi

    # 2) Create the wlan interface if missing
    log "Ensuring interface ${wpa_supplicant_iface} exists"
    if ! ifconfig ${wpa_supplicant_iface} > /dev/null 2>&1; then
        ifconfig iwlwifi0 create wlandev iwlwifi0 \
            || err 1 "Failed to create interface ${wpa_supplicant_iface}"
    fi

    # 3) Bring the wireless interface up
    log "Bringing up ${wpa_supplicant_iface}"
    ifconfig ${wpa_supplicant_iface} up \
        || err 1 "Could not bring up ${wpa_supplicant_iface}"

    # 4) Handle stale ctrl_iface socket
    ctrl_dir="/var/run/wpa_supplicant"
    sock="${ctrl_dir}/${wpa_supplicant_iface}"
    if [ -e "${sock}" ]; then
        log "Found existing ctrl_iface socket ${sock}"
        if [ -f "${pidfile}" ] && kill -0 "$(cat ${pidfile})" > /dev/null 2>&1; then
            log "wpa_supplicant already running PID: $(cat ${pidfile})"
            return 0
        else
            log "Removing stale socket ${sock}"
            rm -f "${sock}" || err 1 "Failed to remove stale socket"
        fi
    fi

    # 5) Start wpa_supplicant
    log "Launching wpa_supplicant"
    eval ${command} ${command_args} \
        || err 1 "wpa_supplicant failed to start"

    # 6) Wait for pidfile
    log "Waiting for PID file ${pidfile}"
    for _ in $(seq 1 10); do
        [ -f "${pidfile}" ] && break
        sleep 0.2
    done
    [ -f "${pidfile}" ] || err 1 "PID file not created"
    log "wpa_supplicant started PID: $(cat ${pidfile})"
}

#
# status: check the pidfile to see if wpa_supplicant is running
#
wpa_supplicant_status()
{
    check_pidfile "${pidfile}" "${command}"
}

#
# stop: terminate the daemon and clean up the pidfile
#
wpa_supplicant_stop()
{
    log "Stopping wpa_supplicant service"
    if [ -f "${pidfile}" ]; then
        kill -TERM "$(cat ${pidfile})" > /dev/null 2>&1 \
            || err 1 "Failed to kill wpa_supplicant PID: $(cat ${pidfile})"
        rm -f "${pidfile}"
        log "Removed PID file"
    else
        err 1 "PID file not found, is wpa_supplicant running?"
    fi
}

run_rc_command "$1"
EOF

chmod +x /etc/rc.d/wpa_supplicant
echo "Installed and made executable: /etc/rc.d/wpa_supplicant"

# 3) Generate /etc/rc.conf.local
cat << 'EOF' > /etc/rc.conf.local
wpa_supplicant_enable="YES"
wpa_supplicant_iface="iwlwifi0_wlan0"
wpa_supplicant_driver="bsd"
wpa_supplicant_conf="/var/etc/wpa_supplicant_iwlwifi0_wlan0.conf"
EOF

echo "Created /etc/rc.conf.local"

echo "Setup complete. You can now enable the service with:"
echo "  service wpa_supplicant start"