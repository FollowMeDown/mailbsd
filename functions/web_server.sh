#!/usr/bin/env bash

web_server_extra()
{
    # Create robots.txt.
    if [ ! -e ${HTTPD_DOCUMENTROOT}/robots.txt ]; then
        cat >> ${HTTPD_DOCUMENTROOT}/robots.txt <<EOF
User-agent: *
Disallow: /
EOF
    fi

    # Redirect home page to webmail by default
    if [ ! -e ${HTTPD_DOCUMENTROOT}/index.html ]; then
        if [ X"${USE_SOGO}" == X'YES' ]; then
            echo '<html><head><meta HTTP-EQUIV="REFRESH" content="0; url=/SOGo/"></head></html>' > ${HTTPD_DOCUMENTROOT}/index.html
        fi
    fi

    # Add alias for web server daemon user
    add_postfix_alias ${HTTPD_USER} ${SYS_ROOT_USER}

    echo 'export status_web_server_extra="DONE"' >> ${STATUS_FILE}
}

web_server_config()
{
    # Create required directories
    [ -d ${HTTPD_SERVERROOT} ] || mkdir -p ${HTTPD_SERVERROOT} >> ${INSTALL_LOG} 2>&1
    [ -d ${HTTPD_DOCUMENTROOT} ] || mkdir -p ${HTTPD_DOCUMENTROOT} >> ${INSTALL_LOG} 2>&1

    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        . ${FUNCTIONS_DIR}/nginx.sh
        check_status_before_run nginx_config
        check_status_before_run web_server_extra
    fi

    if [ X"${MAILBSD_USE_PHP}" == X'YES' ]; then
        . ${FUNCTIONS_DIR}/php.sh
        check_status_before_run php_config
    fi

    echo 'export status_web_server_config="DONE"' >> ${STATUS_FILE}
}
