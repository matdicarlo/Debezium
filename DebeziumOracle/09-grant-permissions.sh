#!/bin/bash
oc exec -i deployment/oracle-xe -n streams -- sh -c "sqlplus -S / as sysdba" <<EOF
GRANT CREATE SESSION TO c##dbzuser;
GRANT CONNECT, RESOURCE, DBA TO c##dbzuser;
EXIT;
EOF
