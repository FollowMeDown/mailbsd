#!/usr/bin/env bash


# --------------------------
# Optional web applications.
# --------------------------

if [ X"${DISABLE_WEB_SERVER}" != X'YES' ]; then
    export DIALOG_SELECTABLE_SOGO='NO'

    # SOGo team doesn't offer binary packages for arm platform.
    if [ X"${OS_ARCH}" == X'i386' -o X"${OS_ARCH}" == X'x86_64' ]; then
        export DIALOG_SELECTABLE_SOGO='YES'
    fi

    if [ X"${DISTRO}" == X'OPENBSD' ]; then
        # OpenBSD doesn't have 'libuuid' which required by netdata
        export DIALOG_SELECTABLE_NETDATA='NO'
    fi
fi

# iRedAdmin
if [ X"${DIALOG_SELECTABLE_IREDADMIN}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} MailBSD-Admin Official_web-based_Admin_Panel on"
fi

# SOGo
if [ X"${DIALOG_SELECTABLE_SOGO}" == X'YES' ]; then
    LIST_OF_OPTIONAL_COMPONENTS="${LIST_OF_OPTIONAL_COMPONENTS} SOGo Webmail,_Calendar,_Address_book off"
fi