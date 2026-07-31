#!/usr/bin/env bash
# Network lab for the desktop's network UI — wireless and wired.
#
#   sudo test/net-sim.sh up       start the lab
#   sudo test/net-sim.sh down     stop it and remove every trace
#   test/net-sim.sh status        report state (exit 0 = up)
#
# Wireless: three simulated radios (mac80211_hwsim), two running fake access
# points, the third left for NetworkManager to scan and join like real
# hardware.
#
#   Starling-Lab    WPA2, password "starling123"   192.168.42.0/24
#   Starling-Guest  open                            192.168.43.0/24
#
# Wired: a veth pair. NetworkManager manages one end as an ordinary ethernet
# device (`starling-lan`) while the other end plays the switch. This exists so
# connect/disconnect can be exercised without touching the machine's real NIC
# — pulling that one out from under a developer takes their network with it.
#
#   starling-lan    DHCP                            192.168.44.0/24
#
# Every segment runs dnsmasq for DHCP (DNS disabled), so a client that joins
# gets a lease and NetworkManager reports a full, honest "connected" state.
#
# Exit codes: 0 ok/up, 1 error, 3 missing prerequisites (callers treat 3 as
# "skip", not "fail" — the functional tier does exactly that).
#
# The `up` path also drops a polkit rule letting the invoking user drive
# NetworkManager: a shell launched over SSH is not seat-active, so polkit
# would otherwise refuse the connect that a real GDM session is allowed.
# `down` removes it.

set -u

RUN_DIR=/run/starling-net-sim
POLKIT_RULE=/etc/polkit-1/rules.d/49-starling-net-sim.rules
SSID_WPA="Starling-Lab"
PSK_WPA="starling123"
SSID_OPEN="Starling-Guest"
LAN_IF="starling-lan"          # the end NetworkManager manages
LAN_PEER="starling-lan-sw"     # the end playing the switch

die() { echo "net-sim: $*" >&2; exit 1; }

