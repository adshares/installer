#!/usr/bin/env bash

export SCRIPT_DIR=$(mktemp --directory)

SRC_DIR=$(dirname $(dirname $(readlink -f "$0")))/src
source ${SRC_DIR}/_functions.sh --root

export VENDOR_NAME
export VENDOR_DIR
export VENDOR_USER

cp -r ${SRC_DIR}/* ${SCRIPT_DIR}
chmod +x ${SCRIPT_DIR}/*.sh

SERVICES=$(cat ${SCRIPT_DIR}/services.txt)
BRANCH=master

while [[ "${1:-""}" != "" ]]
do
    case "$1" in
        --service | -s )
            SERVICES=("$2")
            shift
        ;;
        --branch | -b )
            BRANCH="$2"
            shift
        ;;
    esac
    shift
done

if [[ ${SKIP_BOOTSTRAP:-0} -ne 1 ]]
then
    ${SCRIPT_DIR}/bootstrap.sh
fi

if [[ ${SKIP_CLONE:-0} -ne 1 ]]
then
    for SERVICE in ${SERVICES}
    do
        ${SCRIPT_DIR}/clone.sh ${SERVICE} ${BRANCH}

        [[ -e ${CONFIG_DIR}/${SERVICE}.env ]] && cp -n ${CONFIG_DIR}/${SERVICE}.env ${VENDOR_DIR}/${SERVICE}/.env
    done
fi

${SCRIPT_DIR}/prepare-directories.sh

rm -f ${VENDOR_DIR}/.tmp.env

if [[ ${SKIP_CONFIGURE:-0} -ne 1 ]]
then
    echo " --- Configuring services --- "

    ${SCRIPT_DIR}/configure.sh

    SERVICES=$(cat ${SCRIPT_DIR}/services.txt)
fi

${SCRIPT_DIR}/prepare-directories.sh

if [[ ${SKIP_SERVICES:-0} -ne 1 ]]
then
    for SERVICE in ${SERVICES}
    do
        export SERVICE_NAME=${SERVICE}

        ${SCRIPT_DIR}/run-target.sh stop ${VENDOR_DIR}/${SERVICE}/deploy root ${SCRIPT_DIR} ${VENDOR_DIR}/${SERVICE}
        ${SCRIPT_DIR}/run-target.sh build ${VENDOR_DIR}/${SERVICE}/deploy ${VENDOR_USER} ${SCRIPT_DIR} ${VENDOR_DIR}/${SERVICE}
        ${SCRIPT_DIR}/run-target.sh start ${VENDOR_DIR}/${SERVICE}/deploy root ${SCRIPT_DIR} ${VENDOR_DIR}/${SERVICE}

        ${SCRIPT_DIR}/configure-daemon.sh supervisor ${VENDOR_DIR}/${SERVICE}/deploy
    done
fi

CONFIG_FILE=${ETC_DIR}/config.env
echo " ### Configuring: ${CONFIG_FILE} ### "

source ${CONFIG_FILE}

export SERVICE_NAME=${VENDOR_NAME}
[[ ${INSTALL_FPM_POOL:-0} -eq 1 ]] && ${SCRIPT_DIR}/configure-daemon.sh fpm-pool ${SCRIPT_DIR} /etc/php/7.2/fpm/pool.d php7.2-fpm

if [[ ${SKIP_SERVICES:-0} -ne 1 ]] && [[ ${INSTALL_ADSERVER_CRON:-0} -eq 1 ]]
then
    TEMP_CRONTAB_FILE="$(mktemp).txt"

    for SERVICE in ${SERVICES}
    do
        export SERVICE_DIR="${VENDOR_DIR}/${SERVICE}"

        [[ -e "${SERVICE_DIR}/deploy/crontablist.sh" ]] && "${SERVICE_DIR}/deploy/crontablist.sh" | tee -a ${TEMP_CRONTAB_FILE}
    done

    crontab -u ${VENDOR_USER} ${TEMP_CRONTAB_FILE}

    rm ${TEMP_CRONTAB_FILE}
fi

if [[ ${SKIP_SERVICES:-0} -ne 1 ]]
then
    for SERVICE in ${SERVICES}
    do
        export SERVICE_NAME=${SERVICE}

        ${SCRIPT_DIR}/configure-daemon.sh nginx ${VENDOR_DIR}/${SERVICE}/deploy

        if [[ ${INSTALL_CERTBOT_NGINX:-0} -eq 1 ]]
        then
            ! [[ -z ${INSTALL_HOSTNAME} ]] && [[ ${SERVICE_NAME} == "adpanel" ]] && certbot --keep --agree-tos --redirect --nginx --cert-name ${INSTALL_HOSTNAME} --domains ${INSTALL_HOSTNAME}
            ! [[ -z ${INSTALL_API_HOSTNAME} ]] && [[ ${SERVICE_NAME} == "adserver" ]] && certbot --keep --agree-tos --redirect --nginx --cert-name ${INSTALL_API_HOSTNAME} --domains ${INSTALL_API_HOSTNAME}
            ! [[ -z ${INSTALL_DATA_HOSTNAME} ]] && [[ ${SERVICE_NAME} == "aduser" ]] && certbot --keep --agree-tos --redirect --nginx --cert-name ${INSTALL_DATA_HOSTNAME} --domains ${INSTALL_DATA_HOSTNAME}
        fi
    done
fi

rm -rf ${SCRIPT_DIR}
echo "=== DONE $0 ==="
