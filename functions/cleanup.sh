#!/usr/bin/env bash

# Available variables for automate installation (value should be 'y' or 'n'):
#
#   AUTO_CLEANUP_REMOVE_MOD_PYTHON
#   AUTO_CLEANUP_REPLACE_FIREWALL_RULES
#   AUTO_CLEANUP_RESTART_IPTABLES
#   AUTO_CLEANUP_REPLACE_MYSQL_CONFIG
#
# Usage:
#   # AUTO_CLEANUP_REMOVE_...=y [...] bash MailBSD.sh

# -------------------------------------------
# Misc.
# -------------------------------------------
# Set cron file permission to 0600.
cleanup_set_cron_file_permission()
{
    for f in ${CRON_FILE_ROOT} ${CRON_FILE_AMAVISD} ${CRON_FILE_SOGO}; do
        if [ -f ${f} ]; then
            ECHO_DEBUG "Set file permission to 0600: ${f}."
            chmod 0600 ${f}
        fi
    done

    echo 'export status_cleanup_set_cron_file_permission="DONE"' >> ${STATUS_FILE}
}


cleanup_remove_mod_python()
{
    # Remove mod_python.
    eval ${LIST_ALL_PKGS} | grep 'mod_python' &>/dev/null

    if [ X"$?" == X"0" ]; then
        ECHO_QUESTION -n "iRedAdmin doesn't work with mod_python, *REMOVE* it now? [Y|n]"
        read_setting ${AUTO_CLEANUP_REMOVE_MOD_PYTHON}
        case ${ANSWER} in
            N|n ) : ;;
            Y|y|* ) eval ${remove_pkg} mod_python ;;
        esac
    else
        :
    fi

    echo 'export status_cleanup_remove_mod_python="DONE"' >> ${STATUS_FILE}
}

cleanup_replace_firewall_rules()
{
    # Replace ssh numbers.
    if [ X"${SSHD_PORT2}" != X'22' ]; then
        # Append second ssh port number.
        perl -pi -e 's#(.*22.*)#${1}\n  <port protocol="tcp" port="$ENV{SSHD_PORT2}"/>#' ${SAMPLE_DIR}/firewalld/services/ssh.xml
        perl -pi -e 's#(.* 22 .*)#${1}\n-A INPUT -p tcp --dport $ENV{SSHD_PORT2} -j ACCEPT#' ${SAMPLE_DIR}/iptables/iptables.rules
        perl -pi -e 's#(.* 22 .*)#${1}\n-A INPUT -p tcp --dport $ENV{SSHD_PORT2} -j ACCEPT#' ${SAMPLE_DIR}/iptables/ip6tables.rules

        # Replace first ssh port number
        perl -pi -e 's#(.*)"22"(.*)#${1}"$ENV{SSHD_PORT}"${2}#' ${SAMPLE_DIR}/firewalld/services/ssh.xml
        perl -pi -e 's#(.*) 22 (.*)#${1} $ENV{SSHD_PORT} -j ACCEPT#' ${SAMPLE_DIR}/iptables/iptables.rules
        perl -pi -e 's#(.*) 22 (.*)#${1} $ENV{SSHD_PORT} -j ACCEPT#' ${SAMPLE_DIR}/iptables/ip6tables.rules
    fi

    perl -pi -e 's#(.*mail_services=.*)ssh(.*)#${1}$ENV{SSHD_PORTS_WITH_COMMA}${2}#' ${SAMPLE_DIR}/openbsd/pf.conf

    ECHO_QUESTION "Would you like to use firewall rules provided by MailBSD?"
    ECHO_QUESTION -n "File: ${FIREWALL_RULE_CONF}, with SSHD ports: ${SSHD_PORTS_WITH_COMMA}. [Y|n]"
    read_setting ${AUTO_CLEANUP_REPLACE_FIREWALL_RULES}
    case ${ANSWER} in
        N|n ) ECHO_INFO "Skip firewall rules." ;;
        Y|y|* )
            backup_file ${FIREWALL_RULE_CONF}
            if [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
                # Enable pf
                service_control enable pf >> ${INSTALL_LOG} 2>&1

                # Whitelist file required by spamd(8)
                touch /etc/mail/nospamd

                ECHO_INFO "Copy firewall sample rules: ${FIREWALL_RULE_CONF}."
                cp -f ${SAMPLE_DIR}/openbsd/pf.conf ${FIREWALL_RULE_CONF}
            fi

            # Prompt to restart iptables.
            ECHO_QUESTION -n "Restart firewall now (with ssh ports: ${SSHD_PORTS_WITH_COMMA})? [y|N]"
            read_setting ${AUTO_CLEANUP_RESTART_IPTABLES}
            case ${ANSWER} in
                Y|y )
                    ECHO_INFO "Restarting firewall ..."

                    if [ X"${DISTRO}" == X'OPENBSD' ]; then
                        /sbin/pfctl -ef ${FIREWALL_RULE_CONF} >> ${INSTALL_LOG} 2>&1
                    fi
                    ;;
                N|n|* )
                    export "RESTART_IPTABLES='NO'"
                    ;;
            esac
            ;;
    esac

    echo 'export status_cleanup_replace_firewall_rules="DONE"' >> ${STATUS_FILE}
}

