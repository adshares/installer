#!/dev/null

test ${_FUNCTIONS_FILE_WAS_LOADED:-0} -eq 1 && echo "Functions file was already loaded" >&2 && exit 127
_FUNCTIONS_FILE_WAS_LOADED=1
_CONFIG_VARS=()

# Reset
ColorOff='\e[0m'        # Text Reset

# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White

# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White

# Underline
UBlack='\e[4;30m'       # Black
URed='\e[4;31m'         # Red
UGreen='\e[4;32m'       # Green
UYellow='\e[4;33m'      # Yellow
UBlue='\e[4;34m'        # Blue
UPurple='\e[4;35m'      # Purple
UCyan='\e[4;36m'        # Cyan
UWhite='\e[4;37m'       # White

# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White

# High Intensity
IBlack='\e[0;90m'       # Black
IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
IPurple='\e[0;95m'      # Purple
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White

# Bold High Intensity
BIBlack='\e[1;90m'      # Black
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIBlue='\e[1;94m'       # Blue
BIPurple='\e[1;95m'     # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White

# High Intensity backgrounds
On_IBlack='\e[0;100m'   # Black
On_IRed='\e[0;101m'     # Red
On_IGreen='\e[0;102m'   # Green
On_IYellow='\e[0;103m'  # Yellow
On_IBlue='\e[0;104m'    # Blue
On_IPurple='\e[0;105m'  # Purple
On_ICyan='\e[0;106m'    # Cyan
On_IWhite='\e[0;107m'   # White

function versionFromGit {
    local _PWD
    if [[ -z ${1:-""} ]]
    then
        _PWD="${PWD}"
    else
        _PWD="${1}"
    fi
    local GIT_TAG=$(git -C ${_PWD} tag --list --points-at HEAD | head --lines 1)
    local GIT_HASH="#"$(git -C ${_PWD} rev-parse --short HEAD)
    echo ${GIT_TAG:-${GIT_HASH}}
}

function showVars {
    if [[ ${DEBUG_MODE:-0} -eq 1 ]]
    then
        echo ""
        echo "# ==="
        echo "#"
        echo "# `readlink -f "$0"` $*"
        echo "#"
        echo "# `id`"
        echo "#"
        echo "# SERVICE_NAME: $SERVICE_NAME"
        echo "#  SERVICE_DIR: $SERVICE_DIR"
        echo "#"
        echo "# VENDOR_NAME=$VENDOR_NAME"
        echo "# VENDOR_USER=$VENDOR_USER"
        echo "#  VENDOR_DIR=$VENDOR_DIR"
        echo "#"
        echo "# BACKUP_DIR=$BACKUP_DIR"
        echo "#   DATA_DIR=$DATA_DIR"
        echo "#    ETC_DIR=$ETC_DIR"
        echo "#    LOG_DIR=$LOG_DIR"
        echo "#    RUN_DIR=$RUN_DIR"
        echo "#"
        echo "# CONFIG_DIR=$CONFIG_DIR"
        echo "# SCRIPT_DIR=$SCRIPT_DIR"
        echo "#        PWD=$PWD"
        echo "# ==="
        echo ""
    fi
}

function colorize {
    local _NAME=${1:-"ColorOff"}
    echo -e "${!_NAME}"
}

# Usage: readOption <var_name> [<message> [<max_length> [<namespace]]]
function readOption {
    local MESSAGE=${2:-""}
    local MAX_LENGTH=${3:-0}

    local PREFIX=${4:-""}
    if [[ -z ${PREFIX} ]]
    then
        VARNAME="${1}"
    else
        VARNAME="${PREFIX}_${1}"
    fi

    local ORIGINAL="${!VARNAME:-""}"

    if [[ ${MAX_LENGTH} -eq 1 ]]
    then
        if [[ "${ORIGINAL}" == "1" ]] || [[ "${ORIGINAL^^}" == "Y" ]]
        then
            ORIGINAL=1
        else
            ORIGINAL=0
        fi

        local REPLY
        read -e -p "`colorize BIWhite`${MESSAGE}`colorize` (`colorize BIRed`0 = no`colorize`, `colorize BIGreen`1 = yes`colorize`) [`colorize BIWhite`${ORIGINAL}`colorize`]: " -n ${MAX_LENGTH} REPLY
        if [[ "${REPLY}" == "1" ]] || [[ "${REPLY^^}" == "Y" ]]
        then
            REPLY=1
        elif [[ "${REPLY}" == "" ]]
        then
            REPLY=${ORIGINAL}
        else
            REPLY=0
        fi

        local _EXPR="${VARNAME}=${REPLY}"
        eval "${_EXPR}"
        echo "<<< ${_EXPR}"
    else
        read -e -p "`colorize BIWhite`${MESSAGE}`colorize`: `colorize BIGreen`" -i "${ORIGINAL}" -n ${MAX_LENGTH} ${VARNAME}
        echo -n `colorize`
        echo "<<< ${VARNAME}=\"${!VARNAME}\""
    fi
}