# The three hwsim interfaces, in stable name order. Real WiFi hardware (none
# on the dev box or VM, but cheap to be robust) is never touched: interfaces
# are matched by driver, not by name.
hwsim_ifs() {
    local i drv
    for i in /sys/class/net/*; do
        drv=$(readlink -f "$i/device/driver" 2>/dev/null) || continue
        [[ "$drv" == *mac80211_hwsim* ]] && basename "$i"
    done | sort
}

cmd_status() {
    local ifs
    ifs=$(hwsim_ifs)
    if [[ -z "$ifs" ]]; then
        echo "net-sim: down (no simulated radios)"
        return 1
    fi
    echo "net-sim: radios: $(echo $ifs | tr '\n' ' ')"
    ip link show "$LAN_IF" >/dev/null 2>&1 \
        && echo "net-sim: wired $LAN_IF present" \
        || echo "net-sim: wired $LAN_IF ABSENT"
    local up=1
    for pidfile in "$RUN_DIR"/*.pid; do
        [[ -e "$pidfile" ]] || continue
        local pid
        pid=$(cat "$pidfile")
        if kill -0 "$pid" 2>/dev/null; then
            echo "net-sim: $(basename "$pidfile" .pid) running (pid $pid)"
            up=0
        else
            echo "net-sim: $(basename "$pidfile" .pid) DEAD"
        fi
    done
    return $up
}

cmd_up() {
    [[ $(id -u) -eq 0 ]] || die "up needs root (sudo)"
    command -v hostapd >/dev/null || {
        echo "net-sim: hostapd not installed (apt install hostapd dnsmasq-base) — skipping" >&2
        exit 3
    }
    command -v dnsmasq >/dev/null || {
        echo "net-sim: dnsmasq not installed (apt install dnsmasq-base) — skipping" >&2
        exit 3
    }
    command -v nmcli >/dev/null || {
        echo "net-sim: nmcli not installed (apt install network-manager) — skipping" >&2
        exit 3
    }
    systemctl is-active --quiet NetworkManager || die "NetworkManager is not running"

    modprobe mac80211_hwsim radios=3 || die "mac80211_hwsim failed to load (linux-modules-extra?)"
    sleep 1
    local ifs
    mapfile -t ifs < <(hwsim_ifs)
    [[ ${#ifs[@]} -ge 3 ]] || die "expected 3 hwsim interfaces, got: ${ifs[*]:-none}"
    local ap1=${ifs[0]} ap2=${ifs[1]} client=${ifs[2]}

    rfkill unblock wifi 2>/dev/null || true
    nmcli radio wifi on >/dev/null 2>&1 || true

    mkdir -p "$RUN_DIR"

    # The AP radios must not be NetworkManager's business.
    nmcli dev set "$ap1" managed no
    nmcli dev set "$ap2" managed no

    cat > "$RUN_DIR/hostapd-wpa.conf" <<EOF
interface=$ap1
driver=nl80211
ssid=$SSID_WPA
hw_mode=g
channel=1
wpa=2
wpa_passphrase=$PSK_WPA
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF
    cat > "$RUN_DIR/hostapd-open.conf" <<EOF
interface=$ap2
driver=nl80211
ssid=$SSID_OPEN
hw_mode=g
channel=6
EOF

    ip addr replace 192.168.42.1/24 dev "$ap1"
    ip addr replace 192.168.43.1/24 dev "$ap2"

    hostapd -B -P "$RUN_DIR/hostapd-wpa.pid" "$RUN_DIR/hostapd-wpa.conf" \
        || die "hostapd ($SSID_WPA) failed"
    hostapd -B -P "$RUN_DIR/hostapd-open.pid" "$RUN_DIR/hostapd-open.conf" \
        || die "hostapd ($SSID_OPEN) failed"

    # -p 0 disables DNS entirely: DHCP only, no port-53 fight with resolved.
    # dhcp-option 6 hands clients a DNS server so the UI's DNS row has
    # something to show; nothing answers on it (-p 0), which is honest enough
    # for a lab with no internet behind it either.
    dnsmasq -p 0 -i "$ap1" --bind-interfaces \
        --dhcp-range=192.168.42.10,192.168.42.100,12h \
        --dhcp-option=6,192.168.42.1 \
        --pid-file="$RUN_DIR/dnsmasq-wpa.pid" || die "dnsmasq ($ap1) failed"
    dnsmasq -p 0 -i "$ap2" --bind-interfaces \
        --dhcp-range=192.168.43.10,192.168.43.100,12h \
        --dhcp-option=6,192.168.43.1 \
        --pid-file="$RUN_DIR/dnsmasq-open.pid" || die "dnsmasq ($ap2) failed"

    # Wired: a veth pair. NetworkManager sees $LAN_IF as an ordinary ethernet
    # device; $LAN_PEER is the "switch" side and is kept out of its hands, or
    # NM would try to configure both ends of the same wire.
    if ! ip link show "$LAN_IF" >/dev/null 2>&1; then
        ip link add "$LAN_IF" type veth peer name "$LAN_PEER" \
            || die "could not create the veth pair"
    fi
    nmcli dev set "$LAN_PEER" managed no 2>/dev/null || true
    ip addr replace 192.168.44.1/24 dev "$LAN_PEER"
    ip link set "$LAN_PEER" up
    ip link set "$LAN_IF" up
    # NetworkManager leaves veth unmanaged by default (it assumes virtual
    # devices belong to whoever made them), so claim this end explicitly —
    # without it the device never appears in the desktop's wired UI at all.
    nmcli dev set "$LAN_IF" managed yes 2>/dev/null || true
    dnsmasq -p 0 -i "$LAN_PEER" --bind-interfaces \
        --dhcp-range=192.168.44.10,192.168.44.100,12h \
        --dhcp-option=6,192.168.44.1 \
        --pid-file="$RUN_DIR/dnsmasq-lan.pid" || die "dnsmasq ($LAN_PEER) failed"

    if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != root ]]; then
        cat > "$POLKIT_RULE" <<EOF
// Installed by starling-desktop test/net-sim.sh — removed by "down".
// Lets the dev/test user drive NetworkManager from a non-seat session.
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 &&
        subject.user == "$SUDO_USER") {
        return polkit.Result.YES;
    }
});
EOF
    fi

    echo "net-sim: up — $SSID_WPA (wpa2, $PSK_WPA) on $ap1, $SSID_OPEN (open) on $ap2," \
         "client radio $client, wired $LAN_IF"
}

cmd_down() {
    [[ $(id -u) -eq 0 ]] || die "down needs root (sudo)"
    for pidfile in "$RUN_DIR"/*.pid; do
        [[ -e "$pidfile" ]] || continue
        kill "$(cat "$pidfile")" 2>/dev/null
        rm -f "$pidfile"
    done
    rm -f "$POLKIT_RULE"
    rm -rf "$RUN_DIR"
    # Saved test profiles would silently auto-join the next lab run and make
    # "does a fresh connect work" tests pass vacuously — delete them.
    if command -v nmcli >/dev/null; then
        nmcli connection delete "$SSID_WPA" >/dev/null 2>&1
        nmcli connection delete "$SSID_OPEN" >/dev/null 2>&1
        # NM auto-creates the wired profile under a name of its own choosing
        # ("Wired connection 2"), so find it by the device it is bound to —
        # and do it before the link goes away, or that binding is gone too.
        nmcli -t -f NAME,DEVICE connection show 2>/dev/null \
            | awk -F: -v d="$LAN_IF" '$2 == d { print $1 }' \
            | while read -r name; do
                nmcli connection delete "$name" >/dev/null 2>&1
            done
    fi
    # Deleting either end removes the pair.
    ip link del "$LAN_IF" 2>/dev/null
    modprobe -r mac80211_hwsim 2>/dev/null
    echo "net-sim: down"
}

case "${1:-}" in
    up)     cmd_up ;;
    down)   cmd_down ;;
    status) cmd_status ;;
    *)      echo "usage: $0 up|down|status" >&2; exit 1 ;;
esac
