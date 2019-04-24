#!/usr/bin/env bash

# -------------
# SpamAssassin.
# -------------

sa_config()
{
    ECHO_INFO "Configure SpamAssassin (content-based spam filter)."

    backup_file ${SA_LOCAL_CF}

    ECHO_DEBUG "Copy sample SpamAssassin config file: ${SAMPLE_DIR}/spamassassin/local.cf -> ${SA_LOCAL_CF}."
    cp -f ${SAMPLE_DIR}/spamassassin/local.cf ${SA_LOCAL_CF}
    cp -f ${SAMPLE_DIR}/spamassassin/razor.conf ${SA_PLUGIN_RAZOR_CONF}

    perl -pi -e 's#PH_SA_PLUGIN_RAZOR_CONF#$ENV{SA_PLUGIN_RAZOR_CONF}#g' ${SA_LOCAL_CF}

    ECHO_DEBUG "Enable crontabs for SpamAssassin update."

    cat >> ${TIP_FILE} <<EOF
SpamAssassin:
    * Configuration files and rules:
        - ${SA_CONF_DIR}
        - ${SA_CONF_DIR}/local.cf

EOF

    echo 'export status_sa_config="DONE"' >> ${STATUS_FILE}
}