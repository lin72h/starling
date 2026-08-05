#!/usr/bin/env bash
# scp-vm.sh <localfile> <remote-dest>   e.g. scp-vm.sh foo.deb '~/'
. "$(dirname "$0")/vm-state.sh"
exec scp -i "$VM/id_starling" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 -o LogLevel=ERROR -P 2222 "$1" "tester@127.0.0.1:$2"
