#!/usr/bin/env bash
. "$(dirname "$0")/vm-state.sh"
exec ssh -i "$VM/id_starling" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o LogLevel=ERROR -p 2222 tester@127.0.0.1 "$@"
