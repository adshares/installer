#!/usr/bin/env bash
source $(dirname $(readlink -f "$0"))/_functions.sh
echo "[${SERVICE_NAME}] $0 $*"

TARGET="$1"
shift

SCRIPT_DIR=${1:-""}
test -z ${1:-""} || shift

SUDO_AS=${1:-""}
test -z ${1:-""} || shift

FILE_COUNT=$(find ${SCRIPT_DIR} -maxdepth 1 -name "${TARGET}*.sh" -type f -print | wc -l)
FILE_ITEMS=$(find ${SCRIPT_DIR} -maxdepth 1 -name "${TARGET}*.sh" -type f -print)

if [[ ${FILE_COUNT} -gt 0 ]]
then
    test -e "${VENDOR_DIR}/${SERVICE_NAME}/.env"        && set -a && source ${VENDOR_DIR}/${SERVICE_NAME}/.env       && set +a
    test -e "${VENDOR_DIR}/${SERVICE_NAME}/.env.local"  && set -a && source ${VENDOR_DIR}/${SERVICE_NAME}/.env.local && set +a
    test -e "${VENDOR_DIR}/.tmp.env"                    && set -a && source ${VENDOR_DIR}/.tmp.env                   && set +a

    for FILE in ${FILE_ITEMS}
    do
        if [[ -z ${SUDO_AS} ]] || [[ `id --user --name` == ${SUDO_AS} ]]
        then
            ${FILE} $@
        else
            sudo --preserve-env --set-home --user=${SUDO_AS} ${FILE} "$@"
        fi
    done
fi
