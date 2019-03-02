#!/bin/bash

CURRENT_WORK_DIR=$(cd `dirname $0`; pwd)
source ${CURRENT_WORK_DIR}/config.properties

function usage()
{
    echo "Usage: install.sh [--help]"
    echo ""
    echo "install redis."
    echo ""
    echo "  --help                  : help."
    echo ""
    echo "  --package               : package."
    echo "  --install               : install."
    echo "  --create-root-certs     : create root certs."
    echo "  --create-node-certs     : create node certs."
    echo "  --create-client-certs   : create clientcerts."
    echo "  --uninstall             : uninstall."
}

function check_install()
{
    install_package_path=${CURRENT_WORK_DIR}/${SOFTWARE_SOURCE_PACKAGE_NAME}
    check_file ${install_package_path}
    if [ $? != 0 ]; then
    	echo "Install package ${install_package_path} do not exist."
      return 1
    fi

    service_file_path=${CURRENT_WORK_DIR}/${SOFTWARE_SERVICE_NAME}
    check_file ${service_file_path}
    if [ $? != 0 ]; then
    	echo "Service file ${service_file_path} do not exist."
      return 1
    fi

    return 0
}

function check_user_group()
{
    local tmp=$(cat /etc/group | grep ${1}: | grep -v grep)

    if [ -z "$tmp" ]; then
        return 2
    else
        return 0
    fi
}

function check_user()
{
   if id -u ${1} >/dev/null 2>&1; then
        return 0
    else
        return 2
    fi
}

function check_file()
{
    if [ -f ${1} ]; then
        return 0
    else
        return 2
    fi
}

function check_dir()
{
    if [ -d ${1} ]; then
        return 0
    else
        return 2
    fi
}

