#!/dev/null

test ${_FUNCTIONS_FILE_WAS_LOADED:-0} -eq 1 && echo "Functions file was already loaded" >&2 && exit 127
_FUNCTIONS_FILE_WAS_LOADED=1

function versionFromGit {
    local GIT_TAG=$(git tag --list --points-at HEAD | head --lines 1)
    local GIT_HASH="#"$(git rev-parse --short HEAD)
    echo ${1:-${GIT_TAG:-${GIT_HASH}}}
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

# Usage: readOption <name> [<message> [<max_length>]]
function readOption {
    local ORIGINAL=${!1}
    local MESSAGE=${2:-""}
    local MAX_LENGTH=${3:-0}

    if [[ ${MAX_LENGTH} -eq 1 ]]
    then
        local REPLY
        read -e -p "${MESSAGE} [${ORIGINAL}]: " -n ${MAX_LENGTH} REPLY
        if [[ ! -z $REPLY ]]
        then
            eval $( echo ${1}=\$REPLY )
        fi
    else
        read -e -p "${MESSAGE}: " -i "${ORIGINAL}" -n ${MAX_LENGTH} ${1}
    fi
}

# Usage: configDefault <var_name> [[<default_value>] <namespace>]
function configDefault {
    local PREFIX=${3:-""}
    local VARNAME

    if [[ -z ${PREFIX} ]]
    then
        VARNAME="${1}"
    else
        VARNAME="${PREFIX}_${1}"
    fi

    local ORIGINAL=${!VARNAME:-""}
    local DEFAULT=${2:-""}

    local VALUE
    if [[ -z ${ORIGINAL} ]]
    then
        VALUE="$DEFAULT"
    else
        VALUE="$ORIGINAL"
    fi

    local _EXPR=$( echo ${VARNAME}=\$VALUE )
    eval ${_EXPR}

    _CONFIG_VARS+=(${VARNAME})
}

# Print like `env` would
# Usage: configVars
function configVars {
    for VARNAME in ${_CONFIG_VARS[@]}
    do
        echo "${VARNAME}=${!VARNAME}"
    done
}

# read_option opt_name, prompt, prefill, maxlength
read_option () {
    local PREV
    eval $( echo PREV=\$${1} )

    local MAXLENGTH=${4:-0}
    local REPLY

    if [[ ${3:-0} -eq 1 ]]
    then
        read -e -p "${2}: " -i "${PREV}" -n ${MAXLENGTH} ${1}
    else
        read -e -p "${2} [$PREV]: " -n ${MAXLENGTH} REPLY
        if [[ ! -z $REPLY ]]
        then
            eval $( echo ${1}=\$REPLY )
        fi
    fi
}

# save current env to file based on template
# save_env (template, output file)
save_env () {
    test ! -e $1 && echo "Environment template ($1) not found." && return 1
    test -e $2 && rm $2
    local EXPORT=$(export -p)

    echo "Preparing ($2) environment file."

    while read i
    do
        echo -n $i= >> $2
        echo "$EXPORT" | grep $i= | head -n1 | awk 'NF { st = index($0,"=");printf("%s", substr($0,st+1)) }' >> $2
        echo "" >> $2
    done < <(cat $1 | awk -F"=" 'NF {print $1}')
}

# read dotenv file and export vars. Does not overwrite existing vars
# read_env(.env file)
read_env() {
    if [ ! -e $1 ]
    then
        echo "Environment file ($1) not found."
        return 1
    fi
    source <(grep -v '^#' $1 | sed -E 's|^([^=]+)=(.*)$|: ${\1=\2}; export \1|g')
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

if [[ ${PWD} =~ ^${VENDOR_DIR}\/[^/]+ ]]
then
    SERVICE_NAME=`basename ${SCRIPT_DIR}`
    SERVICE_DIR="$VENDOR_DIR/$SERVICE_NAME"
fi

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
