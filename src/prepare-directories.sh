#!/usr/bin/env bash
source $(dirname $(readlink -f "$0"))/_functions.sh --root
echo " > $0 $*"

id --user ${VENDOR_USER} &>/dev/null || useradd --create-home --shell /bin/bash ${VENDOR_USER}

mkdir -p ${VENDOR_DIR}

chown -R ${VENDOR_USER}:www-data ${VENDOR_DIR}

mkdir -p ${BACKUP_DIR}
mkdir -p ${DATA_DIR}
mkdir -p ${LOG_DIR}
mkdir -p ${RUN_DIR}
mkdir -p ${SCRIPT_DIR}

chown -R ${VENDOR_USER}:www-data ${BACKUP_DIR} ${DATA_DIR} ${LOG_DIR} ${RUN_DIR} ${SCRIPT_DIR}

mkdir -p ${ETC_DIR}
mkdir -p ${CONFIG_DIR}
