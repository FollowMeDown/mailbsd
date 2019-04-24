#!/usr/bin/env bash

# --------------------------------
# Install all optional components.
# --------------------------------
optional_components()
{
    # iRedAPD.
    check_status_before_run iredapd_setup

    # iRedAdmin.
    [ X"${USE_IREDADMIN}" == X'YES' ] && check_status_before_run iredadmin_setup

    # Fail2ban.
    [ X"${USE_FAIL2BAN}" == X'YES' ] && check_status_before_run fail2ban_config

    # SOGo
    [ X"${USE_SOGO}" == X'YES' ] && check_status_before_run sogo_setup

}
