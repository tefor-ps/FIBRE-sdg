#!/bin/bash

for owner in /home/teforadmin/tps/gitlab/fsdb25/var/sdg/runtime/jobs/*/owner; do
    [[ -f $owner ]] || continue

    pgid=$(awk -F= '$1 == "pid" { print $2 }' "$owner")
    [[ $pgid =~ ^[0-9]+$ ]] || continue

    echo "Terminating SDG worker process group $pgid"
    ps -eo pid,ppid,pgid,stat,etime,cmd |
        awk -v pgid="$pgid" 'NR == 1 || $3 == pgid'

    sudo kill -TERM -- "-$pgid"
done