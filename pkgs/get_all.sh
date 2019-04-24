#!/usr/bin/env bash

# Purpose:  Fetch all extra packages we need to build mail server.

_ROOTDIR="$(pwd)"
CONF_DIR="${_ROOTDIR}/../conf"

. ${CONF_DIR}/global
. ${CONF_DIR}/core
. ${CONF_DIR}/iredadmin

# Re-define @STATUS_FILE, so that MailBSD.sh can read it.
#export STATUS_FILE="${_ROOTDIR}/../.status"

check_user root
check_hostname
check_runtime_dir

export PKG_DIR="${_ROOTDIR}/pkgs"
export PKG_MISC_DIR="${_ROOTDIR}/misc"

# Verify downloaded source tarballs
export SHASUM_CHECK_FILE='pkgs.sha256'
# Linux/FreeBSD use 'shasum -c'
export CMD_SHASUM_CHECK='sha256sum -c'

if [ X"${DISTRO}" == X'OPENBSD' ]; then
    export SHASUM_CHECK_FILE='pkgs.openbsd.sha256'
    export CMD_SHASUM_CHECK='cksum -c'
fi

if [ X"${DISTRO}" == X'OPENBSD' ]; then
    MISCLIST="$(cat ${_ROOTDIR}/${SHASUM_CHECK_FILE} | awk -F'[(/)]' '{print $3}')"
fi

prepare_dirs()
{
    ECHO_DEBUG "Creating necessary directories ..."
    for i in ${PKG_DIR} ${PKG_MISC_DIR}; do
        [ -d "${i}" ] || mkdir -p "${i}"
    done
}

fetch_misc()
{
    # Fetch all misc packages.
    cd ${PKG_MISC_DIR}

    misc_total=$(( $(echo ${MISCLIST} | wc -w | awk '{print $1}') ))
    misc_count=1

    ECHO_INFO "Fetching source tarballs ..."

    for i in ${MISCLIST}; do
        url="${MAILBSD_MIRROR}/pub/MailBSD/6.4/amd64/packages/${i}"
        ECHO_INFO "+ ${misc_count} of ${misc_total}: ${url}"

        ${FETCH_CMD} "${url}"

        misc_count=$((misc_count + 1))
    done
}

verify_downloaded_packages()
{
    ECHO_INFO "Validate downloaded source tarballs ..."

    cd ${_ROOTDIR}
    if [ X"${DISTRO}" == X"OPENBSD" ]; then
        ${CMD_SHASUM_CHECK} ${SHASUM_CHECK_FILE}
        RETVAL="$?"
    fi

    if [ X"${RETVAL}" == X"0" ]; then
        echo -e "[ DONE ]"
        echo 'export status_fetch_misc="DONE"' >> ${STATUS_FILE}
        echo 'export status_verify_downloaded_packages="DONE"' >> ${STATUS_FILE}
    else
        echo -e "[ FAILED ]"
        ECHO_ERROR "Package verification failed. Script exit ...\n"
        exit 255
    fi
}

check_new_mailbsd()
{
    # Check new version and track basic information,
    # Used to help MailBSD team understand which Linux/BSD distribution
    # we should take more care of.
    #
    #   - PROG_VERSION: MailBSD version number
    #   - OS_ARCH: arch (i386, x86_64)
    #   - DISTRO: OS distribution
    #   - DISTRO_VERSION: distribution release number
    #   - DISTRO_CODENAME: code name
    ECHO_INFO "Checking new version of MailBSD ..."
    ${FETCH_CMD} "https://lic.mailbsd.org/check_version/mailbsd_os?mailbsd_version=${PROG_VERSION}&arch=${OS_ARCH}&distro=${DISTRO}&distro_version=${DISTRO_VERSION}&distro_code_name=${DISTRO_CODENAME}" &>/dev/null

    UPDATE_AVAILABLE='NO'
    if ls iredmail_os* &>/dev/null; then
        info="$(cat mailbsd_os*)"
        if [ X"${info}" == X'UPDATE_AVAILABLE' ]; then
            UPDATE_AVAILABLE='YES'
        fi
    fi

    rm -f iredmail_os* &>/dev/null

    if [ X"${UPDATE_AVAILABLE}" == X'YES' ]; then
        echo ''
        ECHO_ERROR "Your MailBSD version (${PROG_VERSION}) is out of date, please"
        ECHO_ERROR "download the latest version and try again:"
        ECHO_ERROR "https://mailbsd.org/download.html"
        echo ''
        exit 255
    fi

    echo 'export status_check_new_mailbsd="DONE"' >> ${STATUS_FILE}
}

echo_end_msg()
{
    if [ X"$(basename $0)" != X'get_all.sh' ]; then
        cat <<EOF
********************************************************
* All tasks had been finished successfully. Next step:
*
*   # cd ..
*   # bash ${PROG_NAME}.sh
*
********************************************************

EOF
    fi
}

if [ -e ${STATUS_FILE} ]; then
    . ${STATUS_FILE}
else
    echo '' > ${STATUS_FILE}
fi

# Check latest version
[ X"${CHECK_NEW_MAILBSD}" != X'NO' ] && \
    check_status_before_run check_new_mailbsd

prepare_dirs

check_status_before_run fetch_misc && \
check_status_before_run verify_downloaded_packages && \
check_pkg ${BIN_DIALOG} ${PKG_DIALOG} && \
echo_end_msg && \
echo 'export status_get_all="DONE"' >> ${STATUS_FILE}
