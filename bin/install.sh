#!/usr/bin/env bash
set -e

if [[ $EUID -ne 0 ]]
then
    echo "You need to be root to run $0" >&2
    exit 1
fi

SRC_DIR=$(dirname $(dirname $(readlink -f "$0")))/src

if [[ -z "$1" ]]
then
    SERVICES=$(cat ${SRC_DIR}/services.txt)
else
    SERVICES="$1"
    shift
fi

if [[ -z "$1" ]]
then
    BRANCH=master
else
    BRANCH="$1"
    shift
fi

if [[ ${SKIP_BOOTSTRAP:-0} -ne 1 ]]
then
    ${SRC_DIR}/bootstrap.sh
fi

if [[ ${SKIP_CLONE:-0} -ne 1 ]]
then
    for SERVICE in ${SERVICES}
    do
        if [[ "$SERVICE" == "aduser" ]]
        then
            ${SRC_DIR}/clone.sh ${SERVICE} deploy
        elif [[ "$SERVICE" == "adserver" ]]
        then
            ${SRC_DIR}/clone.sh ${SERVICE} deploy
        elif [[ "$SERVICE" == "adpanel" ]]
        then
            ${SRC_DIR}/clone.sh ${SERVICE} deploy
        else
            ${SRC_DIR}/clone.sh ${SERVICE} ${BRANCH}
        fi
    done
fi

${SRC_DIR}/prepare-directories.sh

export DEBUG_MODE=1

if [[ ${SKIP_CONFIGURE:-0} -ne 1 ]]
then
    sudo --preserve-env --user=${INSTALLATION_USER} ${SRC_DIR}/configure.sh
fi

if [[ ${SKIP_SERVICES:-0} -ne 1 ]]
then
    for SERVICE in ${SERVICES}
    do
        export SERVICE_NAME=${SERVICE}
        ${SRC_DIR}/run-target.sh build /opt/adshares/${SERVICE} /opt/adshares/${SERVICE}/deploy ${INSTALLATION_USER} ${SRC_DIR} /opt/adshares/${SERVICE}

        ${SRC_DIR}/configure-daemon.sh nginx /opt/adshares/${SERVICE}/deploy
        ${SRC_DIR}/configure-daemon.sh supervisor /opt/adshares/${SERVICE}/deploy
    done
fi

${SRC_DIR}/configure-daemon.sh fpm ${SRC_DIR} /etc/php/7.2/fpm/pool.d php7.2-fpm

rm -rf ${SRC_DIR}