# Set <var_name> to (optional) <default_value>,
#   add (also optional) prefix "<namespace>_" to <var_name>
#   include <var_name> in `configVars` listing (useful for dumping environment variables)
# Usage: configDefault <var_name> [<default_value> [namespace]]
function configDefault {
    local PREFIX=${3:-""}
    local VARNAME

    if [[ -z ${PREFIX} ]]
    then
        VARNAME="${1}"
    else
        VARNAME="${PREFIX}_${1}"
    fi

    local ORIGINAL="${!VARNAME:-""}"
    local DEFAULT="${2:-""}"

    local VALUE
    if [[ -z ${ORIGINAL} ]]
    then
        VALUE="$DEFAULT"
    else
        VALUE="$ORIGINAL"
    fi

    local _EXPR

    if [[ "${VALUE}" =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]
    then
        _EXPR="${VARNAME}=${VALUE}"
    else
        _EXPR="${VARNAME}=\"${VALUE}\""
    fi

    echo ">>> ${_EXPR}"
    eval "${_EXPR}"

    _CONFIG_VARS+=(${VARNAME})
}

# Print like `env` would
#   (optionally) remove "<namespace>_" prefix
# Usage: configVars [namespace]
function configVars {
    local PREFIX=${1:-""}

    local KEY
    local VAL

    for VARNAME in ${_CONFIG_VARS[*]}
    do
        if [[ -z ${PREFIX} ]]
        then
            KEY="${VARNAME}"
        elif [[ ${VARNAME} == ${PREFIX}_* ]]
        then
            KEY="${VARNAME:${#PREFIX}}"
        else
            KEY=""
        fi

        if ! [[ -z ${KEY} ]]
        then
            if [[ "${!VARNAME}" =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]
            then
                VAL="${!VARNAME}"
            else
                VAL="'${!VARNAME}'"
            fi

            echo "${KEY}=${VAL}"
        fi
    done
}

# save current env to file based on template
# save_env (template, output file)
save_env () {
    test ! -e $1 && echo "Environment template ($1) not found." && return 1
    test -e $2 && rm "$2"

    echo -n " < Preparing environment file: $2"

    local _INITIAL_VALUES=`grep -v '^#' "$1" | sed -E 's|^([^=]+)=(.*)$|\1="${\1:-\2}"|g'`
    eval "${_INITIAL_VALUES}"

    local _NAMES=`grep -v '^#' "$1" | sed -E 's|^([^=]+)=(.*)$|\1|g'`
    local VALUE
    for VARNAME in ${_NAMES}
    do
        if [[ "${!VARNAME}" =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]
        then
            VALUE="${!VARNAME}"
        else
            VALUE="\"${!VARNAME}\""
        fi

        echo "${VARNAME}=${VALUE}" >> "$2"
    done

    echo " [DONE]"
}

# read dotenv file and export vars. Does not overwrite existing vars
# read_env(.env file)
read_env() {
    if ! [[ -e $1 ]]
    then
        echo " ! Environment file ($1) not found."
        return 1
    fi

    local _ENV=`grep -v '^#' "$1" | sed -E 's|^([^=]+)=(.*)$|\1="${\1:-\2}"|g'`

    set -a
    source <(echo ${_ENV})
    set +a
}

VENDOR_NAME=${VENDOR_NAME:-"adshares"}
VENDOR_USER=${VENDOR_USER:-"${VENDOR_NAME}"}
VENDOR_DIR=${VENDOR_DIR:-"/opt/${VENDOR_NAME}"}

BACKUP_DIR=${BACKUP_DIR:-"${VENDOR_DIR}/.backup"}
DATA_DIR=${DATA_DIR:-"/var/lib/${VENDOR_NAME}"}
ETC_DIR=${ETC_DIR:-"/etc/${VENDOR_NAME}"}
LOG_DIR=${LOG_DIR:-"/var/log/${VENDOR_NAME}"}
RUN_DIR=${RUN_DIR:-"/var/run/${VENDOR_NAME}"}
SCRIPT_DIR=${SCRIPT_DIR:-"${VENDOR_DIR}/.script"}

CONFIG_DIR=${CONFIG_DIR:-"${ETC_DIR}/conf.d"}

[[ -z ${SERVICE_NAME} ]] || SERVICE_DIR="$VENDOR_DIR/$SERVICE_NAME"

showVars "$@"

# ===

_ARGS=()
while [[ ${1:-""} != "" ]]
do
    case "$1" in
        --root )
            if [[ $EUID -ne 0 ]]
            then
                echo "You need to be root to run $0" >&2
                exit 126
            fi
        ;;
        --vendor )
            if  [[ $EUID -eq 0 ]]
            then
                echo "You cannot be root to run $0" >&2
                exit 125
            fi

            if [[ `id --user --name` != ${VENDOR_USER} ]]
            then
                echo "You need to be '$VENDOR_USER' to run $0" >&2
                exit 124
            fi
        ;;
        --force )
            OPT_FORCE=1
        ;;
        -- )
            shift
            break
        ;;
        * )
            _ARGS+=("$1")
        ;;
    esac
    shift
done

if [[ ${#_ARGS[@]} -gt 0 ]]
then
    set -- ${_ARGS[@]}
fi

unset _ARGS

# ===

set -eu
