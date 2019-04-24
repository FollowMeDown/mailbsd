#!/usr/bin/env bash

# Purpose:  Install & config necessary packages for iRedAPD.

iredapd_install()
{
    ECHO_INFO "Configure iRedAPD (postfix policy daemon)."

    # Extract source tarball.
    cd ${PKG_MISC_DIR}
    [ -d ${IREDAPD_PARENT_DIR} ] || mkdir -p ${IREDAPD_PARENT_DIR}
    extract_pkg ${IREDAPD_TARBALL} ${IREDAPD_PARENT_DIR}

    ECHO_DEBUG "Configure iRedAPD."
    # Create symbol link.
    ln -s ${IREDAPD_ROOT_DIR} ${IREDAPD_ROOT_DIR_SYMBOL_LINK} >> ${INSTALL_LOG} 2>&1

    # Set file permission.
    chown -R ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} ${IREDAPD_ROOT_DIR}
    chmod -R 0500 ${IREDAPD_ROOT_DIR}

    # Copy init rc script.

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        cp ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/rc_scripts/iredapd.openbsd ${DIR_RC_SCRIPTS}/iredapd >> ${INSTALL_LOG} 2>&1
    fi

    chmod 0755 ${DIR_RC_SCRIPTS}/iredapd >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Make iredapd starting after system startup."
    service_control enable iredapd >> ${INSTALL_LOG} 2>&1
    export ENABLED_SERVICES="${ENABLED_SERVICES} iredapd"

    # Copy sample config file.
    cd ${IREDAPD_ROOT_DIR_SYMBOL_LINK}
    cp settings.py.sample settings.py
    chown ${SYS_ROOT_USER}:${SYS_ROOT_GROUP} settings.py
    chmod -R 0400 settings.py

    echo 'export status_iredapd_install="DONE"' >> ${STATUS_FILE}
}

