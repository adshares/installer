#!/usr/bin/env bash
source $(dirname $(readlink -f "$0"))/_functions.sh --root
echo " > $0 $*"

export DEBIAN_FRONTEND=noninteractive

apt-get --yes update
apt-get --yes install software-properties-common git curl gettext-base unzip supervisor vim htop screen tree

# ===

curl https://dl.yarnpkg.com/debian/pubkey.gpg -sS | apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

# ===

add-apt-repository --yes ppa:adshares/releases
add-apt-repository --yes ppa:certbot/certbot

# ===

TEMP_DIR=$(mktemp --directory)

# ===

DIST_ID=$(lsb_release -si)

if [[ "${DIST_ID^^}" != "UBUNTU" ]]
then
    if [[ "${DIST_ID^^}" != "LINUXMINT" ]]
    then
        echo "Unsupported > $DIST_ID < distribution."
        exit 1
    fi

    if [[ ! -f /etc/os-release ]]
    then
        echo "Missing > os-release < file."
        exit 1
    fi

    source /etc/os-release

    if [[ -z ${UBUNTU_CODENAME:-""} ]]
    then
        echo "Missing > UBUNTU_CODENAME < value."
        exit 1
    fi

    LSB_RELEASE_BACKUP=$(cat /etc/lsb-release)
    DISTRIB_CODENAME="${UBUNTU_CODENAME}"

    source /etc/lsb-release
    {
        echo "DISTRIB_ID=${ID_LIKE}"
        echo "DISTRIB_RELEASE=${DISTRIB_RELEASE}"
        echo "DISTRIB_CODENAME=${UBUNTU_CODENAME}"
        echo "DISTRIB_DESCRIPTION=${DISTRIB_DESCRIPTION}"
    } > /etc/lsb-release

    _NEED_TO_REVERT_LSB=1
fi

PERCONA_FILE=percona-release_latest.$(lsb_release -sc)_all.deb
curl https://repo.percona.com/apt/${PERCONA_FILE} -sS -o ${TEMP_DIR}/${PERCONA_FILE}
dpkg --install ${TEMP_DIR}/${PERCONA_FILE} || echo "Couldn't install Percona"

if [[ ${_NEED_TO_REVERT_LSB:-0} -eq 1 ]]
then
    echo "$LSB_RELEASE_BACKUP" > /etc/lsb-release
    unset _NEED_TO_REVERT_LSB
    unset LSB_RELEASE_BACKUP
fi

# ===

apt-get --yes update
apt-get --yes --no-install-recommends install \
    python python-pip python-dev gcc \
    php7.2-fpm php7.2-mysql php7.2-bcmath php7.2-bz2 php7.2-curl php7.2-gd php7.2-intl php7.2-mbstring php7.2-sqlite3 php7.2-zip php7.2-simplexml php-apcu \
    ads nginx percona-server-server-5.7 percona-server-client-5.7 nodejs yarn mongodb \
    certbot python-certbot-nginx apt-transport-https
phpenmod apcu

# ===

pip install --system pipenv

# === ElasticSearch
curl https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.1.1-amd64.deb -sS -o ${TEMP_DIR}/elasticsearch-7.1.1-amd64.deb
curl  https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.1.1-amd64.deb.sha512 -sS -o ${TEMP_DIR}/elasticsearch-7.1.1-amd64.deb.sha512
#shasum -a 512 -c ${TEMP_DIR}/elasticsearch-7.1.1-amd64.deb.sha512
dpkg --install ${TEMP_DIR}/elasticsearch-7.1.1-amd64.deb || echo "Couldn't install ElasticSearch"

/bin/systemctl daemon-reload
/bin/systemctl enable elasticsearch.service

systemctl start elasticsearch.service

# ===

COMPOSER_INSTALLER_FILENAME="composer-installer.php"
curl https://getcomposer.org/installer -sS -o ${TEMP_DIR}/${COMPOSER_INSTALLER_FILENAME}
test $(sha384sum ${TEMP_DIR}/${COMPOSER_INSTALLER_FILENAME} | head -c 96) == "48e3236262b34d30969dca3c37281b3b4bbe3221bda826ac6a9a62d6444cdb0dcd0615698a5cbe587c3f0fe57a54d8f5"
php ${TEMP_DIR}/${COMPOSER_INSTALLER_FILENAME} --install-dir=/usr/local/bin --filename=composer

# ===

rm -rf ${TEMP_DIR}

# ===

DB_USERNAME=${VENDOR_NAME}
DB_PASSWORD=${VENDOR_NAME}

echo "CREATE USER IF NOT EXISTS '$DB_USERNAME'@'%' IDENTIFIED BY '$DB_PASSWORD';" | mysql
echo 'FLUSH PRIVILEGES;' | mysql
echo "SELECT User,Host FROM mysql.user;" | mysql

DB_DATABASES=("${VENDOR_NAME}_adserver" "${VENDOR_NAME}_aduser")

for DB_DATABASE in ${DB_DATABASES[@]}
do
    mysql=( mysql )

    if [[ "$DB_DATABASE" ]]
    then
        echo "CREATE DATABASE IF NOT EXISTS \`$DB_DATABASE\`;" | "${mysql[@]}"
        mysql+=( "$DB_DATABASE" )
    fi

    echo "GRANT ALL ON \`$DB_DATABASE\`.* TO '$DB_USERNAME'@'%';" | "${mysql[@]}"
    echo 'FLUSH PRIVILEGES;' | "${mysql[@]}"
done

# ===

crontab -r &> /dev/null || echo "No crontab to remove"

if [[ ${CONFIG_DB_CRON_BACKUP:-0} -eq 1 ]]
then
    TEMP_FILE="$(mktemp)-crontab.txt"

    {
        echo "### Controlled by an external script - all changes will be overwritten ###"
        echo "5 5 * * * mongodump --out ${BACKUP_DIR}/mongo-\$(date -u -Iseconds)                                              &> /dev/null"
        echo "6 6 * * * mysqldump --add-drop-table --all-databases --result-file=${BACKUP_DIR}/mysql-\$(date -u -Iseconds).sql &> /dev/null"
    } | tee ${TEMP_FILE}

    crontab ${TEMP_FILE}
fi
