#!/usr/bin/env bash -e
function usage() {
    echo "usage: $0 [TF_CMD] [ENV] [TARGET_DIR] (TF_OPTS)"
    echo "  ex) $0 plan stg aws/main/s3 -no-color"
}

function init_shell() {
    source ${BASE_DIR}/_env_ini/tfenv_${ENV}.ini
    if [ -n "${TF_AWS_ACCESS_KEY_ID}" -a -n "${TF_AWS_SECRET_ACCESS_KEY}" ]; then
        export AWS_ACCESS_KEY_ID=${TF_AWS_ACCESS_KEY_ID}
        export AWS_SECRET_ACCESS_KEY=${TF_AWS_SECRET_ACCESS_KEY}
        BACKEND_PARAMS="-backend-config access_key=${TF_AWS_ACCESS_KEY_ID} -backend-config secret_key=${TF_AWS_SECRET_ACCESS_KEY}"
    else
        export AWS_PROFILE=${AWS_PROFILE}
        BACKEND_PARAMS="-backend-config profile=${AWS_PROFILE}"
    fi

    ### copy tempate files
    cp -fr ${BASE_DIR}/${PROVIDER}/_template/__*.tf ${BASE_DIR}/${TARGET_DIR}/

    cd ${BASE_DIR}/${TARGET_DIR}
    ### terraform init
    terraform init \
      -backend-config "key=state/${TARGET_DIR}.tfstate"  \
      -backend-config "bucket=${S3_BUCKET}" \
      -backend-config "region=${S3_REGION}" \
      ${BACKEND_PARAMS} \
      -force-copy -reconfigure >&2

    ### switch workspace
    terraform workspace list | tr -d ' ' | tr -d \* | grep ^${ENV}$ >/dev/null 2>&1 | :
    RET=${PIPESTATUS[3]}
    if [[ ${RET} -ne 0 ]]; then
        terraform workspace new ${ENV}
    elif [ "$(terraform workspace show)" != ${ENV} ]; then
        terraform workspace select ${ENV}
    fi
    terraform workspace list

    cd ${BASE_DIR}
}

function term_shell() {
    rm -rf ${BASE_DIR}/${TARGET_DIR}/__*.tf
}

##### MAIN
trap 'term_shell; exit' EXIT

BASE_DIR=$(cd $(dirname $0);pwd)
TF_CMD=$1
ENV=$2
TARGET_DIR=${3%/}
TF_OPTS=${@:4}
PROVIDER=${TARGET_DIR%%/*}  # first before slash str

[ $# -eq 0 ] && (usage; exit 128)
[ $1 == '-h' -o $1 == '--help' ] && (usage; exit 128)
[ ! -e ${BASE_DIR}/${TARGET_DIR} ] && (echo "TARGET_DIR not found." && exit 1)

init_shell

cd ${BASE_DIR}/${TARGET_DIR}
terraform ${TF_CMD} ${TF_OPTS}
