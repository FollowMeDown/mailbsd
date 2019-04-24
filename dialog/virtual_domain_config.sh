#!/usr/bin/env bash

# First domain name.
while : ; do
    ${DIALOG} \
    --title "YOUR FIRST MAIL DOMAIL NAME" \
    --inputbox "\

Please specify your first mail domain name.

EXAMPLE:
* example.com

WARNING:
It can NOT be the same as server hostname: ${HOSTNAME}.

We need Postfix to accept emails sent to system accounts (e.g. root), 
if your mail domain is same as server hostname, 
Postfix won't accept any email sent to this mail domain.

" 20 76 2>${RUNTIME_DIR}/.first_domain

    FIRST_DOMAIN="$(cat ${RUNTIME_DIR}/.first_domain | tr '[A-Z]' '[a-z]')"

    echo "${FIRST_DOMAIN}" | grep '\.' &>/dev/null
    [ X"$?" == X"0" -a X"${FIRST_DOMAIN}" != X"${HOSTNAME}" ] && break
done

export FIRST_DOMAIN="${FIRST_DOMAIN}"
echo "export FIRST_DOMAIN='${FIRST_DOMAIN}'" >> ${MAILBSD_CONFIG_FILE}
rm -f ${RUNTIME_DIR}/.first_domain

# Domain admin password
while : ; do
    ${DIALOG} \
    --title "PASSWORD FOR THE MAIL DOMAIN ADMIN" \
    --passwordbox "\

Please specify password for the mail domain administrator:

* ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}

You can login to webmail and MailBSD-Admin with this account.

WARNING:

* Do *NOT* use special characters (like \$, #, @) in password.
* EMPTY password is *NOT* permitted.
* Sample password: $(${RANDOM_STRING})

" 20 76 2>${RUNTIME_DIR}/.first_domain_admin_passwd

    DOMAIN_ADMIN_PASSWD_PLAIN="$(cat ${RUNTIME_DIR}/.first_domain_admin_passwd)"

    [ X"${DOMAIN_ADMIN_PASSWD_PLAIN}" != X"" ] && break
done

export DOMAIN_ADMIN_PASSWD_PLAIN="${DOMAIN_ADMIN_PASSWD_PLAIN}"
echo "export DOMAIN_ADMIN_PASSWD_PLAIN='${DOMAIN_ADMIN_PASSWD_PLAIN}'" >> ${MAILBSD_CONFIG_FILE}
rm -f ${RUNTIME_DIR}/.first_domain_admin_passwd

cat >> ${TIP_FILE} <<EOF
Admin of domain ${FIRST_DOMAIN}:

    * Account: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}
    * Password: ${DOMAIN_ADMIN_PASSWD_PLAIN}

    You can login to iRedAdmin with this account, login name is full email address.

First mail user:
    * Username: ${DOMAIN_ADMIN_NAME}@${FIRST_DOMAIN}
    * Password: ${DOMAIN_ADMIN_PASSWD_PLAIN}
    * SMTP/IMAP auth type: login
    * Connection security: STARTTLS or SSL/TLS

    You can login to webmail with this account, login name is full email address.

EOF