cleanup_update_compile_spamassassin_rules()
{
    # Required on FreeBSD to start Amavisd-new.
    ECHO_INFO "Updating SpamAssassin rules (sa-update), please wait ..."
    ${BIN_SA_UPDATE} >> ${INSTALL_LOG} 2>&1

    ECHO_INFO "Compiling SpamAssassin rulesets (sa-compile), please wait ..."
    ${BIN_SA_COMPILE} >> ${INSTALL_LOG} 2>&1

    echo 'export status_cleanup_update_compile_spamassassin_rules="DONE"' >> ${STATUS_FILE}
}

cleanup_update_clamav_signatures()
{
    # Update clamav before start clamav-clamd service.
    if [ X"${FRESHCLAM_UPDATE_IMMEDIATELY}" == X'YES' ]; then
        ECHO_INFO "Updating ClamAV database (freshclam), please wait ..."
        freshclam 2>/dev/null
    fi

    echo 'export status_cleanup_update_clamav_signatures="DONE"' >> ${STATUS_FILE}
}

cleanup_feedback()
{
    # Send names of chosen package to MailBSD project to help developers
    # understand which packages are most important to users.
    url="${BACKEND_ORIG}=YES"
    url="${url}&SOGO=${USE_SOGO}"
    url="${url}&FAIL2BAN=${USE_FAIL2BAN}"
    url="${url}&IREDADMIN=${USE_IREDADMIN}"
    [ X"${WEB_SERVER}" == X'NGINX' ] && url="${url}&NGINX=YES"

    ECHO_DEBUG "Send info of chosed packages to MailBSD team to help improve MailBSD:"
    ECHO_DEBUG ""
    ECHO_DEBUG "\t${BACKEND_ORIG}=YES"
    ECHO_DEBUG "\tWEB_SERVER=${WEB_SERVER}"
    ECHO_DEBUG "\tSOGO=${USE_SOGO}"
    ECHO_DEBUG "\tFAIL2BAN=${USE_FAIL2BAN}"
    ECHO_DEBUG "\tIREDADMIN=${USE_IREDADMIN}"
    ECHO_DEBUG ""

    cd /tmp
    ${FETCH_CMD} "https://lic.mailbsd.org/check_version/mailbsd_pkgs?${url}" &>/dev/null
    rm -f /tmp/mailbsd_pkgs* &>/dev/null

    echo 'export status_cleanup_feedback="DONE"' >> ${STATUS_FILE}
}

