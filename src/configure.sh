#!/usr/bin/env bash
source $(dirname $(readlink -f "$0"))/_functions.sh --root
echo " > $0 $*"

CONFIG_FILE=${ETC_DIR}/config.env
if [[ -f ${CONFIG_FILE} ]]
then
    set -a
    source ${CONFIG_FILE}
    set +a
fi

read_env ${VENDOR_DIR}/adserver/.env || read_env ${VENDOR_DIR}/adserver/.env.dist

configDefault HOSTNAME `php -r 'if(count($argv) == 3) echo parse_url($argv[1])[$argv[2]];' "$ADPANEL_URL" host 2>/dev/null` INSTALL
readOption HOSTNAME "AdPanel domain (UI for advertisers and publishers)" 0 INSTALL

configDefault API_HOSTNAME `php -r 'if(count($argv) == 3) echo parse_url($argv[1])[$argv[2]];' "$APP_URL" host 2>/dev/null` INSTALL
readOption API_HOSTNAME "AdServer domain (serving banners)" 0 INSTALL

configDefault DATA_HOSTNAME `php -r 'if(count($argv) == 3) echo parse_url($argv[1])[$argv[2]];' "$ADUSER_BASE_URL" host 2>/dev/null` INSTALL
readOption DATA_HOSTNAME "AdUser domain (data API)" 0 INSTALL
echo ">$INSTALL_DATA_HOSTNAME<"

configDefault HTTPS 1 INSTALL
readOption HTTPS "Configure for HTTPS?" 1 INSTALL

if [[ "${INSTALL_HTTPS^^}" == "Y" ]] || [[ ${INSTALL_HTTPS:-0} -eq 1 ]] || [[ "${INSTALL_USE_HTTPS^^}" == "Y" ]] || [[ ${INSTALL_USE_HTTPS} -eq 1 ]]
then
    INSTALL_HTTPS=1
    INSTALL_SCHEME=https
    BANNER_FORCE_HTTPS=true
    APP_PORT=443
else
    INSTALL_HTTPS=0
    INSTALL_SCHEME=http
    BANNER_FORCE_HTTPS=false
    APP_PORT=80
fi

configDefault ADSELECT 1 INSTALL
readOption ADSELECT "Install local >AdSelect< service?" 1 INSTALL

if [[ "${INSTALL_ADSELECT^^}" == "Y" ]] || [[ ${INSTALL_ADSELECT:-0} -eq 1 ]]
then
    INSTALL_ADSELECT=1
    ADSELECT_ENDPOINT=http://localhost:8011

    read_env ${VENDOR_DIR}/adselect/.env || read_env ${VENDOR_DIR}/adselect/.env.dist

    ADSELECT_SERVER_PORT=8011
    ADSELECT_SERVER_INTERFACE=127.0.0.1

    save_env ${VENDOR_DIR}/adselect/.env.dist ${VENDOR_DIR}/adselect/.env
else
    INSTALL_ADSELECT=0
    ADSELECT_ENDPOINT="https://example.com"
    readOption ADSELECT_ENDPOINT "External AdSelect service endpoint"
fi

configDefault ADPAY 1 INSTALL
readOption ADPAY "Install local >AdPay< service?" 1 INSTALL

if [[ "${INSTALL_ADPAY^^}" == "Y" ]] || [[ ${INSTALL_ADPAY:-0} -eq 1 ]]
then
    INSTALL_ADPAY=1
    ADPAY_ENDPOINT=http://localhost:8012

    read_env ${VENDOR_DIR}/adpay/.env || read_env ${VENDOR_DIR}/adpay/.env.dist

    ADPAY_SERVER_PORT=8012
    ADPAY_SERVER_INTERFACE=127.0.0.1

    save_env ${VENDOR_DIR}/adpay/.env.dist ${VENDOR_DIR}/adpay/.env
else
    INSTALL_ADPAY=0
    ADPAY_ENDPOINT="https://example.com"
    readOption ADPAY_ENDPOINT "External AdPay service endpoint"
fi

configDefault ADUSER 1 INSTALL
readOption ADUSER "Install local >AdUser< service?" 1 INSTALL

