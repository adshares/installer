#!/usr/bin/env bash
set -e

if [[ $EUID -ne 0 ]]
then
    echo "You need to be root to run $0" >&2
    exit 1
fi

echo "Work in progress"
exit 127
