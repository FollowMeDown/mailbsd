#!/usr/bin/env bash

# -------------------------------------------------------
# ------------------- Nginx -----------------------------
# -------------------------------------------------------

nginx_config()
{
    ECHO_INFO "Configure Nginx web server."

    backup_file ${NGINX_CONF} ${NGINX_CONF_SITE_DEFAULT} ${PHP_FPM_POOL_WWW_CONF}

    # Make sure we have an empty directory
    [ -d ${HTTPD_CONF_DIR_AVAILABLE_CONF} ] && mv ${HTTPD_CONF_DIR_AVAILABLE_CONF} ${HTTPD_CONF_DIR_AVAILABLE_CONF}.bak
    [ ! -d ${HTTPD_CONF_DIR_AVAILABLE_CONF} ] && mkdir -p ${HTTPD_CONF_DIR_AVAILABLE_CONF}

    [ -d ${HTTPD_CONF_DIR_ENABLED_CONF} ] && mv ${HTTPD_CONF_DIR_ENABLED_CONF} ${HTTPD_CONF_DIR_ENABLED_CONF}.bak
    [ ! -d ${HTTPD_CONF_DIR_ENABLED_CONF} ] && mkdir -p ${HTTPD_CONF_DIR_ENABLED_CONF}

    # Directory used to store virtual web hosts config files
    [ -d ${HTTPD_CONF_DIR_AVAILABLE_SITES} ] && mv ${HTTPD_CONF_DIR_AVAILABLE_SITES} ${HTTPD_CONF_DIR_AVAILABLE_SITES}.bak
    [ ! -d ${HTTPD_CONF_DIR_AVAILABLE_SITES} ] && mkdir -p ${HTTPD_CONF_DIR_AVAILABLE_SITES}

    [ -d ${HTTPD_CONF_DIR_ENABLED_SITES} ] && mv ${HTTPD_CONF_DIR_ENABLED_SITES} ${HTTPD_CONF_DIR_ENABLED_SITES}.bak
    [ ! -d ${HTTPD_CONF_DIR_ENABLED_SITES} ] && mkdir -p ${HTTPD_CONF_DIR_ENABLED_SITES}

    #
    # Modular config files
    #
    # Copy sample files
    cp ${SAMPLE_DIR}/nginx/nginx.conf ${NGINX_CONF}
    cp -f ${SAMPLE_DIR}/nginx/conf-available/*.conf ${HTTPD_CONF_DIR_AVAILABLE_CONF}

    #
    # Enable modular config files
    #
    _modular_conf='0-general.conf
        cache.conf
        client_max_body_size.conf
        default_type.conf
        gzip.conf
        headers.conf
        log.conf
        mime_types.conf
        sendfile.conf
        server_tokens.conf
        types_hash_max_size.conf'

    [ X"${MAILBSD_USE_PHP}" == X'YES' ] && _modular_conf="${_modular_conf} php-fpm.conf"

    for cf in ${_modular_conf}; do
        ln -s ${HTTPD_CONF_DIR_AVAILABLE_CONF}/${cf} ${HTTPD_CONF_DIR_ENABLED_CONF}/${cf} >> ${INSTALL_LOG} 2>&1
    done

    #
    # Default sites
    #
    cp -f ${SAMPLE_DIR}/nginx/sites-available/00-default.conf ${NGINX_CONF_SITE_DEFAULT}
    cp -f ${SAMPLE_DIR}/nginx/sites-available/00-default-ssl.conf ${NGINX_CONF_SITE_DEFAULT_SSL}
    ln -s ${NGINX_CONF_SITE_DEFAULT} ${HTTPD_CONF_DIR_ENABLED_SITES} >> ${INSTALL_LOG} 2>&1
    ln -s ${NGINX_CONF_SITE_DEFAULT_SSL} ${HTTPD_CONF_DIR_ENABLED_SITES} >> ${INSTALL_LOG} 2>&1

    # Template configuration snippets.
    [ ! -d ${NGINX_CONF_TMPL_DIR} ] && mkdir -p ${NGINX_CONF_TMPL_DIR}
    cp ${SAMPLE_DIR}/nginx/templates/*.tmpl ${NGINX_CONF_TMPL_DIR}
    perl -pi -e 's#PH_NGINX_CONF_TMPL_DIR#$ENV{NGINX_CONF_TMPL_DIR}#g' \
        ${HTTPD_CONF_DIR_AVAILABLE_SITES}/*.conf \
        ${NGINX_CONF_TMPL_DIR}/*tmpl

    # nginx.conf
    perl -pi -e 's#PH_HTTPD_USER#$ENV{HTTPD_USER}#g' ${NGINX_CONF}
    perl -pi -e 's#PH_NGINX_PID#$ENV{NGINX_PID}#g' ${NGINX_CONF}
    perl -pi -e 's#PH_HTTPD_CONF_DIR_ENABLED_SITES#$ENV{HTTPD_CONF_DIR_ENABLED_SITES}#g' ${NGINX_CONF}
    perl -pi -e 's#PH_HTTPD_CONF_DIR_ENABLED_CONF#$ENV{HTTPD_CONF_DIR_ENABLED_CONF}#g' ${NGINX_CONF}

    #
    # conf-available/*.conf
    #
    perl -pi -e 's#PH_HTTPD_LOG_ERRORLOG#$ENV{HTTPD_LOG_ERRORLOG}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/log.conf
    perl -pi -e 's#PH_HTTPD_LOG_ACCESSLOG#$ENV{HTTPD_LOG_ACCESSLOG}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/log.conf
    perl -pi -e 's#PH_NGINX_MIME_TYPES#$ENV{NGINX_MIME_TYPES}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/mime_types.conf

    perl -pi -e 's#PH_PHP_FPM_BIND_HOST#$ENV{PHP_FPM_BIND_HOST}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/php-fpm.conf
    perl -pi -e 's#PH_PHP_FPM_PORT#$ENV{PHP_FPM_PORT}#g' ${HTTPD_CONF_DIR_AVAILABLE_CONF}/php-fpm.conf

    #
    # web sites
    #
    perl -pi -e 's#PH_HTTPD_PORT#$ENV{HTTPD_PORT}#g' ${HTTPD_CONF_DIR_AVAILABLE_SITES}/*.conf
    perl -pi -e 's#PH_HTTPD_DOCUMENTROOT#$ENV{HTTPD_DOCUMENTROOT}#g' ${HTTPD_CONF_DIR_AVAILABLE_SITES}/*.conf

    # ssl
    perl -pi -e 's#PH_HTTPS_PORT#$ENV{HTTPS_PORT}#g' ${HTTPD_CONF_DIR_AVAILABLE_SITES}/*.conf
    perl -pi -e 's#PH_SSL_CERT_FILE#$ENV{SSL_CERT_FILE}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SSL_KEY_FILE#$ENV{SSL_KEY_FILE}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SSL_CIPHERS#$ENV{SSL_CIPHERS}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SSL_DH1024_PARAM_FILE#$ENV{SSL_DH1024_PARAM_FILE}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # Roundcube
    perl -pi -e 's#PH_RCM_HTTPD_ROOT_SYMBOL_LINK#$ENV{RCM_HTTPD_ROOT_SYMBOL_LINK}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # iRedAdmin
    perl -pi -e 's#PH_IREDADMIN_HTTPD_ROOT_SYMBOL_LINK#$ENV{IREDADMIN_HTTPD_ROOT_SYMBOL_LINK}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_IREDADMIN_BIND_ADDRESS#$ENV{IREDADMIN_BIND_ADDRESS}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_IREDADMIN_LISTEN_PORT#$ENV{IREDADMIN_LISTEN_PORT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # SOGo
    perl -pi -e 's#PH_SOGO_BIND_ADDRESS#$ENV{SOGO_BIND_ADDRESS}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SOGO_BIND_PORT#$ENV{SOGO_BIND_PORT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SOGO_GNUSTEP_DIR#$ENV{SOGO_GNUSTEP_DIR}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_SOGO_PROXY_TIMEOUT#$ENV{SOGO_PROXY_TIMEOUT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # netdata
    perl -pi -e 's#PH_NETDATA_HTTPD_AUTH_FILE#$ENV{NETDATA_HTTPD_AUTH_FILE}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl
    perl -pi -e 's#PH_NETDATA_PORT#$ENV{NETDATA_PORT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # Adminer
    perl -pi -e 's#PH_HTTPD_SERVERROOT#$ENV{HTTPD_SERVERROOT}#g' ${NGINX_CONF_TMPL_DIR}/*.tmpl

    # php-fpm
    if [ X"${MAILBSD_USE_PHP}" == X'YES' ]; then
        # Update php-fpm.conf
        perl -pi -e 's#^(error_log)( =.*)#$1 = syslog#g' ${PHP_FPM_CONF}
        perl -pi -e 's#;(error_log)( =.*)#$1 = syslog#g' ${PHP_FPM_CONF}
        perl -pi -e 's#^(syslog.facility)( =.*)#$1 = $ENV{MAILBSD_SYSLOG_FACILITY}#g' ${PHP_FPM_CONF}
        perl -pi -e 's#;(syslog.facility)( =.*)#$1 = $ENV{MAILBSD_SYSLOG_FACILITY}#g' ${PHP_FPM_CONF}
        perl -pi -e 's#^(syslog.ident)( =.*)#$1 = php-fpm#g' ${PHP_FPM_CONF}
        perl -pi -e 's#;(syslog.ident)( =.*)#$1 = php-fpm#g' ${PHP_FPM_CONF}
        perl -pi -e 's#^(pid)( =.*)#$1 = $ENV{PHP_FPM_PID_FILE}#g' ${PHP_FPM_CONF}
        perl -pi -e 's#;(pid)( =.*)#$1 = $ENV{PHP_FPM_PID_FILE}#g' ${PHP_FPM_CONF}

        # Create php-fpm conf directory
        mkdir -p ${PHP_FPM_POOL_DIR} >> ${INSTALL_LOG} 2>&1
        cp ${SAMPLE_DIR}/php/fpm/pool.d/www.conf ${PHP_FPM_POOL_WWW_CONF} >> ${INSTALL_LOG} 2>&1

        perl -pi -e 's#PH_HTTPD_USER#$ENV{HTTPD_USER}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_HTTPD_GROUP#$ENV{HTTPD_GROUP}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_LOCAL_ADDRESS#$ENV{LOCAL_ADDRESS}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_PORT#$ENV{PHP_FPM_PORT}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_POOL_MAX_CHILDREN#$ENV{PHP_FPM_POOL_MAX_CHILDREN}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_POOL_START_SERVERS#$ENV{PHP_FPM_POOL_START_SERVERS}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_POOL_MIN_SPARE_SERVERS#$ENV{PHP_FPM_POOL_MIN_SPARE_SERVERS}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_POOL_MAX_SPARE_SERVERS#$ENV{PHP_FPM_POOL_MAX_SPARE_SERVERS}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_POOL_MAX_CHILDREN#$ENV{PHP_FPM_POOL_MAX_CHILDREN}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_URI_STATUS#$ENV{PHP_FPM_URI_STATUS}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_URI_PING#$ENV{PHP_FPM_URI_PING}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_POOL_REQUEST_TERMINATE_TIMEOUT#$ENV{PHP_FPM_POOL_REQUEST_TERMINATE_TIMEOUT}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_REQUEST_SLOWLOG_TIMEOUT#$ENV{PHP_FPM_REQUEST_SLOWLOG_TIMEOUT}#g' ${PHP_FPM_POOL_WWW_CONF}

        perl -pi -e 's#PH_PHP_FPM_LOG_MAIN#$ENV{PHP_FPM_LOG_MAIN}#g' ${PHP_FPM_POOL_WWW_CONF}
        perl -pi -e 's#PH_PHP_FPM_LOG_SLOW#$ENV{PHP_FPM_LOG_SLOW}#g' ${PHP_FPM_POOL_WWW_CONF}

        # Create log directory
        mkdir -p ${PHP_FPM_LOG_DIR} >> ${INSTALL_LOG} 2>&1
        touch ${PHP_FPM_LOG_MAIN} ${PHP_FPM_LOG_SLOW}
        chown ${SYS_USER_SYSLOG}:${SYS_GROUP_SYSLOG} ${PHP_FPM_LOG_MAIN} ${PHP_FPM_LOG_SLOW}
        chmod 0640 ${PHP_FPM_LOG_MAIN} ${PHP_FPM_LOG_SLOW}

        # Create modular syslog config file
        if [[ X"${KERNEL_NAME}" == X'OPENBSD' ]]; then
            if ! grep "${PHP_FPM_LOG_MAIN}" ${SYSLOG_CONF} &>/dev/null; then
                # '!!' means abort further evaluation after first match
                echo '!!php-fpm' >> ${SYSLOG_CONF}
                echo "${MAILBSD_SYSLOG_FACILITY}.*        ${PHP_FPM_LOG_MAIN}" >> ${SYSLOG_CONF}
            fi

            # Remove unused log file to avoid confusion.
            rm -f /var/log/php-fpm.log &>/dev/null

            if ! grep "${PHP_FPM_LOG_MAIN}" /etc/newsyslog.conf &>/dev/null; then
                cat >> /etc/newsyslog.conf <<EOF
${PHP_FPM_LOG_MAIN}    ${HTTPD_USER}:${HTTPD_GROUP}   600  7     *    24    Z    ${PHP_FPM_PID_FILE}
EOF
            fi

            if ! grep "${PHP_FPM_LOG_SLOW}" /etc/newsyslog.conf &>/dev/null; then
                cat >> /etc/newsyslog.conf <<EOF
${PHP_FPM_LOG_SLOW}    ${HTTPD_USER}:${HTTPD_GROUP}   600  7     *    24    Z    ${PHP_FPM_PID_FILE}
EOF
            fi
        fi
    fi

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable unchrooted Nginx
        echo 'nginx_flags="-u"' >> ${RC_CONF_LOCAL}
    fi

    cat >> ${TIP_FILE} <<EOF
Nginx:
    * Configuration files:
        - ${NGINX_CONF}
        - ${NGINX_CONF_SITE_DEFAULT}
        - ${NGINX_CONF_SITE_DEFAULT_SSL}
    * Directories:
        - ${HTTPD_CONF_ROOT}
        - ${HTTPD_DOCUMENTROOT}
    * See also:
        - ${HTTPD_DOCUMENTROOT}/index.html

php-fpm:
    * Configuration files: ${PHP_FPM_POOL_WWW_CONF}

EOF

    echo 'export status_nginx_config="DONE"' >> ${STATUS_FILE}
}
