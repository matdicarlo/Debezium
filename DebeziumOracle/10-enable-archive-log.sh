#!/bin/bash
oc exec -i deployment/oracle-xe -n streams -- sh -c "sqlplus -S / as sysdba <<EOF
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
EOF"