function install()
{
    check_install
    if [ $? != 0 ]; then
        echo "Check install failed,check it please."
        return 1
    fi

    check_user_group ${SOFTWARE_USER_GROUP}
    if [ $? != 0 ]; then
    	groupadd ${SOFTWARE_USER_GROUP}

    	echo "Add user group ${SOFTWARE_USER_GROUP} success."
    fi

    check_user ${SOFTWARE_USER_NAME}
    if [ $? != 0 ]; then
    	useradd -g ${SOFTWARE_USER_GROUP} -m ${SOFTWARE_USER_NAME}
        usermod -L ${SOFTWARE_USER_NAME}

        echo "Add user ${SOFTWARE_USER_NAME} success."
    fi

    father_dir=`dirname ${SOFTWARE_INSTALL_PATH}`
    mkdir -p ${father_dir}
    chmod 755 ${father_dir}
    mkdir -p ${SOFTWARE_INSTALL_PATH}
    chmod 700 ${SOFTWARE_INSTALL_PATH}
    mkdir -p ${SOFTWARE_INSTALL_PATH}/certs
    chmod 700 ${SOFTWARE_INSTALL_PATH}/certs
    mkdir -p ${SOFTWARE_INSTALL_PATH}/safe-dir
    chmod 700 ${SOFTWARE_INSTALL_PATH}/safe-dir
    chown ${SOFTWARE_USER_NAME}:${SOFTWARE_USER_GROUP} ${SOFTWARE_INSTALL_PATH}

    father_dir=`dirname ${SOFTWARE_DATA_PATH}`
    mkdir -p ${father_dir}
    chmod 755 ${father_dir}
    mkdir -p ${SOFTWARE_DATA_PATH}
    chmod 700 ${SOFTWARE_DATA_PATH}
    mkdir -p ${SOFTWARE_DATA_PATH}/tmp
    chmod 700 ${SOFTWARE_DATA_PATH}/tmp
    chown -R ${SOFTWARE_USER_NAME}:${SOFTWARE_USER_GROUP} ${SOFTWARE_DATA_PATH}

    father_dir=`dirname ${SOFTWARE_LOG_PATH}`
    mkdir -p ${father_dir}
    chmod 755 ${father_dir}
    mkdir -p ${SOFTWARE_LOG_PATH}
    chmod 700 ${SOFTWARE_LOG_PATH}
    chown ${SOFTWARE_USER_NAME}:${SOFTWARE_USER_GROUP} ${SOFTWARE_LOG_PATH}

    package_path=${CURRENT_WORK_DIR}/${SOFTWARE_SOURCE_PACKAGE_NAME}
    tar zxvf ${package_path} -C ${CUR_WORK_DIR}/
    cp -rf ${CUR_WORK_DIR}/${SOFTWARE_INSTALL_PACKAGE_NAME}/* ${SOFTWARE_INSTALL_PATH}

    chown -R ${SOFTWARE_USER_NAME}:${SOFTWARE_USER_GROUP} ${SOFTWARE_INSTALL_PATH}
    chmod -R u=rwx,g=rwx,o=r ${SOFTWARE_INSTALL_PATH}

    return 0
}

function config()
{
    cp ${CURRENT_WORK_DIR}/${SOFTWARE_SERVICE_NAME} /etc/init.d/${SOFTWARE_SERVICE_NAME}

    src=SOFTWARE_USER_NAME
    dst=${SOFTWARE_USER_NAME}
    sed -i "s#$src#$dst#g" /etc/init.d/${SOFTWARE_SERVICE_NAME}

    src=SOFTWARE_INSTALL_PATH
    dst=${SOFTWARE_INSTALL_PATH}
    sed -i "s#$src#$dst#g" /etc/init.d/${SOFTWARE_SERVICE_NAME}

    src=SOFTWARE_LOG_PATH
    dst=${SOFTWARE_LOG_PATH}
    sed -i "s#$src#$dst#g" /etc/init.d/${SOFTWARE_SERVICE_NAME}

    src=SOFTWARE_DATA_PATH
    dst=${SOFTWARE_DATA_PATH}
    sed -i "s#$src#$dst#g" /etc/init.d/${SOFTWARE_SERVICE_NAME}

    src=COCKROACHDB_MASTER_HOSTS
    dst=${COCKROACHDB_MASTER_HOSTS}
    sed -i "s#$src#$dst#g" /etc/init.d/${SOFTWARE_SERVICE_NAME}

    src=COCKROACHDB_HOST
    dst=${COCKROACHDB_HOST}
    sed -i "s#$src#$dst#g" /etc/init.d/${SOFTWARE_SERVICE_NAME}

    src=COCKROACHDB_PORT
    dst=${COCKROACHDB_PORT}
    sed -i "s#$src#$dst#g" /etc/init.d/${SOFTWARE_SERVICE_NAME}

    src=COCKROACHDB_UI_PORT
    dst=${COCKROACHDB_UI_PORT}
    sed -i "s#$src#$dst#g" /etc/init.d/${SOFTWARE_SERVICE_NAME}

    chmod 755 /etc/init.d/${SOFTWARE_SERVICE_NAME}
    chkconfig --add ${SOFTWARE_SERVICE_NAME}

    echo "Install success,
    please run cmd to create user for ui:
    cockroach sql --host=localhost:26258
    CREATE USER user WITH PASSWORD 'pass'; "
}

function create_root_certs() {
    ${SOFTWARE_INSTALL_PATH}/cockroach cert create-ca --certs-dir=${SOFTWARE_INSTALL_PATH}/certs --ca-key=${SOFTWARE_INSTALL_PATH}/safe-dir/ca.key
    #for host in ${COCKROACHDB_NODE_HOST_LIST[@]}; do
    #    scp ${SOFTWARE_INSTALL_PATH}/certs/ca.crt root@$host:${SOFTWARE_INSTALL_PATH}/certs/ca.crt
    #    scp ${SOFTWARE_INSTALL_PATH}/safe-dir/ca.key root@$host:${SOFTWARE_INSTALL_PATH}/safe-dir/ca.key
    #done
    chown -R ${SOFTWARE_USER_NAME}:${SOFTWARE_USER_GROUP} ${SOFTWARE_INSTALL_PATH}
}

function create_node_certs() {
    ${SOFTWARE_INSTALL_PATH}/cockroach cert create-node ${COCKROACHDB_HOST} --certs-dir=${SOFTWARE_INSTALL_PATH}/certs --ca-key=${SOFTWARE_INSTALL_PATH}/safe-dir/ca.key
    chown -R ${SOFTWARE_USER_NAME}:${SOFTWARE_USER_GROUP} ${SOFTWARE_INSTALL_PATH}
}

function create_client_certs() {
    ${SOFTWARE_INSTALL_PATH}/cockroach cert create-client root --certs-dir=${SOFTWARE_INSTALL_PATH}/certs --ca-key=${SOFTWARE_INSTALL_PATH}/safe-dir/ca.key
    chown -R ${SOFTWARE_USER_NAME}:${SOFTWARE_USER_GROUP} ${SOFTWARE_INSTALL_PATH}
}

function package()
{

    install_package_path=${CURRENT_WORK_DIR}/${SOFTWARE_SOURCE_PACKAGE_NAME}
    check_file ${install_package_path}
    if [ $? == 0 ]; then
    	echo "Package file ${install_package_path} exists."
        return 0
    else
        install_package_path=${PACKAGE_REPO_DIR}/${SOFTWARE_SOURCE_PACKAGE_NAME}
        check_file ${install_package_path}
        if [ $? == 0 ]; then
            cp -rf ${install_package_path} ./
        else
            wget https://binaries.cockroachdb.com/${SOFTWARE_SOURCE_PACKAGE_NAME}
        fi
    fi
}

function uninstall()
{
    rm -rf ${SOFTWARE_INSTALL_PATH}
    rm -rf ${SOFTWARE_LOG_PATH}
    rm -rf ${SOFTWARE_DATA_PATH}

    chkconfig --del ${SOFTWARE_SERVICE_NAME}
    rm /etc/init.d/${SOFTWARE_SERVICE_NAME}

    echo "Uninstall success."
    return 0
}

if [ $# -eq 0 ]; then
    usage
    exit
fi

opt=$1

if [ "${opt}" == "--package" ]; then
    package
elif [ "${opt}" == "--install" ]; then
    if [ ! `id -u` = "0" ]; then
        echo "Please run as root user"
        exit 2
    fi

    install
    if [ $? != 0 ]; then
        echo "Install failed,check it please."
        return 1
    fi
    config
elif [ "${opt}" == "--create-root-certs" ]; then
    create_root_certs
elif [ "${opt}" == "--create-node-certs" ]; then
    create_node_certs
elif [ "${opt}" == "--create-client-certs" ]; then
    create_client_certs
elif [ "${opt}" == "--uninstall" ]; then
    if [ ! `id -u` = "0" ]; then
        echo "Please run as root user"
        exit 2
    fi
    uninstall
elif [ "${opt}" == "--help" ]; then
    usage
else
    echo "Unknown argument"
fi