iredapd_initialize_db()
{
    ECHO_DEBUG "Import iRedAPD database template."

    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        ${MYSQL_CLIENT_ROOT} <<EOF
-- Create databases and user.
CREATE DATABASE IF NOT EXISTS ${IREDAPD_DB_NAME} DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;

-- Import SQL template.
USE ${IREDAPD_DB_NAME};
SOURCE ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/iredapd.mysql;
GRANT ALL ON ${IREDAPD_DB_NAME}.* TO '${IREDAPD_DB_USER}'@'${MYSQL_GRANT_HOST}' IDENTIFIED BY '${IREDAPD_DB_PASSWD}';
-- GRANT ALL ON ${IREDAPD_DB_NAME}.* TO '${IREDAPD_DB_USER}'@'${HOSTNAME}' IDENTIFIED BY '${IREDAPD_DB_PASSWD}';
FLUSH PRIVILEGES;

-- Enable greylisting by default.
SOURCE ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/enable_global_greylisting.sql;

-- Import greylisting whitelist domains.
SOURCE ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/greylisting_whitelist_domains.sql;

-- Blacklist some rDNS names
SOURCE ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/wblist_rdns.sql;
EOF

        # Generate .my.cnf file
        cat > /root/.my.cnf-${IREDAPD_DB_USER} <<EOF
[client]
host=${MYSQL_SERVER_ADDRESS}
port=${MYSQL_SERVER_PORT}
user=${IREDAPD_DB_USER}
password="${IREDAPD_DB_PASSWD}"
EOF

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        mkdir ${PGSQL_DATA_DIR}/tmp 2>/dev/null
        cp ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/SQL/*sql ${PGSQL_DATA_DIR}/tmp/ >> ${INSTALL_LOG} 2>&1
        chmod 0555 ${PGSQL_DATA_DIR}/tmp/*sql

        su - ${SYS_USER_PGSQL} -c "psql -d template1" >> ${INSTALL_LOG} 2>&1 <<EOF
-- Create user
CREATE USER ${IREDAPD_DB_USER} WITH ENCRYPTED PASSWORD '${IREDAPD_DB_PASSWD}' NOSUPERUSER NOCREATEDB NOCREATEROLE;

-- Create database
CREATE DATABASE ${IREDAPD_DB_NAME} WITH TEMPLATE template0 ENCODING 'UTF8';

ALTER DATABASE ${IREDAPD_DB_NAME} OWNER TO ${IREDAPD_DB_USER};
EOF

        su - ${SYS_USER_PGSQL} -c "psql -U ${IREDAPD_DB_USER} -d ${IREDAPD_DB_NAME}" >> ${INSTALL_LOG} 2>&1 <<EOF
-- Import SQL template
\i ${PGSQL_DATA_DIR}/tmp/iredapd.pgsql;

-- Enable greylisting by default.
\i ${PGSQL_DATA_DIR}/tmp/enable_global_greylisting.sql;

-- Import greylisting whitelist domains.
\i ${PGSQL_DATA_DIR}/tmp/greylisting_whitelist_domains.sql;

-- Blacklist some rDNS names
\i ${PGSQL_DATA_DIR}/tmp/wblist_rdns.sql;

EOF

        rm -rf ${PGSQL_DATA_DIR}/tmp >> ${INSTALL_LOG} 2>&1
    fi

    echo 'export status_iredapd_initialize_db="DONE"' >> ${STATUS_FILE}
}

iredapd_config()
{
    perl -pi -e 's#^(listen_address).*#${1} = "$ENV{IREDAPD_BIND_HOST}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(listen_port).*#${1} = "$ENV{IREDAPD_LISTEN_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(run_as_user).*#${1} = "$ENV{SYS_USER_IREDAPD}"#' ${IREDAPD_CONF}

    # SRS
    perl -pi -e 's#^(srs_forward_port).*#${1} = "$ENV{IREDAPD_SRS_FORWARD_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(srs_reverse_port).*#${1} = "$ENV{IREDAPD_SRS_REVERSE_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(srs_domain).*#${1} = "$ENV{HOSTNAME}"#' ${IREDAPD_CONF}
    export _srs_secret="$(${RANDOM_STRING})"
    perl -pi -e 's#^(srs_secrets).*#${1} = ["$ENV{_srs_secret}"]#' ${IREDAPD_CONF}

    # Log
    perl -pi -e 's#^(log_level).*#${1} = "info"#' ${IREDAPD_CONF}

    # Create log directory and log file
    [ -d ${IREDAPD_LOG_DIR} ] || mkdir -p ${IREDAPD_LOG_DIR} >> ${INSTALL_LOG} 2>&1
    touch ${IREDAPD_LOG_FILE} >> ${INSTALL_LOG} 2>&1
    chown -R ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${IREDAPD_LOG_DIR} ${IREDAPD_LOG_FILE} >> ${INSTALL_LOG} 2>&1
    chmod 0640 ${IREDAPD_LOG_DIR} ${IREDAPD_LOG_FILE} >> ${INSTALL_LOG} 2>&1

    # Backend.
    [ X"${BACKEND}" == X'OPENLDAP' ] && perl -pi -e 's#^(backend).*#${1} = "ldap"#' ${IREDAPD_CONF}
    [ X"${BACKEND}" == X'MYSQL' ] && perl -pi -e 's#^(backend).*#${1} = "mysql"#' ${IREDAPD_CONF}
    [ X"${BACKEND}" == X'PGSQL' ] && perl -pi -e 's#^(backend).*#${1} = "pgsql"#' ${IREDAPD_CONF}

    # Backend related parameters.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        perl -pi -e 's#^(ldap_uri).*#${1} = "ldap://$ENV{LDAP_SERVER_HOST}:$ENV{LDAP_SERVER_PORT}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(ldap_binddn).*#${1} = "$ENV{LDAP_BINDDN}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(ldap_bindpw).*#${1} = "$ENV{LDAP_BINDPW}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(ldap_basedn).*#${1} = "$ENV{LDAP_BASEDN}"#' ${IREDAPD_CONF}

        perl -pi -e 's#^(plugins).*#${1} = ["reject_null_sender", "wblist_rdns", "reject_sender_login_mismatch", "greylisting", "throttle", "amavisd_wblist", "ldap_maillist_access_policy"]#' ${IREDAPD_CONF}

    elif [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#^(vmail_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(vmail_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(vmail_db_name).*#${1} = "$ENV{VMAIL_DB_NAME}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(vmail_db_user).*#${1} = "$ENV{VMAIL_DB_BIND_USER}"#' ${IREDAPD_CONF}
        perl -pi -e 's#^(vmail_db_password).*#${1} = "$ENV{VMAIL_DB_BIND_PASSWD}"#' ${IREDAPD_CONF}

        perl -pi -e 's#^(plugins).*#${1} = ["reject_null_sender", "wblist_rdns", "reject_sender_login_mismatch", "greylisting", "throttle", "amavisd_wblist", "sql_alias_access_policy"]#' ${IREDAPD_CONF}
    fi

    # Amavisd database
    perl -pi -e 's#^(amavisd_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(amavisd_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(amavisd_db_name).*#${1} = "$ENV{AMAVISD_DB_NAME}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(amavisd_db_user).*#${1} = "$ENV{AMAVISD_DB_USER}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(amavisd_db_password).*#${1} = "$ENV{AMAVISD_DB_PASSWD}"#' ${IREDAPD_CONF}

    # iRedAdmin database
    perl -pi -e 's#^(iredadmin_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredadmin_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredadmin_db_name).*#${1} = "$ENV{IREDADMIN_DB_NAME}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredadmin_db_user).*#${1} = "$ENV{IREDADMIN_DB_USER}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredadmin_db_password).*#${1} = "$ENV{IREDADMIN_DB_PASSWD}"#' ${IREDAPD_CONF}

    # iRedAPD database
    perl -pi -e 's#^(iredapd_db_server).*#${1} = "$ENV{SQL_SERVER_ADDRESS}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredapd_db_port).*#${1} = "$ENV{SQL_SERVER_PORT}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredapd_db_name).*#${1} = "$ENV{IREDAPD_DB_NAME}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredapd_db_user).*#${1} = "$ENV{IREDAPD_DB_USER}"#' ${IREDAPD_CONF}
    perl -pi -e 's#^(iredapd_db_password).*#${1} = "$ENV{IREDAPD_DB_PASSWD}"#' ${IREDAPD_CONF}

    if [ X"${LOCAL_ADDRESS}" != X'127.0.0.1' ]; then
        echo "MYNETWORKS = ['${LOCAL_ADDRESS}']" >> ${IREDAPD_CONF}
    fi

    echo 'export status_iredapd_config="DONE"' >> ${STATUS_FILE}
}

iredapd_syslog_setup()
{
    ECHO_DEBUG "Generate modular syslog and log rotate config files for iRedAPD."
    if [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        if ! grep "${IREDAPD_LOG_FILE}" ${SYSLOG_CONF} &>/dev/null; then
            # '!!' means abort further evaluation after first match
            echo '' >> ${SYSLOG_CONF}
            echo '!!iredapd' >> ${SYSLOG_CONF}
            echo "${MAILBSD_SYSLOG_FACILITY}.*        ${IREDAPD_LOG_FILE}" >> ${SYSLOG_CONF}
        fi

        if ! grep "${IREDAPD_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            cat >> /etc/newsyslog.conf <<EOF
${IREDAPD_LOG_FILE}    ${SYS_USER_IREDAPD}:${SYS_GROUP_IREDAPD}   600  7     *    24    Z
EOF
        fi
    fi
    echo 'export status_iredapd_syslog_setup="DONE"' >> ${STATUS_FILE}
}


iredapd_cron_setup()
{
    # Setup cron job to clean up expired throttle tracking records.
    # Note: use ${IREDAPD_ROOT_DIR_SYMBOL_LINK} instead of ${IREDAPD_ROOT_DIR}
    # here, so that we don't need to change cron job after upgrading iRedAPD.
    cat >> ${CRON_FILE_ROOT} <<EOF
# iRedAPD: Clean up expired tracking records hourly.
1   *   *   *   *   ${PYTHON_BIN} ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/tools/cleanup_db.py >/dev/null

# iRedAPD: Convert SPF DNS record of specified domain names to IP
#          addresses/networks hourly.
2   *   *   *   *   ${PYTHON_BIN} ${IREDAPD_ROOT_DIR_SYMBOL_LINK}/tools/spf_to_greylist_whitelists.py >/dev/null

EOF

    # Disable cron jobs if we don't need to initialize database on this server.
    if [ X"${INITIALIZE_SQL_DATA}" != X'YES' ]; then
        perl -pi -e 's/(.*iredapd.*tools.*cleanup_db.py.*)/#${1}/g' ${CRON_FILE_ROOT}
        perl -pi -e 's/(.*iredapd.*tools.*spf_to_greylist_whitelists.py.*)/#${1}/g' ${CRON_FILE_ROOT}
    fi

    echo 'export status_iredapd_cron_setup="DONE"' >> ${STATUS_FILE}
}

iredapd_setup()
{
    check_status_before_run iredapd_install

    if [ X"${INITIALIZE_SQL_DATA}" == X'YES' ]; then
        check_status_before_run iredapd_initialize_db
    fi

    check_status_before_run iredapd_cron_setup
    check_status_before_run iredapd_config
    check_status_before_run iredapd_syslog_setup

    cat >> ${TIP_FILE} <<EOF
iRedAPD - Postfix Policy Server:
    * Version: ${IREDAPD_VERSION}
    * Listen address: ${IREDAPD_BIND_HOST}, port: ${IREDAPD_LISTEN_PORT}
    * SQL database account:
        - Database name: ${IREDAPD_DB_NAME}
        - Username: ${IREDAPD_DB_USER}
        - Password: ${IREDAPD_DB_PASSWD}
    * Configuration file:
        - ${IREDAPD_CONF}
    * Related files:
        - ${IREDAPD_ROOT_DIR}
        - ${IREDAPD_ROOT_DIR_SYMBOL_LINK} (symbol link to ${IREDAPD_ROOT_DIR}

EOF

    echo 'export status_iredapd_setup="DONE"' >> ${STATUS_FILE}
}
