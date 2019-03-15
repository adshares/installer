#!/usr/bin/env bash
set -e

echo "## Run: $*"

[[ $# -ge 1 ]] || echo "Usage: `basename $0` <target> [[[<SCRIPT_DIR>] <sudo_as>] ...]"
TARGET="$1"
shift

SCRIPT_DIR="$1"
test -z $1 || shift

SUDO_AS="$1"
test -z $1 || shift

source $(dirname $(readlink -f "$0"))/_functions.sh any

FILE_COUNT=$(find ${SCRIPT_DIR} -maxdepth 1 -name "${TARGET}*.sh" -type f -print | wc -l)
FILE_ITEMS=$(find ${SCRIPT_DIR} -maxdepth 1 -name "${TARGET}*.sh" -type f -print)

if [[ ${FILE_COUNT} -gt 0 ]]
then
    for FILE in ${FILE_ITEMS}
    do
        if [[ -z ${SUDO_AS} ]] || [[ `id --user --name` == ${SUDO_AS} ]]
        then
            ${FILE} $@
        else
            sudo -E -i -u ${SUDO_AS} ${FILE} "$@"
        fi
    done
fi
