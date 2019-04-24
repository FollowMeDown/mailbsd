#!/usr/bin/env bash

# -------
# ClamAV.
# -------

clamav_config()
{
    ECHO_INFO "Configure ClamAV (anti-virus toolkit)."
    backup_file ${CLAMD_CONF} ${FRESHCLAM_CONF}

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        perl -pi -e 's/^(Example)/#${1}/' ${CLAMD_CONF} ${FRESHCLAM_CONF}
        mkdir /var/log/clamav
        chown ${SYS_USER_CLAMAV}:${SYS_GROUP_CLAMAV} /var/log/clamav
    fi

    [ -f ${FRESHCLAM_CONF} ] && perl -pi -e 's#^Example##' ${FRESHCLAM_CONF}

    export CLAMD_LOCAL_SOCKET CLAMD_BIND_HOST
    ECHO_DEBUG "Configure ClamAV: ${CLAMD_CONF}."
    perl -pi -e 's/^(TCPSocket .*)/#${1}/' ${CLAMD_CONF}
    perl -pi -e 's#^(TCPAddr ).*#${1} $ENV{CLAMD_BIND_HOST}#' ${CLAMD_CONF}

    # Disable log file
    perl -pi -e 's/^(LogFile .*)/#${1}/' ${CLAMD_CONF}

    # Set CLAMD_LOCAL_SOCKET
    perl -pi -e 's/^(LocalSocket ).*/${1}$ENV{CLAMD_LOCAL_SOCKET}/' ${CLAMD_CONF}
    perl -pi -e 's/^#(LocalSocket ).*/${1}$ENV{CLAMD_LOCAL_SOCKET}/' ${CLAMD_CONF}

    ECHO_DEBUG "Configure freshclam: ${FRESHCLAM_CONF}."
    perl -pi -e 's#^(UpdateLogFile ).*#${1}$ENV{FRESHCLAM_LOGFILE}#' ${FRESHCLAM_CONF}

    # Official database only
    perl -pi -e 's/^#(OfficialDatabaseOnly ).*/${1} yes/' ${CLAMD_CONF}

    # Enable AllowSupplementaryGroups
    perl -pi -e 's/^(AllowSupplementaryGroups.*)/#${1}/' ${CLAMD_CONF}
    if [ X"${DISTRO_CODENAME}" != X'stretch' \
        -a X"${DISTRO_CODENAME}" != X'bionic' \
        -a X"${DISTRO_CODENAME}" != X'cosmic' \
        -a X"${DISTRO}" != X'FREEBSD' ]; then
        echo 'AllowSupplementaryGroups true' >> ${CLAMD_CONF}
    fi

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        usermod -G ${SYS_GROUP_AMAVISD} ${SYS_USER_CLAMAV}

        perl -pi -e 's#^(AllowSupplementaryGroups.*)##g' ${CLAMD_CONF}
        # Remove all `StatsXXX` parameters
        perl -pi -e 's#^(Stats.*)##g' ${CLAMD_CONF}
    fi

    # Add user alias in Postfix
    add_postfix_alias ${SYS_USER_CLAMAV} ${SYS_ROOT_USER}

    cat >> ${TIP_FILE} <<EOF
ClamAV:
    * Configuration files:
        - ${CLAMD_CONF}
        - ${FRESHCLAM_CONF}
        - /etc/logrotate.d/clamav
    * RC scripts:
            + ${DIR_RC_SCRIPTS}/${CLAMAV_CLAMD_SERVICE_NAME}
            + ${DIR_RC_SCRIPTS}/${CLAMAV_FRESHCLAMD_RC_SCRIPT_NAME}

EOF

    echo 'export status_clamav_config="DONE"' >> ${STATUS_FILE}
}
