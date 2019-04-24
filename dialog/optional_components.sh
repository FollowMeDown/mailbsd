#!/usr/bin/env bash

# ----------------------------------------
# Optional components for special backend.
# ----------------------------------------
# Construct dialog menu list
# Format: item_name item_descrition on/off
# Note: item_descrition must be concatenated by '_'.
export LIST_OF_OPTIONAL_COMPONENTS=''

# Fail2ban
export DIALOG_SELECTABLE_FAIL2BAN='YES'
if [ X"${DISTRO}" == X'OPENBSD' ]; then
    export DIALOG_SELECTABLE_FAIL2BAN='NO'
fi

# Web applications
if [ X"${DISABLE_WEB_SERVER}" != X'YES' ]; then
    . ${DIALOG_DIR}/web_applications.sh
fi

# iRedAdmin. Although it's a web application, but it's also able to run with
# WSGI server instead of web server.
LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} MailBSD-Admin Official_web-based_Admin_Panel on"

# Fail2ban.
if [ X"${DIALOG_SELECTABLE_FAIL2BAN}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} Fail2ban Ban_IP_with_too_many_password_failures on"
fi

export tmp_config_optional_components="${ROOTDIR}/.optional_components"

if echo ${LIST_OF_OPTIONAL_COMPONENTS} | grep 'o' &>/dev/null; then
    ${DIALOG} \
    --title "OPTIONAL COMPONENTS" \
    --checklist "\

* DKIM signing/verification and SPF validation are enabled by default.
* DNS records for SPF and DKIM are required after installation.

Refer to below file for more detail after installation:

* ${TIP_FILE}

" 20 76 6 \
${LIST_OF_OPTIONAL_COMPONENTS} \
2>${tmp_config_optional_components}

    OPTIONAL_COMPONENTS="$(cat ${tmp_config_optional_components})"
    rm -f ${tmp_config_optional_components} &>/dev/null
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'iredadmin' &>/dev/null; then
    export USE_IREDADMIN='YES'
    echo "export USE_IREDADMIN='YES'" >> ${MAILBSD_CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'sogo' &>/dev/null; then
    export USE_SOGO='YES'
    echo "export USE_SOGO='YES'" >> ${MAILBSD_CONFIG_FILE}
fi

if echo ${OPTIONAL_COMPONENTS} | grep -i 'fail2ban' &>/dev/null; then
    export USE_FAIL2BAN='YES'
    echo "export USE_FAIL2BAN='YES'" >>${MAILBSD_CONFIG_FILE}
fi

export random_pw="$(${RANDOM_STRING})"
export AMAVISD_DB_PASSWD="${AMAVISD_DB_PASSWD:=${random_pw}}"
echo "export AMAVISD_DB_PASSWD='${AMAVISD_DB_PASSWD}'" >> ${MAILBSD_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export IREDADMIN_DB_PASSWD="${IREDADMIN_DB_PASSWD:=${random_pw}}"
echo "export IREDADMIN_DB_PASSWD='${IREDADMIN_DB_PASSWD}'" >> ${MAILBSD_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export RCM_DB_PASSWD="${RCM_DB_PASSWD:=${random_pw}}"
echo "export RCM_DB_PASSWD='${RCM_DB_PASSWD}'" >> ${MAILBSD_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export SOGO_DB_PASSWD="${SOGO_DB_PASSWD:=${random_pw}}"
echo "export SOGO_DB_PASSWD='${SOGO_DB_PASSWD}'" >> ${MAILBSD_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export SOGO_SIEVE_MASTER_PASSWD="${SOGO_SIEVE_MASTER_PASSWD:=${random_pw}}"
echo "export SOGO_SIEVE_MASTER_PASSWD='${SOGO_SIEVE_MASTER_PASSWD}'" >> ${MAILBSD_CONFIG_FILE}

export random_pw="$(${RANDOM_STRING})"
export IREDAPD_DB_PASSWD="${IREDAPD_DB_PASSWD:=${random_pw}}"
echo "export IREDAPD_DB_PASSWD='${IREDAPD_DB_PASSWD}'" >> ${MAILBSD_CONFIG_FILE}
