#!/usr/bin/env bash
source $(dirname $(readlink -f "$0"))/_functions.sh --root
echo " > $0 $*"

CONFIG_FILE=${ETC_DIR}/config.env
if [[ -f ${CONFIG_FILE} ]]
then
    cat ${CONFIG_FILE}
    set -a
    source ${CONFIG_FILE}
    set +a
fi

read_env ${VENDOR_DIR}/adserver/.env || read_env ${VENDOR_DIR}/adserver/.env.dist

INSTALL_SCHEME=`php -r 'if(count($argv) == 3) echo parse_url($argv[1])[$argv[2]];' "$ADPANEL_URL" scheme 2>/dev/null`
INSTALL_HOSTNAME=`php -r 'if(count($argv) == 3) echo parse_url($argv[1])[$argv[2]];' "$ADPANEL_URL" host 2>/dev/null`
INSTALL_HOSTNAME=${INSTALL_HOSTNAME:-127.0.0.1}
INSTALL_API_HOSTNAME=`php -r 'if(count($argv) == 3) echo parse_url($argv[1])[$argv[2]];' "$APP_URL" host 2>/dev/null`
INSTALL_API_HOSTNAME=${INSTALL_API_HOSTNAME:-127.0.0.2}

read_option INSTALL_HOSTNAME       "AdPanel domain (UI for advertisers and publishers)" 1
read_option INSTALL_API_HOSTNAME   "AdServer domain (serving banners)" 1

configDefault USE_HTTPS N INSTALL
read_option INSTALL_USE_HTTPS "Configure for HTTPS?" 0 1

if [[ "${INSTALL_USE_HTTPS^^}" == "Y" ]]
then
    INSTALL_SCHEME=https
    BANNER_FORCE_HTTPS=true
    APP_PORT=443
else
    INSTALL_SCHEME=http
    BANNER_FORCE_HTTPS=false
    APP_PORT=80
fi

export INSTALL_HOSTNAME
export INSTALL_API_HOSTNAME

ADPANEL_URL="${INSTALL_SCHEME}://$INSTALL_HOSTNAME"
ADSERVER_HOST="${INSTALL_SCHEME}://${INSTALL_API_HOSTNAME}"
ADSERVER_BANNER_HOST=${ADSERVER_HOST}
APP_URL=${ADSERVER_HOST}

read_option ADSHARES_ADDRESS "ADS wallet address" 1
read_option ADSHARES_SECRET "ADS wallet secret" 1
read_option ADSHARES_NODE_HOST "ADS node hostname" 1
read_option ADSHARES_NODE_PORT "ADS node port" 1
read_option ADSHARES_OPERATOR_EMAIL "ADS wallet owner email (for balance alerts)" 1

ADSHARES_COMMAND=`which ads`
ADSHARES_WORKINGDIR="${VENDOR_DIR}/adserver/storage/wallet"
ADSERVER_ID=x`echo "${INSTALL_HOSTNAME}" | sha256sum | head -c 16`

read_option MAIL_HOST "mail smtp host" 1
read_option MAIL_PORT "mail smtp port" 1
read_option MAIL_USERNAME "mail smtp username" 1
read_option MAIL_PASSWORD "mail smtp password" 1
read_option MAIL_FROM_ADDRESS "mail from address" 1
read_option MAIL_FROM_NAME "mail from name" 1

configDefault INSTALL_ADUSER N
read_option INSTALL_ADUSER "Install local aduser service?" 0 1

if [[ "${INSTALL_ADUSER^^}" == "Y" ]]
then
    INSTALL_DATA_HOSTNAME=`php -r 'if(count($argv) == 3) echo parse_url($argv[1])[$argv[2]];' "$ADUSER_INTERNAL_LOCATION" host 2>/dev/null`
    INSTALL_DATA_HOSTNAME=${INSTALL_DATA_HOSTNAME:-127.0.0.3}
    read_option INSTALL_DATA_HOSTNAME       "AdUser domain (data API)" 1
else
    ADUSER_ENDPOINT="https://gitoku.com/"
    read_option ADUSER_ENDPOINT "External aduser service endpoint" 1

    ADUSER_INTERNAL_LOCATION="$ADUSER_ENDPOINT"
    ADUSER_EXTERNAL_LOCATION="$ADUSER_ENDPOINT"
fi

configDefault INSTALL_ADSELECT Y
read_option INSTALL_ADSELECT "Install local adselect service?" 0 1

if [[ "${INSTALL_ADSELECT^^}" != "Y" ]]
then
    ADSELECT_ENDPOINT="https://example.com"
    read_option ADSELECT_ENDPOINT "External adselect service endpoint" 1
fi

configDefault INSTALL_ADPAY Y
read_option INSTALL_ADPAY "Install local adpay service?" 0 1

if [[ "${INSTALL_ADPAY^^}" != "Y" ]]
then
    ADPAY_ENDPOINT="https://example.com"
    read_option ADPAY_ENDPOINT "External adselect service endpoint" 1
fi

configDefault INSTALL_ADPANEL Y
read_option INSTALL_ADPANEL "Install local adpanel service?" 0 1

if [[ "${INSTALL_ADPANEL^^}" != "Y" ]]
then
    ADPANEL_ENDPOINT="https://example.com"
    read_option ADPANEL_ENDPOINT "External adselect service endpoint" 1
