#!/usr/bin/env bash

export SCRIPT_DIR=$(mktemp --directory)

SRC_DIR=$(dirname $(dirname $(readlink -f "$0")))/src
source ${SRC_DIR}/_functions.sh --root

cp -r ${SRC_DIR}/* ${SCRIPT_DIR}
chmod +x ${SCRIPT_DIR}/*.sh

if [[ -z ${1:-""} ]]
then
    SERVICES=$(cat ${SCRIPT_DIR}/services.txt)
else
    SERVICES=($1)
    shift
fi

if [[ -z ${1:-""} ]]
then
    BRANCH=master
else
    BRANCH="$1"
    shift
fi

if [[ ${SKIP_BOOTSTRAP:-0} -ne 1 ]]
then
    ${SCRIPT_DIR}/bootstrap.sh
fi

if [[ ${SKIP_CLONE:-0} -ne 1 ]]
then
    for SERVICE in ${SERVICES}
    do
        if [[ "$SERVICE" == "aduser" ]]
        then
            ${SCRIPT_DIR}/clone.sh ${SERVICE} develop
        elif [[ "$SERVICE" == "adserver" ]]
        then
            ${SCRIPT_DIR}/clone.sh ${SERVICE} develop
        elif [[ "$SERVICE" == "adpanel" ]]
        then
            ${SCRIPT_DIR}/clone.sh ${SERVICE} develop
        else
            ${SCRIPT_DIR}/clone.sh ${SERVICE} ${BRANCH}
        fi

        [[ -e ${CONFIG_DIR}/${SERVICE}.env ]] && cp -n ${CONFIG_DIR}/${SERVICE}.env ${VENDOR_DIR}/${SERVICE}/.env
    done
fi

${SCRIPT_DIR}/prepare-directories.sh

if [[ ${SKIP_CONFIGURE:-0} -ne 1 ]]
then
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
        ${SCRIPT_DIR}/configure-daemon.sh nginx ${VENDOR_DIR}/${SERVICE}/deploy
        ${SCRIPT_DIR}/configure-daemon.sh supervisor ${VENDOR_DIR}/${SERVICE}/deploy
    done
fi

export SERVICE_NAME=${VENDOR_NAME}
${SCRIPT_DIR}/configure-daemon.sh fpm-pool ${SCRIPT_DIR} /etc/php/7.2/fpm/pool.d php7.2-fpm

CONFIG_FILE=${ETC_DIR}/config.env

source ${CONFIG_FILE}

if [[ ${INSTALL_CERT_NGINX:-0} -eq 1 ]]
then
    certbot --nginx
fi

rm -rf ${SCRIPT_DIR}

${SCRIPT_DIR}/prepare-directories.sh

echo "DONE"
