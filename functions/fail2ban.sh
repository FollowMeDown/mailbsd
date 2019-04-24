#!/usr/bin/env bash

fail2ban_config()
{
    ECHO_INFO "Configure Fail2ban (authentication failure monitor)."

    ECHO_DEBUG "Log into syslog instead of log file."
    perl -pi -e 's#^(logtarget).*#${1} = $ENV{FAIL2BAN_LOGTARGET}#' ${FAIL2BAN_MAIN_CONF}

    ECHO_DEBUG "Disable all default filters in ${FAIL2BAN_JAIL_CONF}."
    perl -pi -e 's#^(enabled).*=.*#${1} = false#' ${FAIL2BAN_JAIL_CONF}

    ECHO_DEBUG "Create Fail2ban config file: ${FAIL2BAN_JAIL_LOCAL_CONF}."
    backup_file ${FAIL2BAN_JAIL_LOCAL_CONF}
    cp -f ${SAMPLE_DIR}/fail2ban/jail.local ${FAIL2BAN_JAIL_LOCAL_CONF} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Create Fail2ban directory: ${FAIL2BAN_JAIL_CONF_DIR}."
    mkdir -p ${FAIL2BAN_JAIL_CONF_DIR} >> ${INSTALL_LOG} 2>&1

    perl -pi -e 's#PH_LOCAL_ADDRESS#$ENV{LOCAL_ADDRESS}#' ${FAIL2BAN_JAIL_LOCAL_CONF}

    ECHO_DEBUG "Copy modular Fail2ban jail config files to ${FAIL2BAN_JAIL_CONF_DIR}."
    cp -f ${SAMPLE_DIR}/fail2ban/jail.d/*.local ${FAIL2BAN_JAIL_CONF_DIR} >> ${INSTALL_LOG} 2>&1

    # Firewall command
    perl -pi -e 's#PH_FAIL2BAN_ACTION#$ENV{FAIL2BAN_ACTION}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local

    perl -pi -e 's#PH_SSHD_LOGFILE#$ENV{SSHD_LOGFILE}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_HTTPD_LOG_ERRORLOG#$ENV{HTTPD_LOG_ERRORLOG}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_RCM_LOGFILE#$ENV{RCM_LOGFILE}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_MAILLOG#$ENV{MAILLOG}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_SOGO_LOG_FILE#$ENV{SOGO_LOG_FILE}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_DOVECOT_LOG_FILE#$ENV{DOVECOT_LOG_DIR}/*.log#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local
    perl -pi -e 's#PH_FAIL2BAN_DISABLED_SERVICES#$ENV{FAIL2BAN_DISABLED_SERVICES}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local

    perl -pi -e 's#PH_SSHD_PORT#$ENV{SSHD_PORTS_WITH_COMMA}#' ${FAIL2BAN_JAIL_CONF_DIR}/*.local

    ECHO_DEBUG "Copy sample Fail2ban filter config files."
    cp -f ${SAMPLE_DIR}/fail2ban/filter.d/*.conf ${FAIL2BAN_FILTER_DIR}

    # Enable Nginx
    if [ X"${WEB_SERVER}" == X'NGINX' ]; then
        perl -pi -e 's#(enabled.*=.*)false#${1}true#' ${FAIL2BAN_JAIL_CONF_DIR}/nginx-http-auth.local
    fi

    if [ X"${USE_SOGO}" == X'YES' ]; then
        perl -pi -e 's#(enabled.*=.*)false#${1}true#' ${FAIL2BAN_JAIL_CONF_DIR}/sogo.local
    fi

    echo 'export status_fail2ban_config="DONE"' >> ${STATUS_FILE}
}