else
    ADPANEL_BRAND_ASSETS_DIR=${ADPANEL_BRAND_ASSETS_DIR:-""}
    read_option ADPANEL_BRAND_ASSETS_DIR "Directory where custom brand assets are stored. If dir does not exist, standard assets will be used" 1
    if [[ ! -d "${ADPANEL_BRAND_ASSETS_DIR}" ]]
    then
        echo "Directory ${ADPANEL_BRAND_ASSETS_DIR} doesn't exist."
    fi
fi

configDefault INSTALL_ADSERVER_CRON Y
read_option INSTALL_ADSERVER_CRON "Install adserver cronjob?" 0 1

> ${SCRIPT_DIR}/services.txt

if [[ "${INSTALL_ADUSER^^}" == "Y" ]]
then
    ADUSER_EXTERNAL_LOCATION="${INSTALL_SCHEME}://$INSTALL_DATA_HOSTNAME"
    ADUSER_INTERNAL_LOCATION="$ADUSER_EXTERNAL_LOCATION"

    unset APP_NAME
    read_env ${VENDOR_DIR}/aduser/.env.local || read_env ${VENDOR_DIR}/aduser/.env.dist

    APP_VERSION=$(versionFromGit ${VENDOR_DIR}/aduser)
    APP_HOST=${INSTALL_DATA_HOSTNAME}
    read_option APP_NAME "AdUser Service Name" 1

    read_option RECAPTCHA_SITE_KEY "Google reCAPTCHA v3 site key" 1
    read_option RECAPTCHA_SECRET_KEY "Google reCAPTCHA v3 secret key" 1

    save_env ${VENDOR_DIR}/aduser/.env.dist ${VENDOR_DIR}/aduser/.env.local

    echo "aduser" | tee -a ${SCRIPT_DIR}/services.txt
fi

if [[ "${INSTALL_ADSELECT^^}" == "Y" ]]
then
    ADSELECT_ENDPOINT=http://localhost:8011

    read_env ${VENDOR_DIR}/adselect/.env || read_env ${VENDOR_DIR}/adselect/.env.dist

    ADSELECT_SERVER_PORT=8011
    ADSELECT_SERVER_INTERFACE=127.0.0.1

    save_env ${VENDOR_DIR}/adselect/.env.dist ${VENDOR_DIR}/adselect/.env

    echo "adselect" | tee -a ${SCRIPT_DIR}/services.txt
fi

if [[ "${INSTALL_ADPAY^^}" == "Y" ]]
then
    ADPAY_ENDPOINT=http://localhost:8012

    read_env ${VENDOR_DIR}/adpay/.env || read_env ${VENDOR_DIR}/adpay/.env.dist

    ADPAY_SERVER_PORT=8012
    ADPAY_SERVER_INTERFACE=127.0.0.1

    save_env ${VENDOR_DIR}/adpay/.env.dist ${VENDOR_DIR}/adpay/.env

    echo "adpay" | tee -a ${SCRIPT_DIR}/services.txt
fi

echo "adserver" | tee -a ${SCRIPT_DIR}/services.txt

if [[ "${INSTALL_ADPANEL^^}" == "Y" ]]
then
    ADSERVER_URL="$APP_URL"

    unset APP_ENV

    APP_HOST=${INSTALL_HOSTNAME}

    read_env ${VENDOR_DIR}/adpanel/.env || read_env ${VENDOR_DIR}/adpanel/.env.dist

    BRAND_ASSETS_DIR=${ADPANEL_BRAND_ASSETS_DIR:-""}

    save_env ${VENDOR_DIR}/adpanel/.env.dist ${VENDOR_DIR}/adpanel/.env

    echo "adpanel" | tee -a ${SCRIPT_DIR}/services.txt
fi

APP_HOST=${INSTALL_API_HOSTNAME}

configDefault ADSHARES_LICENCE_KEY "" INSTALL

read_option INSTALL_ADSHARES_LICENCE_KEY "Adshares Network Licence Key" 1

MAIL_DRIVER=log
LOG_FILE_PATH=${LOG_DIR}/adserver.log
save_env ${VENDOR_DIR}/adserver/.env.dist ${VENDOR_DIR}/adserver/.env

configDefault INSTALL_CERT_NGINX 0
if [[ "${INSTALL_SCHEME^^}" == "HTTPS" ]]
then
    INSTALL_CERTBOT=N
    read_option INSTALL_CERTBOT "Do you want to setup SSL using Let's Encrypt / certbot" 0 1
    if [[ "${INSTALL_CERTBOT^^}" == "Y" ]]
    then
        INSTALL_CERT_NGINX=1
    fi
fi

configDefault UPDATE_TARGETING 0 ADSERVER
readOption UPDATE_TARGETING "Do you want to update targeting options (0 = no, 1 = yes)" 1 ADSERVER

configDefault UPDATE_FILTERING 0 ADSERVER
readOption UPDATE_FILTERING "Do you want to update filtering options (0 = no, 1 = yes)" 1 ADSERVER

configDefault CREATE_ADMIN 0 ADSERVER
readOption CREATE_ADMIN "Do you want to update filtering options (0 = no, 1 = yes)" 1 ADSERVER

configVars | tee ${CONFIG_FILE}
