#!/bin/bash
oc exec -i deployment/oracle-xe -n streams -- sh -c "sqlplus -S / as sysdba <<EOF
-- Switch to Root
ALTER SESSION SET CONTAINER = CDB\$ROOT;
-- Grant the crucial permission to switch containers
GRANT SET CONTAINER TO c##dbzuser;
-- Grant general Debezium permissions again just to be 100% sure
GRANT CREATE SESSION TO c##dbzuser;
GRANT SELECT ANY TRANSACTION TO c##dbzuser;
GRANT SELECT ANY TABLE TO c##dbzuser;
GRANT SELECT ANY DICTIONARY TO c##dbzuser;
GRANT EXECUTE ON DBMS_LOGMNR TO c##dbzuser;
EXIT;
EOF"