cleanup()
{
    # Store MailBSD version number in /etc/mailbsd-release
    cat > /etc/${PROG_NAME_LOWERCASE}-release <<EOF
${PROG_VERSION} ${BACKEND_ORIG} edition.
# Get professional support from MailBSD Team: https://mailbsd.org/support.html
EOF

    cat <<EOF

*************************************************************************
* ${PROG_NAME}-${PROG_VERSION} installation and configuration complete.
*************************************************************************

EOF

    # Mail installation related info to postmaster@
    msg_date="$(date "+%a, %d %b %Y %H:%M:%S %z")"

    ECHO_DEBUG "Mail sensitive administration info to ${DOMAIN_ADMIN_EMAIL}."
    FILE_MAILBSD_INSTALLATION_DETAILS="${DOMAIN_ADMIN_MAILDIR_INBOX}/details.eml"
    FILE_MAILBSD_LINKS="${DOMAIN_ADMIN_MAILDIR_INBOX}/links.eml"
    FILE_MAILBSD_MUA_SETTINGS="${DOMAIN_ADMIN_MAILDIR_INBOX}/mua.eml"

    cat > ${FILE_MAILBSD_INSTALLATION_DETAILS} <<EOF
From: root@${HOSTNAME}
To: ${DOMAIN_ADMIN_EMAIL}
Date: ${msg_date}
Subject: Details of this MailBSD installation

$(cat ${TIP_FILE})
EOF

    cat > ${FILE_MAILBSD_LINKS} <<EOF
From: root@${HOSTNAME}
To: ${DOMAIN_ADMIN_EMAIL}
Date: ${msg_date}
Subject: Useful resources for MailBSD administrator

$(cat ${DOC_FILE})
EOF

    cat > ${FILE_MAILBSD_MUA_SETTINGS} <<EOF
From: root@${HOSTNAME}
To: ${DOMAIN_ADMIN_EMAIL}
Date: ${msg_date}
Subject: How to configure your mail client applications (MUA)


* POP3 service: port 110 over TLS (recommended), or port 995 with SSL.
* IMAP service: port 143 over TLS (recommended), or port 993 with SSL.
* SMTP service: port 587 over TLS.
* CalDAV and CardDAV server addresses: https://<server>/SOGo/dav/<full email address>

For more details, please check detailed documentations:
https://docs.mailbsd.org/#mua
EOF

    chown -R ${SYS_USER_VMAIL}:${SYS_GROUP_VMAIL} ${DOMAIN_ADMIN_MAILDIR_INBOX}
    chmod -R 0700 ${DOMAIN_ADMIN_MAILDIR_INBOX}

    check_status_before_run cleanup_set_cron_file_permission
    check_status_before_run cleanup_remove_mod_python

    [ X"${KERNEL_NAME}" == X'OPENBSD' ] && \
        check_status_before_run cleanup_replace_firewall_rules

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        check_status_before_run cleanup_update_compile_spamassassin_rules
    fi

    check_status_before_run cleanup_update_clamav_signatures
    check_status_before_run cleanup_feedback

    cat <<EOF
********************************************************************
* URLs of installed web applications:
*
EOF

    if [ X"${USE_SOGO}" == X'YES' ]; then
        cat <<EOF
* - SOGo groupware: https://${HOSTNAME}/SOGo/
EOF
    fi

    cat <<EOF
*
* - Web admin panel (iRedAdmin): https://${HOSTNAME}/iredadmin/
*
* You can login to above links with below credential:
*
* - Username: ${DOMAIN_ADMIN_EMAIL}
* - Password: ${DOMAIN_ADMIN_PASSWD_PLAIN}
*
*
********************************************************************
* Congratulations, mail server setup completed successfully. Please
* read below file for more information:
*
*   - ${TIP_FILE}
*
* And it's sent to your mail account ${DOMAIN_ADMIN_EMAIL}.
*
********************* WARNING **************************************
*
* Please reboot your system to enable all mail services.
*
********************************************************************
EOF

    echo 'export status_cleanup="DONE"' >> ${STATUS_FILE}
}
