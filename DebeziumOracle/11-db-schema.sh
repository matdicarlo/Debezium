#!/bin/bash
cat 11-db-schema.sh 
 oc exec -i deployment/oracle-xe -n streams -- sh -c "sqlplus -S / as sysdba <<EOF
   -- Ensure Table exists
   CREATE USER APP_USER IDENTIFIED BY password;
   GRANT CONNECT, RESOURCE, DBA TO APP_USER;
   ALTER USER APP_USER QUOTA UNLIMITED ON USERS;
   CREATE TABLE APP_USER.CUSTOMERS (id NUMBER PRIMARY KEY, name VARCHAR2(100));

   -- Grant Debezium specific privileges
   GRANT CREATE SESSION TO c##dbzuser;
   GRANT SELECT ANY TRANSACTION TO c##dbzuser;
   GRANT SELECT ANY TABLE TO c##dbzuser;
   GRANT SELECT ANY DICTIONARY TO c##dbzuser
   GRANT SELECT ON V_\$LOGMNR_CONTENTS TO c##dbzuser;
   GRANT SELECT ON V_\$LOGMNR_LOGS TO c##dbzuser;
   GRANT EXECUTE ON DBMS_LOGMNR TO c##dbzuser;
   GRANT SELECT ON V_\$DATABASE TO c##dbzuser;
   GRANT SELECT ON V_\$INSTANCE TO c##dbzuser;
   GRANT SELECT ON V_\$PARAMETER TO c##dbzuser;
   GRANT SELECT ON V_\$LOGMNR_CONTENTS TO c##dbzuser;
   GRANT SELECT ON V_\$LOGMNR_LOGS TO c##dbzuser;
   GRANT SELECT ON V_\$LOGMNR_LOGS TO c##dbzuser;
   GRANT SELECT ON V_\$LOGMNR_CONTENTS TO c##dbzuser;
   -- Crucial for PDB access
   GRANT SET CONTAINER TO c##dbzuser;
   EXIT;
   EOF"

