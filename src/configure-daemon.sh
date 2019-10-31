#!/usr/bin/env bash
source $(dirname $(readlink -f "$0"))/_functions.sh --root
echo " > $0 $*"

DAEMON_NAME="$1"
shift

SOURCE_DIR="$1"
shift

TARGET_DIR=${1:-"/etc/${DAEMON_NAME}/conf.d"}
test -z ${1:-""} || shift

DAEMON_SERVICE_NAME=${1:-${DAEMON_NAME}}
test -z ${1:-""} || shift

FILE_COUNT=$(find ${SOURCE_DIR} -maxdepth 1 -name "${DAEMON_NAME}*.conf" -type f -print | wc -l)
FILE_ITEMS=$(find ${SOURCE_DIR} -maxdepth 1 -name "${DAEMON_NAME}*.conf" -type f -print)

if [[ ${FILE_COUNT} -gt 0 ]]
then
    for FILE in ${FILE_ITEMS}
    do
        OVERWRITE_FILE=1
        TARGET_FILE=${VENDOR_NAME}-${SERVICE_NAME}-$(basename ${FILE})

        if test -f "${TARGET_DIR}/${TARGET_FILE}"; then
            echo "Previous configuration: ${TARGET_DIR}/${TARGET_FILE}"
            if test -f "${ETC_DIR}/${TARGET_FILE}.sha1" && ! sha1sum --status -c ${ETC_DIR}/${TARGET_FILE}.sha1; then
                OVERWRITE_FILE=0
                readOption OVERWRITE_FILE "Configuration file has been modified. Overwrite $(basename ${FILE})?" 1
            fi
        fi

        if [[ ${OVERWRITE_FILE} -eq 1 ]]; then
            echo "Copy ${FILE} to ${TARGET_DIR} as ${TARGET_FILE}"

            [[ -e ${VENDOR_DIR}/${SERVICE_NAME}/.env ]]       && set -a && source ${VENDOR_DIR}/${SERVICE_NAME}/.env && set +a
            [[ -e ${VENDOR_DIR}/${SERVICE_NAME}/.env.local ]] && set -a && source ${VENDOR_DIR}/${SERVICE_NAME}/.env.local && set +a

            envsubst '${SERVICE_NAME},${APP_PORT},${APP_HOST},${_APP_HOST_SERVE},${_APP_HOST_MAIN_JS},${VENDOR_NAME},${VENDOR_USER},${VENDOR_DIR},${LOG_DIR},${PHP_FPM_SOCK}' < ${FILE} | tee ${TARGET_DIR}/${TARGET_FILE}
            sha1sum ${TARGET_DIR}/${TARGET_FILE} > ${ETC_DIR}/${TARGET_FILE}.sha1
        fi
    done

    echo "Restart ${DAEMON_SERVICE_NAME}"
    systemctl restart ${DAEMON_SERVICE_NAME}
fi