if [[ "${INSTALL_ADUSER^^}" == "Y" ]] || [[ ${INSTALL_ADUSER:-0} -eq 1 ]]
then
    INSTALL_ADUSER=1

    unset APP_NAME

    read_env ${VENDOR_DIR}/aduser/.env.local || read_env ${VENDOR_DIR}/aduser/.env.local.dist

    APP_SECRET=${APP_SECRET:-"`date | sha256sum | head -c 64`"}
    APP_VERSION=$(versionFromGit ${VENDOR_DIR}/aduser)
    APP_HOST=${INSTALL_DATA_HOSTNAME}
    readOption APP_NAME "AdUser Service Name"

    readOption RECAPTCHA_SITE_KEY "Google reCAPTCHA v3 site key"
    readOption RECAPTCHA_SECRET_KEY "Google reCAPTCHA v3 secret key"

    TRACKING_SECRET=${TRACKING_SECRET:-${ADUSER_TRACKING_SECRET:-"`date | sha256sum | head -c 64`"}}

    save_env ${VENDOR_DIR}/aduser/.env.local.dist ${VENDOR_DIR}/aduser/.env.local

    ADUSER_BASE_URL="${INSTALL_SCHEME}://${INSTALL_DATA_HOSTNAME}"
else
    INSTALL_ADUSER=0
    configDefault ADUSER_ENDPOINT "${INSTALL_SCHEME}://${INSTALL_DATA_HOSTNAME}"
    readOption ADUSER_ENDPOINT "External AdUser service endpoint"

    ADUSER_BASE_URL="$ADUSER_ENDPOINT"
fi

configDefault ADSERVER 1 INSTALL
readOption ADUSER "Install local >AdServer< service?" 1 INSTALL

if [[ "${INSTALL_ADSERVER^^}" == "Y" ]] || [[ ${INSTALL_ADSERVER:-0} -eq 1 ]]
then
    INSTALL_ADSERVER=1

    APP_URL="${INSTALL_SCHEME}://${INSTALL_API_HOSTNAME}"
    APP_ID=${APP_ID:"x`echo "${INSTALL_HOSTNAME}" | sha256sum | head -c 16`"}
    APP_KEY=${APP_KEY:-"base64:`date | sha256sum | head -c 32 | base64`"}

    readOption ADSHARES_ADDRESS "ADS wallet address"
    readOption ADSHARES_SECRET "ADS wallet secret"
    readOption ADSHARES_NODE_HOST "ADS node hostname"
    readOption ADSHARES_NODE_PORT "ADS node port"
    readOption ADSHARES_OPERATOR_EMAIL "ADS wallet owner email (for balance alerts)"
    ADSHARES_COMMAND=`which ads`
    ADSHARES_WORKINGDIR="${VENDOR_DIR}/adserver/storage/wallet"

    readOption MAIL_HOST "mail smtp host"
    readOption MAIL_PORT "mail smtp port"
    readOption MAIL_USERNAME "mail smtp username"
    readOption MAIL_PASSWORD "mail smtp password"
    readOption MAIL_FROM_ADDRESS "mail from address"
    readOption MAIL_FROM_NAME "mail from name"
else
    INSTALL_ADSERVER=0
fi

ADPANEL_URL="${INSTALL_SCHEME}://$INSTALL_HOSTNAME"

configDefault ADSERVER_CRON 1 INSTALL
if [[ "${INSTALL_ADSERVER_CRON^^}" == "Y" ]] || [[ ${INSTALL_ADSERVER_CRON:-0} -eq 1 ]]
then
    INSTALL_ADSERVER_CRON=1
else
    INSTALL_ADSERVER_CRON=0
fi
readOption ADSERVER_CRON "Install AdServer cron jobs?" 1 INSTALL

configDefault ADPANEL 1 INSTALL
readOption ADPANEL "Install local >AdPanel< service?" 1 INSTALL

