#!/usr/bin/env bash

# --------------------------------------------------
# --------------------- MySQL ----------------------
# --------------------------------------------------

. ${CONF_DIR}/postgresql

# Root password.
while : ; do
    ${DIALOG} \
    --title "Password for PostgreSQL administrator: ${PGSQL_ROOT_USER}" \
    --passwordbox "\

Please specify password for PostgreSQL administrator: ${PGSQL_ROOT_USER}

WARNING:

* Do *NOT* use special characters in password right now. e.g. $, #, @, space.
* EMPTY password is *NOT* permitted.
* Sample password: $(${RANDOM_STRING})

" 20 76 2>${RUNTIME_DIR}/.pgsql_rootpw

    PGSQL_ROOT_PASSWD="$(cat ${RUNTIME_DIR}/.pgsql_rootpw)"

    # Check $, #, space
    echo ${PGSQL_ROOT_PASSWD} | grep '[\$\#\ ]' &>/dev/null
    [ X"$?" != X'0' -a X"${PGSQL_ROOT_PASSWD}" != X'' ] && break
done

export PGSQL_ROOT_PASSWD="${PGSQL_ROOT_PASSWD}"
echo "export PGSQL_ROOT_PASSWD='${PGSQL_ROOT_PASSWD}'" >>${MAILBSD_CONFIG_FILE}
rm -f ${RUNTIME_DIR}/.pgsql_rootpw
