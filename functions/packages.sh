#!/usr/bin/env bash

install_all()
{
    ALL_PKGS=''
    ENABLED_SERVICES=''
    DISABLED_SERVICES=''

    # OpenBSD only
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        PKG_SCRIPTS=''

        if [ X"${DISTRO_VERSION}" == X'6.4' ]; then
            OB_PKG_PHP_VER='-7.2.10'
            OB_PKG_OPENLDAP_SERVER_VER='-2.4.46p0'
            OB_PKG_OPENLDAP_CLIENT_VER='-2.4.46'
        else
            # 6.5
            OB_PKG_PHP_VER='-7.2.16'
            OB_PKG_OPENLDAP_SERVER_VER='-2.4.47p0'
            OB_PKG_OPENLDAP_CLIENT_VER='-2.4.47p0'
        fi

    fi

    # Install PHP if there's a web server running -- php is too popular.
    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        export MAILBSD_USE_PHP='YES'
    fi

    # Postfix.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${POSTFIX_RC_SCRIPT_NAME}"
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} postfix--sasl2-ldap%stable"
        [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} postfix--sasl2-mysql%stable"
        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} postfix--sasl2-pgsql%stable"
    fi

    # Backend: OpenLDAP, MySQL, PGSQL and extra packages.
    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        # OpenLDAP server & client.
        ENABLED_SERVICES="${ENABLED_SERVICES} ${OPENLDAP_RC_SCRIPT_NAME} ${MYSQL_RC_SCRIPT_NAME}"

        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            if [ X"${BACKEND_ORIG}" == X'OPENLDAP' ]; then
                ALL_PKGS="${ALL_PKGS} openldap-server${OB_PKG_OPENLDAP_SERVER_VER}"
                PKG_SCRIPTS="${PKG_SCRIPTS} ${OPENLDAP_RC_SCRIPT_NAME}"
            elif [ X"${BACKEND_ORIG}" == X'LDAPD' ]; then
                ALL_PKGS="${ALL_PKGS} openldap-client${OB_PKG_OPENLDAP_CLIENT_VER}"
                PKG_SCRIPTS="${PKG_SCRIPTS} ${LDAPD_RC_SCRIPT_NAME}"
            fi

            ALL_PKGS="${ALL_PKGS} mariadb-server mariadb-client p5-ldap p5-DBD-mysql"
            PKG_SCRIPTS="${PKG_SCRIPTS} ${MYSQL_RC_SCRIPT_NAME}"

        fi
    elif [ X"${BACKEND}" == X'MYSQL' ]; then
        # MySQL server & client.
        ENABLED_SERVICES="${ENABLED_SERVICES} ${MYSQL_RC_SCRIPT_NAME}"
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} mariadb-client"

            if [ X"${USE_EXISTING_MYSQL}" != X'YES' ]; then
                ALL_PKGS="${ALL_PKGS} mariadb-server p5-DBD-mysql"
                PKG_SCRIPTS="${PKG_SCRIPTS} ${MYSQL_RC_SCRIPT_NAME}"
            fi
        fi
    elif [ X"${BACKEND}" == X'PGSQL' ]; then
        ENABLED_SERVICES="${ENABLED_SERVICES} ${PGSQL_RC_SCRIPT_NAME}"

        # PGSQL server & client.
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} postgresql-client postgresql-server postgresql-contrib p5-DBD-Pg"
            PKG_SCRIPTS="${PKG_SCRIPTS} ${PGSQL_RC_SCRIPT_NAME}"
        fi
    fi

    # PHP
    if [ X"${MAILBSD_USE_PHP}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} php${OB_PKG_PHP_VER} php-bz2${OB_PKG_PHP_VER} php-imap${OB_PKG_PHP_VER} php-gd${OB_PKG_PHP_VER} php-intl${OB_PKG_PHP_VER}"

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} php-ldap${OB_PKG_PHP_VER} php-pdo_mysql${OB_PKG_PHP_VER}"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} php-pdo_mysql${OB_PKG_PHP_VER}"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} php-pdo_pgsql${OB_PKG_PHP_VER}"
        fi
    fi

    # Nginx
    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} nginx"
            PKG_SCRIPTS="${PKG_SCRIPTS} ${NGINX_RC_SCRIPT_NAME} ${PHP_FPM_RC_SCRIPT_NAME}"
        fi

        ENABLED_SERVICES="${ENABLED_SERVICES} ${NGINX_RC_SCRIPT_NAME} ${PHP_FPM_RC_SCRIPT_NAME}"
    fi

    # Dovecot.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${DOVECOT_RC_SCRIPT_NAME}"
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} dovecot dovecot-pigeonhole"
        PKG_SCRIPTS="${PKG_SCRIPTS} ${DOVECOT_RC_SCRIPT_NAME}"

        if [ X"${BACKEND}" == X'OPENLDAP' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-ldap dovecot-mysql"
        elif [ X"${BACKEND}" == X'MYSQL' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-mysql"
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            ALL_PKGS="${ALL_PKGS} dovecot-postgresql"
        fi

        DISABLED_SERVICES="${DISABLED_SERVICES} saslauthd"
    fi

    # Amavisd-new & ClamAV & Altermime.
    ENABLED_SERVICES="${ENABLED_SERVICES} ${CLAMAV_CLAMD_SERVICE_NAME} ${AMAVISD_RC_SCRIPT_NAME}"
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} rpm2cpio amavisd-new amavisd-new-utils p5-Mail-SPF p5-Mail-SpamAssassin clamav unrar altermime"
        PKG_SCRIPTS="${PKG_SCRIPTS} ${CLAMAV_CLAMD_SERVICE_NAME} ${CLAMAV_FRESHCLAMD_RC_SCRIPT_NAME} ${AMAVISD_RC_SCRIPT_NAME}"
    fi

    # mlmmj: mailing list manager
    ALL_PKGS="${ALL_PKGS} mlmmj"

    # SOGo
    if [ X"${USE_SOGO}" == X'YES' ]; then
        ENABLED_SERVICES="${ENABLED_SERVICES} ${SOGO_RC_SCRIPT_NAME} ${MEMCACHED_RC_SCRIPT_NAME}"

        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            ALL_PKGS="${ALL_PKGS} sogo memcached--"

            [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} sope-mysql"
            [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} sope-mysql"
            [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} sope-postgres"

            PKG_SCRIPTS="${PKG_SCRIPTS} ${MEMCACHED_RC_SCRIPT_NAME} ${SOGO_RC_SCRIPT_NAME}"
        fi
    fi

    # iRedAPD.
    # Don't append 'iredapd' to ${ENABLED_SERVICES} since we don't have
    # RC script ready in early stage.
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} py-sqlalchemy py-dnspython"
        [ X"${BACKEND}" == X'OPENLDAP' ] && ALL_PKGS="${ALL_PKGS} py-ldap py-mysql"
        [ X"${BACKEND}" == X'MYSQL' ] && ALL_PKGS="${ALL_PKGS} py-mysql"
        [ X"${BACKEND}" == X'PGSQL' ] && ALL_PKGS="${ALL_PKGS} py-psycopg2"
        PKG_SCRIPTS="${PKG_SCRIPTS} iredapd"
    fi

    # OpenBSD: List postfix as last startup script.
    export PKG_SCRIPTS="${PKG_SCRIPTS} ${POSTFIX_RC_SCRIPT_NAME}"

    # iRedAdmin.
    # Force install all dependence to help customers install iRedAdmin-Pro.
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} py-jinja2 py-webpy py-flup py-bcrypt py-curl py-requests py-netifaces"
    fi

    # Fail2ban
    if [ X"${USE_FAIL2BAN}" == X'YES' ]; then
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            # No port available.
            :
        else
            ALL_PKGS="${ALL_PKGS} fail2ban"
            ENABLED_SERVICES="${ENABLED_SERVICES} ${FAIL2BAN_RC_SCRIPT_NAME}"
        fi
    fi

    # Misc packages & services.
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        ALL_PKGS="${ALL_PKGS} bzip2 lz4"
    fi

    export ALL_PKGS ENABLED_SERVICES PKG_SCRIPTS

    # Install all packages.
    install_all_pkgs()
    {
        eval ${install_pkg} ${ALL_PKGS} | tee ${PKG_INSTALL_LOG}

        if [ -f ${RUNTIME_DIR}/.pkg_install_failed ]; then
            ECHO_ERROR "Installation failed, please check the terminal output."
            ECHO_ERROR "If you're not sure what the problem is, try to get help in MailBSD"
            ECHO_ERROR "forum: https://forum.mailbsd.org/"
            exit 255
        fi
    }

    # Enable/Disable services.
    enable_all_services()
    {

        # Enable/Disable services.
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            for srv in ${PKG_SCRIPTS}; do
                service_control enable ${srv} >> ${INSTALL_LOG} 2>&1
            done
        else
            service_control enable ${ENABLED_SERVICES} >> ${INSTALL_LOG} 2>&1
            service_control disable ${DISABLED_SERVICES} >> ${INSTALL_LOG} 2>&1
        fi

        cat >> ${TIP_FILE} <<EOF
* Enabled services: ${ENABLED_SERVICES}

EOF
    }

    after_package_installation()
    {
        if [ X"${DISTRO}" == X'OPENBSD' ]; then
            # Create symbol links for Python.
            ln -sf /usr/local/bin/python2.7 /usr/local/bin/python >> ${INSTALL_LOG} 2>&1
            ln -sf /usr/local/bin/python2.7-2to3 /usr/local/bin/2to3 >> ${INSTALL_LOG} 2>&1
            ln -sf /usr/local/bin/python2.7-config /usr/local/bin/python-config >> ${INSTALL_LOG} 2>&1
            ln -sf /usr/local/bin/pydoc2.7  /usr/local/bin/pydoc >> ${INSTALL_LOG} 2>&1

            # Create symbol links for php.
            if [ X"${MAILBSD_USE_PHP}" == X'YES' ]; then
                ln -sf /usr/local/bin/php-${OB_PHP_VERSION} /usr/local/bin/php >> ${INSTALL_LOG} 2>&1
                ln -sf /usr/local/bin/php-config-${OB_PHP_VERSION} /usr/local/bin/php-config >> ${INSTALL_LOG} 2>&1
                ln -sf /usr/local/bin/phpize-${OB_PHP_VERSION} /usr/local/bin/phpize >> ${INSTALL_LOG} 2>&1
                ln -sf /usr/local/bin/php-fpm-${OB_PHP_VERSION} /usr/local/bin/php-fpm >> ${INSTALL_LOG} 2>&1
            fi

            # uwsgi. Required by iRedAdmin.
            ECHO_INFO "Installing uWSGI from source tarball, please wait."
            cd ${PKG_MISC_DIR}
            tar zxf uwsgi-*.tar.gz
            cd uwsgi-*/
            python setup.py install > ${RUNTIME_DIR}/uwsgi_install.log 2>&1

            # Required by uwsgi applications.
            update_sysctl_param kern.seminfo.semmni 1024
            update_sysctl_param kern.seminfo.semmns 1200
            update_sysctl_param kern.seminfo.semmnu 60
            update_sysctl_param kern.seminfo.semmsl 120
            update_sysctl_param kern.seminfo.semopm 200
        fi

        echo 'export status_after_package_installation="DONE"' >> ${STATUS_FILE}
    }

    # Do not run them with 'check_status_before_run', so that we can always
    # install missed packages and enable/disable new services while re-run
    # iRedMail installer.
    install_all_pkgs
    enable_all_services

    check_status_before_run after_package_installation
}