if [[ "${INSTALL_ADPANEL^^}" == "Y" ]] || [[ ${INSTALL_ADPANEL:-0} -eq 1 ]]
then
    INSTALL_ADPANEL=1
    ADSERVER_URL="$APP_URL"

    unset APP_ENV

    APP_HOST=${INSTALL_HOSTNAME}

    read_env ${VENDOR_DIR}/adpanel/.env || read_env ${VENDOR_DIR}/adpanel/.env.dist

    BRAND_ASSETS_DIR=${ADPANEL_BRAND_ASSETS_DIR:-""}

    save_env ${VENDOR_DIR}/adpanel/.env.dist ${VENDOR_DIR}/adpanel/.env

    ADPANEL_BRAND_ASSETS_DIR=${ADPANEL_BRAND_ASSETS_DIR:-""}
    readOption ADPANEL_BRAND_ASSETS_DIR "Directory where custom brand assets are stored. If dir does not exist, standard assets will be used" 0
    if [[ ! -d "${ADPANEL_BRAND_ASSETS_DIR}" ]]
    then
        echo "Directory ${ADPANEL_BRAND_ASSETS_DIR} doesn't exist."
    fi
else
    INSTALL_ADPANEL=0
    configDefault ADPANEL_ENDPOINT "${INSTALL_SCHEME}://${INSTALL_HOSTNAME}"
    readOption ADPANEL_ENDPOINT "External AdPanel service endpoint"
fi

APP_HOST=${INSTALL_API_HOSTNAME}

configDefault LICENSE_KEY "SRV-000000" ADSHARES
configDefault LICENSE_SERVER_URL "https://account.e11.click" ADSHARES

readOption ADSHARES_LICENSE_KEY "Adshares Network LICENSE Key" 0

LOG_FILE_PATH=${LOG_DIR}/adserver.log
APP_DEBUG=1
APP_ENV=debug
DATABASE_URL=mysql://adshares:adshares@127.0.0.1:3306/aduser
save_env ${VENDOR_DIR}/adserver/.env.dist ${VENDOR_DIR}/adserver/.env

configDefault CERTBOT_NGINX 0 INSTALL
if [[ "${INSTALL_SCHEME^^}" == "HTTPS" ]]
then
    readOption CERTBOT_NGINX "Do you want to setup SSL using Let's Encrypt / certbot" 1 INSTALL
fi

configDefault UPDATE_TARGETING 0 ADSERVER
readOption UPDATE_TARGETING "Do you want to update targeting options" 1 ADSERVER

configDefault UPDATE_FILTERING 0 ADSERVER
readOption UPDATE_FILTERING "Do you want to update filtering options" 1 ADSERVER

configDefault CREATE_ADMIN 0 ADSERVER
readOption CREATE_ADMIN "Do you want to create an admin user for $ADSHARES_OPERATOR_EMAIL" 1 ADSERVER

configDefault FPM_POOL 0 INSTALL
readOption FPM_POOL "Do you want to setup php-fpm pool" 1 INSTALL

configVars | tee ${CONFIG_FILE}

> ${SCRIPT_DIR}/services.txt

[[ ${INSTALL_ADSELECT:-0} -eq 1 ]] && echo "adselect" | tee -a ${SCRIPT_DIR}/services.txt && configVars ADSELECT | tee -a ${VENDOR_DIR}/adselect/.env

[[ ${INSTALL_ADPAY:-0} -eq 1 ]] && echo "adpay" | tee -a ${SCRIPT_DIR}/services.txt && configVars ADPAY | tee -a ${VENDOR_DIR}/adpay/.env

[[ ${INSTALL_ADUSER:-0} -eq 1 ]] && echo "aduser" | tee -a ${SCRIPT_DIR}/services.txt && configVars ADUSER | tee -a ${VENDOR_DIR}/aduser/.env.local

[[ ${INSTALL_ADSERVER:-0} -eq 1 ]] && echo "adserver" | tee -a ${SCRIPT_DIR}/services.txt && configVars ADSERVER | tee -a ${VENDOR_DIR}/adserver/.env

[[ ${INSTALL_ADPANEL:-0} -eq 1 ]] && echo "adpanel" | tee -a ${SCRIPT_DIR}/services.txt && configVars ADPANEL | tee -a ${VENDOR_DIR}/adpanel/.env
