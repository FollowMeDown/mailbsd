#!/usr/bin/env bash

ldapd_config()
{
    ECHO_INFO "Configure LDAP server: ldapd(8)."

    ECHO_DEBUG "Copy schema files"
    cp -f ${LDAP_MAILBSD_SCHEMA} ${LDAPD_SCHEMA_DIR}
    cp -f /usr/local/share/doc/amavisd-new/LDAP.schema ${LDAPD_SCHEMA_DIR}/${AMAVISD_LDAP_SCHEMA_NAME}

    ECHO_DEBUG "Copy sample config file: ${SAMPLE_DIR}/openbsd/ldapd.conf -> ${LDAPD_CONF}"
    backup_file ${LDAPD_CONF}
    cp -f ${SAMPLE_DIR}/openbsd/ldapd.conf ${LDAPD_CONF}
    chmod 0600 ${LDAPD_CONF}

    ECHO_DEBUG "Update config file: ${LDAPD_CONF}"
    export LDAP_SUFFIX LDAP_BASEDN LDAP_ADMIN_BASEDN
    export LDAP_ROOTDN LDAP_ROOTPW
    export LDAP_BINDDN LDAP_ADMIN_DN
    perl -pi -e 's#PH_LDAP_SUFFIX#$ENV{LDAP_SUFFIX}#g' ${LDAPD_CONF}
    perl -pi -e 's#PH_LDAP_BASEDN#$ENV{LDAP_BASEDN}#g' ${LDAPD_CONF}
    perl -pi -e 's#PH_LDAP_ADMIN_BASEDN#$ENV{LDAP_ADMIN_BASEDN}#g' ${LDAPD_CONF}

    perl -pi -e 's#PH_LDAP_ROOTDN#$ENV{LDAP_ROOTDN}#g' ${LDAPD_CONF}
    perl -pi -e 's#PH_LDAP_ROOTPW#$ENV{LDAP_ROOTPW_SSHA}#g' ${LDAPD_CONF}

    perl -pi -e 's#PH_LDAP_BINDDN#$ENV{LDAP_BINDDN}#g' ${LDAPD_CONF}
    perl -pi -e 's#PH_LDAP_ADMIN_DN#$ENV{LDAP_ADMIN_DN}#g' ${LDAPD_CONF}

    ECHO_DEBUG "Start ldapd"
    rcctl restart ${LDAPD_RC_SCRIPT_NAME} >> ${INSTALL_LOG} 2>&1

    ECHO_DEBUG "Sleep 5 seconds for LDAP daemon initialize ..."
    sleep 5

    ECHO_DEBUG "Populate LDAP tree"
    ldapadd -x \
        -h ${LDAP_SERVER_HOST} -p ${LDAP_SERVER_PORT} \
        -D "${LDAP_ROOTDN}" -w "${LDAP_ROOTPW}" \
        -f ${LDAP_INIT_LDIF} >> ${INSTALL_LOG} 2>&1

    cat >> ${TIP_FILE} <<EOF
ldapd:
    * LDAP suffix: ${LDAP_SUFFIX}
    * LDAP root dn: ${LDAP_ROOTDN}, password: ${LDAP_ROOTPW}
    * LDAP bind dn (read-only): ${LDAP_BINDDN}, password: ${LDAP_BINDPW}
    * LDAP admin dn (read-write): ${LDAP_ADMIN_DN}, password: ${LDAP_ADMIN_PW}
    * LDAP base dn: ${LDAP_BASEDN}
    * LDAP admin base dn: ${LDAP_ADMIN_BASEDN}
    * Configuration files:
        - ${LDAPD_CONF}
        - ${LDAPD_SCHEMA_DIR}/${PROG_NAME_LOWERCASE}.schema
        - ${LDAPD_SCHEMA_DIR}/${AMAVISD_LDAP_SCHEMA_NAME}
    * Log file related:
        - ${SYSLOG_CONF}
    * Data dir and files:
        - ${LDAPD_DATA_DIR}
    * RC script name:
        - ${LDAPD_RC_SCRIPT_NAME}
    * See also:
        - ${LDAP_INIT_LDIF}

EOF

    echo 'export status_ldapd_config="DONE"' >> ${STATUS_FILE}
}
