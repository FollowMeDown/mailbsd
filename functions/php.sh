#!/usr/bin/env bash

# PHP Setting.
php_config()
{
    ECHO_INFO "Configure PHP."

    backup_file ${PHP_INI}

    # FreeBSD: Copy sample file.
    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # Enable PHP modules
        # Get php version number.
        PHP_VERSION="$(basename /etc/php-${OB_PHP_VERSION} | awk -F'-' '{print $2}')"
        for i in $(ls -d /etc/php-${PHP_VERSION}.sample/*); do
            ln -sf ${i} /etc/php-${PHP_VERSION}/$(basename $i)
        done
    fi

    ECHO_DEBUG "Hide PHP info from remote users requests: ${PHP_INI}."
    perl -pi -e 's#^(expose_php.*=).*#${1} Off;#' ${PHP_INI}

    ECHO_DEBUG "Increase 'memory_limit' to 256M: ${PHP_INI}."
    perl -pi -e 's#^(memory_limit.*=).*#${1} 256M;#' ${PHP_INI}

    ECHO_DEBUG "Increase 'upload_max_filesize', 'post_max_size' to 10/12M: ${PHP_INI}."
    perl -pi -e 's/^(upload_max_filesize.*=).*/${1} 10M;/' ${PHP_INI}
    perl -pi -e 's/^(post_max_size.*=).*/${1} 12M;/' ${PHP_INI}

    ECHO_DEBUG "Disable php extension: suhosin. ${PHP_INI}."
    perl -pi -e 's/^(suhosin.session.encrypt.*=).*/${1} Off;/' ${PHP_INI}
    perl -pi -e 's/^;(suhosin.session.encrypt.*=).*/${1} Off;/' ${PHP_INI}

    #perl -pi -e 's/^(allow_url_fopen.*=).*/${1} On/' ${PHP_INI}

    # Add setting `disable_functions`
    perl -pi -e 's#^;(disable_functions.*)#${1}#g' ${PHP_INI}
    perl -pi -e 's#^(disable_functions).*#${1} = $ENV{PHP_DISABLE_FUNCTIONS}#g' ${PHP_INI}

    # Create directory used to store session (session.save_path)
    perl -pi -e 's#^;(session.save_path).*#${1}#g' ${PHP_INI}
    perl -pi -e 's#^(session.save_path).*#session.save_path = "$ENV{PHP_SESSION_SAVE_PATH}"#g' ${PHP_INI}
    # Set correct owner and permission
    [ -d ${PHP_SESSION_SAVE_PATH} ] || mkdir -p ${PHP_SESSION_SAVE_PATH} >> ${INSTALL_LOG} 2>&1
    chown ${SYS_ROOT_USER}:${HTTPD_GROUP} ${PHP_SESSION_SAVE_PATH}
    chmod 0770 ${PHP_SESSION_SAVE_PATH}

    # Set date.timezone. Required by PHP-5.3.
    grep '^date.timezone' ${PHP_INI} >/dev/null
    if [ X"$?" == X"0" ]; then
        perl -pi -e 's#^(date.timezone).*#${1} = GMT#' ${PHP_INI}
    else
        perl -pi -e 's#^;(date.timezone).*#${1} = GMT#' ${PHP_INI}
    fi

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        ECHO_DEBUG "Disable suhosin.session.encrypt -> Off."
        echo 'suhosin.session.encrypt = Off' >> ${PHP_INI}
    fi

    cat >> ${TIP_FILE} <<EOF
PHP:
    * PHP config file for Nginx: ${NGINX_PHP_INI}
    * Disabled functions: ${PHP_DISABLE_FUNCTIONS}

EOF

    echo 'export status_php_config="DONE"' >> ${STATUS_FILE}
}
