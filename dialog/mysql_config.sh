#!/usr/bin/env bash

# --------------------------------------------------
# --------------------- MySQL ----------------------
# --------------------------------------------------

. ${CONF_DIR}/mysql

if [ -z "${MYSQL_ROOT_PASSWD}" ]; then
    # set a new MySQL root password.
    while : ; do
        ${DIALOG} \
        --title "PASSWORD FOR MYSQL ADMIN: ${MYSQL_ROOT_USER}" \
        --passwordbox "\

Please specify password for MySQL Admin :
${MYSQL_ROOT_USER} on server : ${MYSQL_SERVER_ADDRESS}.

WARNING:

* Do *NOT* use double quote (\") in password.
* EMPTY password is NOT permitted.
* Sample password: $(${RANDOM_STRING})

" 20 76 2>${RUNTIME_DIR}/.mysql_rootpw

        MYSQL_ROOT_PASSWD="$(cat ${RUNTIME_DIR}/.mysql_rootpw)"

        [ X"${MYSQL_ROOT_PASSWD}" != X'' ] && break
    done

    export MYSQL_ROOT_PASSWD="${MYSQL_ROOT_PASSWD}"
fi

echo "export MYSQL_ROOT_PASSWD='${MYSQL_ROOT_PASSWD}'" >>${MAILBSD_CONFIG_FILE}
rm -f ${RUNTIME_DIR}/.mysql_rootpw &>/dev/null
