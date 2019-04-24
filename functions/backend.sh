#!/usr/bin/env bash

# -------------------------------------------------------
# ------------- Install and config backend. -------------
# -------------------------------------------------------
backend_install()
{
    if [ X"${BACKEND}" == X'OPENLDAP' -o X"${BACKEND}" == X'MYSQL' ]; then
        export SQL_SERVER_ADDRESS="${MYSQL_SERVER_ADDRESS}"
        export SQL_SERVER_PORT="${MYSQL_SERVER_PORT}"
        export SQL_ROOT_USER="${MYSQL_ROOT_USER}"
        export SQL_ROOT_PASSWD="${MYSQL_ROOT_PASSWD}"
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        export SQL_SERVER_ADDRESS="${PGSQL_SERVER_ADDRESS}"
        export SQL_SERVER_PORT="${PGSQL_SERVER_PORT}"
        export SQL_ROOT_USER="${PGSQL_ROOT_USER}"
        export SQL_ROOT_PASSWD="${PGSQL_ROOT_PASSWD}"
    fi

    # Check whether remote MySQL server is an IPv6 address.
    SQL_SERVER_ADDRESS_IS_IPV6='NO'
    if echo ${SQL_SERVER_ADDRESS} | grep ':' &>/dev/null; then
        SQL_SERVER_ADDRESS_IS_IPV6='YES'
    fi

    # Hashed admin password. It requies Python.
    export DOMAIN_ADMIN_PASSWD_HASH="$(generate_password_hash ${DEFAULT_PASSWORD_SCHEME} ${DOMAIN_ADMIN_PASSWD_PLAIN})"

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # Install, config and initialize LDAP server
        check_status_before_run ldap_server_config
        check_status_before_run ldap_server_cron_backup

        # Setup MySQL database server.
        if [ X"${BACKEND_ORIG}" == X'MARIADB' ]; then
            ECHO_INFO "Configure MariaDB database server."
        else
            ECHO_INFO "Configure MySQL database server."
        fi
        check_status_before_run mysql_initialize_db
        check_status_before_run mysql_generate_defaults_file_root
        check_status_before_run mysql_remove_insecure_data
        check_status_before_run mysql_cron_backup

    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        check_status_before_run mysql_setup

    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        check_status_before_run pgsql_setup
    fi
}
