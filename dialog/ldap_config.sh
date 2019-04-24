#!/usr/bin/env bash

# --------------------------------------------------
# --------------------- LDAP -----------------------
# --------------------------------------------------

# LDAP suffix.
while : ; do
    ${DIALOG} \
        --title "LDAP SUFFIX (root dn)" \
        --inputbox "\

Please specify your LDAP suffix (root dn):

EXAMPLE:

* Domain 'example.com': dc=example,dc=com
* Domain 'test.com.de': dc=test,dc=com,dc=de

NOTE:

Password for LDAP rootdn (cn=Manager,dc=xx,dc=xx) 

will be generated randomly.

" 20 76 "dc=example,dc=com" 2>${RUNTIME_DIR}/.ldap_suffix

    LDAP_SUFFIX="$(cat ${RUNTIME_DIR}/.ldap_suffix)"
    [ X"${LDAP_SUFFIX}" != X"" ] && break
done

rm -f ${RUNTIME_DIR}/.ldap_suffix

export LDAP_SUFFIX="${LDAP_SUFFIX}"
echo "export LDAP_SUFFIX='${LDAP_SUFFIX}'" >> ${MAILBSD_CONFIG_FILE}

# LDAP bind dn, passwords.
export LDAP_BINDPW="$(${RANDOM_STRING})"
export LDAP_ADMIN_PW="$(${RANDOM_STRING})"
export LDAP_ROOTPW="$(${RANDOM_STRING})"
echo "export LDAP_BINDPW='${LDAP_BINDPW}'" >> ${MAILBSD_CONFIG_FILE}
echo "export LDAP_ADMIN_PW='${LDAP_ADMIN_PW}'" >> ${MAILBSD_CONFIG_FILE}
echo "export LDAP_ROOTPW='${LDAP_ROOTPW}'" >> ${MAILBSD_CONFIG_FILE}
