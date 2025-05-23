
#!/bin/bash
POSTGRES_URI=$1
PORT=$2

export PGRST_DB_URI=$POSTGRES_URI
export PGRST_DB_SCHEMA=witstats_api
export PGRST_DB_ANON_ROLE=witstats_user
export PGRST_DB_ROOT_SPEC=home
export PGRST_SERVER_PORT=$PORT
postgrest