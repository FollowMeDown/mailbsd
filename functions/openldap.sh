#!/usr/bin/env bash

# -------------------------------------------------------
# ------------------- OpenLDAP --------------------------
# -------------------------------------------------------

openldap_config()
{
    ECHO_INFO "Configure LDAP server: OpenLDAP."

    ECHO_DEBUG "Stoping OpenLDAP."
    service_control stop ${OPENLDAP_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1

    backup_file ${OPENLDAP_SLAPD_CONF} ${OPENLDAP_LDAP_CONF}

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable TLS/SSL support
        cat >> ${RC_CONF_LOCAL} <<EOF
slapd_flags="-u ${SYS_USER_LDAP} -f ${OPENLDAP_SLAPD_CONF} -h ldapi:///\ ldap://0.0.0.0/\ ldaps://0.0.0.0/"
EOF
    fi

    # Copy extar LDAP schema files
    cp -f ${LDAP_MAILBSD_SCHEMA} ${OPENLDAP_SCHEMA_DIR}
    cp -f ${SAMPLE_DIR}/openldap/*.schema ${OPENLDAP_SCHEMA_DIR}

    # Copy amavisd schema.
    # - On OpenBSD: package amavisd-new will copy schema file to /etc/openldap/schema
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        cp -f /usr/local/share/doc/amavisd-new/LDAP.schema ${OPENLDAP_SCHEMA_DIR}/${AMAVISD_LDAP_SCHEMA_NAME}
    fi

    ECHO_DEBUG "Generate new server configuration file: ${OPENLDAP_SLAPD_CONF}."
    cp -f ${SAMPLE_DIR}/openldap/slapd.conf ${OPENLDAP_SLAPD_CONF}
    chown ${SYS_USER_LDAP}:${SYS_GROUP_LDAP} ${OPENLDAP_SLAPD_CONF}
    chmod 0640 ${OPENLDAP_SLAPD_CONF}

    export LDAP_SUFFIX
    perl -pi -e 's#PH_OPENLDAP_SCHEMA_DIR#$ENV{OPENLDAP_SCHEMA_DIR}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_AMAVISD_LDAP_SCHEMA_NAME#$ENV{AMAVISD_LDAP_SCHEMA_NAME}#g' ${OPENLDAP_SLAPD_CONF}

    perl -pi -e 's#PH_OPENLDAP_PID_FILE#$ENV{OPENLDAP_PID_FILE}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_OPENLDAP_ARGS_FILE#$ENV{OPENLDAP_ARGS_FILE}#g' ${OPENLDAP_SLAPD_CONF}

    perl -pi -e 's#PH_OPENLDAP_MODULE_PATH#$ENV{OPENLDAP_MODULE_PATH}#g' ${OPENLDAP_SLAPD_CONF}
    if [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' -o X"${DISTRO}" == X'FREEBSD' ]; then
        perl -pi -e 's/^#(modulepath.*)/${1}/g' ${OPENLDAP_SLAPD_CONF}
        perl -pi -e 's/^#(moduleload.*back.*)/${1}/g' ${OPENLDAP_SLAPD_CONF}
    fi

    perl -pi -e 's#PH_SSL_CERT_FILE#$ENV{SSL_CERT_FILE}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_SSL_KEY_FILE#$ENV{SSL_KEY_FILE}#g' ${OPENLDAP_SLAPD_CONF}

    perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_ADMIN_DN#$ENV{LDAP_ADMIN_DN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_ADMIN_BASEDN#$ENV{LDAP_ADMIN_BASEDN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_SUFFIX#$ENV{LDAP_SUFFIX}#g' ${OPENLDAP_SLAPD_CONF}

    perl -pi -e 's#PH_OPENLDAP_DEFAULT_DBTYPE#$ENV{OPENLDAP_DEFAULT_DBTYPE}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_DATA_DIR#$ENV{LDAP_DATA_DIR}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_ROOTDN#$ENV{LDAP_ROOTDN}#g' ${OPENLDAP_SLAPD_CONF}
    perl -pi -e 's#PH_LDAP_ROOTPW_SSHA#$ENV{LDAP_ROOTPW_SSHA}#g' ${OPENLDAP_SLAPD_CONF}

    if [ X"${OPENLDAP_DEFAULT_DBTYPE}" == X'mdb' ]; then
        # maxsize is required by mdb
        perl -pi -e 's/^#(maxsize.*)/${1}/g' ${OPENLDAP_SLAPD_CONF}
    elif [ X"${OPENLDAP_DEFAULT_DBTYPE}" == X'bdb' \
        -o X"${OPENLDAP_DEFAULT_DBTYPE}" == X'hdb' ]; then
        # cachesize is required by hdb and bdb.
        perl -pi -e 's/^#(cachesize.*)//g' ${OPENLDAP_SLAPD_CONF}
    fi

    # Password verification with sha2.
    if [ X"${OPENLDAP_HAS_SHA2}" == X'YES' ]; then
        perl -pi -e 's/^#(moduleload.*)(pw_sha2)/${1}$ENV{OPENLDAP_MOD_PW_SHA2}/' ${OPENLDAP_SLAPD_CONF}
    fi

    ECHO_DEBUG "Generate new client configuration file: ${OPENLDAP_LDAP_CONF}"
    cp ${SAMPLE_DIR}/openldap/ldap.conf ${OPENLDAP_LDAP_CONF}
    perl -pi -e 's#PH_LDAP_SUFFIX#$ENV{LDAP_SUFFIX}#g' ${OPENLDAP_LDAP_CONF}
    perl -pi -e 's#PH_LDAP_SERVER_HOST#$ENV{LDAP_SERVER_HOST}#g' ${OPENLDAP_LDAP_CONF}
    perl -pi -e 's#PH_LDAP_SERVER_PORT#$ENV{LDAP_SERVER_PORT}#g' ${OPENLDAP_LDAP_CONF}
    perl -pi -e 's#PH_SSL_CERT_FILE#$ENV{SSL_CERT_FILE}#g' ${OPENLDAP_LDAP_CONF}
    chown ${SYS_USER_LDAP}:${SYS_GROUP_LDAP} ${OPENLDAP_LDAP_CONF}

    ECHO_DEBUG "Create directory used to store OpenLDAP log file: ${OPENLDAP_LOG_DIR}"
    mkdir -p ${OPENLDAP_LOG_DIR}
    chown ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${OPENLDAP_LOG_DIR}
    chmod 0750 ${OPENLDAP_LOG_DIR}

    ECHO_DEBUG "Create empty log file: ${OPENLDAP_LOG_FILE}."
    touch ${OPENLDAP_LOG_FILE}
    chown ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${OPENLDAP_LOG_FILE}
    chmod 0640 ${OPENLDAP_LOG_FILE}

    ECHO_DEBUG "Setting up syslog and logrotate config files for OpenLDAP."
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # '!!' means abort further evaluation after first match
        echo -e '!!slapd' >> ${SYSLOG_CONF}
        echo -e "*.*\t\t\t\t\t\t${OPENLDAP_LOG_FILE}" >> ${SYSLOG_CONF}

        if ! grep "${OPENLDAP_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            cat >> /etc/newsyslog.conf <<EOF
${OPENLDAP_LOG_FILE}    ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG}   640  7     *    24    Z
EOF
        fi
    fi

    echo 'export status_openldap_config="DONE"' >> ${STATUS_FILE}
}

openldap_data_initialize()
{
    ECHO_DEBUG "Create instance directory for openldap tree: ${LDAP_DATA_DIR}."
    mkdir -p ${LDAP_DATA_DIR}

    # Get DB_CONFIG.example.
    if [ X"${OPENLDAP_DEFAULT_DBTYPE}" == X'hdb' ]; then
        cp -f ${OPENLDAP_DB_CONFIG_SAMPLE} ${LDAP_DATA_DIR}/DB_CONFIG
    fi

    chown -R ${SYS_USER_LDAP}:${SYS_GROUP_LDAP} ${OPENLDAP_DATA_DIR}
    chmod -R 0700 ${OPENLDAP_DATA_DIR}

    ECHO_DEBUG "Starting OpenLDAP."
    service_control restart ${OPENLDAP_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Sleep 5 seconds for LDAP daemon initialization ..."
    sleep 5

    ECHO_DEBUG "Populate LDAP tree."
    ldapadd -x -D "${LDAP_ROOTDN}" -w "${LDAP_ROOTPW}" -f ${LDAP_INIT_LDIF} >> ${INSTALL_LOG} 2>&1

    cat >> ${TIP_FILE} <<EOF
OpenLDAP:
    * LDAP suffix: ${LDAP_SUFFIX}
    * LDAP root dn: ${LDAP_ROOTDN}, password: ${LDAP_ROOTPW}
    * LDAP bind dn (read-only): ${LDAP_BINDDN}, password: ${LDAP_BINDPW}
    * LDAP admin dn (read-write): ${LDAP_ADMIN_DN}, password: ${LDAP_ADMIN_PW}
    * LDAP base dn: ${LDAP_BASEDN}
    * LDAP admin base dn: ${LDAP_ADMIN_BASEDN}
    * Configuration files:
        - ${OPENLDAP_CONF_ROOT}
        - ${OPENLDAP_SLAPD_CONF}
        - ${OPENLDAP_LDAP_CONF}
        - ${OPENLDAP_SCHEMA_DIR}/${PROG_NAME_LOWERCASE}.schema
    * Log file related:
        - ${SYSLOG_CONF}
        - ${OPENLDAP_LOG_FILE}
        - ${OPENLDAP_LOGROTATE_FILE}
    * Data dir and files:
        - ${OPENLDAP_DATA_DIR}
        - ${LDAP_DATA_DIR}
        - ${LDAP_DATA_DIR}/DB_CONFIG (available if backend is bdb or hdb)
    * RC script:
        - ${OPENLDAP_RC_SCRIPT}
    * See also:
        - ${LDAP_INIT_LDIF}

EOF

    echo 'export status_openldap_data_initialize="DONE"' >> ${STATUS_FILE}
}

