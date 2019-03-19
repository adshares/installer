#!/usr/bin/env bash

#export DEBUG_MODE=1
export SCRIPT_DIR=$(mktemp --directory)
SKIP_BOOTSTRAP=1
SKIP_CLONE=1
SKIP_CONFIGURE=1

SRC_DIR=$(dirname $(dirname $(readlink -f "$0")))/src
source ${SRC_DIR}/_functions.sh --root

cp -r ${SRC_DIR}/* ${SCRIPT_DIR}

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
            ${SCRIPT_DIR}/clone.sh ${SERVICE} deploy
        elif [[ "$SERVICE" == "adserver" ]]
        then
            ${SCRIPT_DIR}/clone.sh ${SERVICE} deploy
        elif [[ "$SERVICE" == "adpanel" ]]
        then
            ${SCRIPT_DIR}/clone.sh ${SERVICE} deploy
        else
            ${SCRIPT_DIR}/clone.sh ${SERVICE} ${BRANCH}
        fi
    done
fi

${SCRIPT_DIR}/prepare-directories.sh

if [[ ${SKIP_CONFIGURE:-0} -ne 1 ]]
then
    sudo --preserve-env --user=${VENDOR_USER} ${SCRIPT_DIR}/configure.sh
fi

if [[ ${SKIP_SERVICES:-0} -ne 1 ]]
then
    for SERVICE in ${SERVICES}
    do
        export SERVICE_NAME=${SERVICE}

        if [[ -e ${VENDOR_DIR}/${SERVICE}/.env ]]
        then
            ${SCRIPT_DIR}/run-target.sh stop ${VENDOR_DIR}/${SERVICE}/deploy root ${SCRIPT_DIR} ${VENDOR_DIR}/${SERVICE}

            ${SCRIPT_DIR}/run-target.sh build ${VENDOR_DIR}/${SERVICE}/deploy ${VENDOR_USER} ${SCRIPT_DIR} ${VENDOR_DIR}/${SERVICE}

            ${SCRIPT_DIR}/run-target.sh start ${VENDOR_DIR}/${SERVICE}/deploy root ${SCRIPT_DIR} ${VENDOR_DIR}/${SERVICE}

            ${SCRIPT_DIR}/configure-daemon.sh nginx ${VENDOR_DIR}/${SERVICE}/deploy
            ${SCRIPT_DIR}/configure-daemon.sh supervisor ${VENDOR_DIR}/${SERVICE}/deploy
        else
            echo "Skipping $SERVICE_NAME."
        fi
    done
fi

${SCRIPT_DIR}/configure-daemon.sh fpm-pool ${SCRIPT_DIR} /etc/php/7.2/fpm/pool.d php7.2-fpm

rm -rf ${SCRIPT_DIR}
