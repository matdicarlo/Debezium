
# Deploy Debezium connector for Oracle on Openshift

# Links
https://debezium.io/documentation/reference/stable/connectors/oracle.html

# Preconfiguration
- Install Streams for Apache Kafka Operator
- Install Debezium Operator

# Installation/Configuration steps

## 1. Install Streams for apache Kafka and create NodePools and Instance
~~~
oc apply -f strimzi.yaml
~~~

## 2. Apply Debezium yaml

~~~
oc apply -f debezium.yaml
~~~


## 3. Apply oracle yaml
~~~
oc apply -f oracle.yaml
~~~


## 4. Grant scc
Grant SCC: Run the oc adm policy command mentioned above.
~~~
oc adm policy add-scc-to-user anyuid -z default -n debezium
~~~
Check Oracle Logs: Ensure the DB starts and the init scripts run (oc logs -f deployment/oracle-xe).
Restart Debezium.

## Issues
The error ORA-01031: insufficient privileges on CREATE TABLE "LOG_MINING_FLUSH" happens because Debezium needs to create a small helper table in the database to manage the "flushing" of redo logs. This table ensures that LogMiner doesn't miss transactions.
~~~
oc exec -it deployment/oracle-xe -n debezium -- /bin/bash

sqlplus / as sysdba

-- Grant create table permission commonly
GRANT CREATE TABLE TO c##dbzuser CONTAINER=ALL;

-- Grant tablespace quota so it can actually store the table
ALTER USER c##dbzuser QUOTA UNLIMITED ON USERS;

-- Just in case, grant it specifically in the PDB as well
ALTER SESSION SET CONTAINER=XEPDB1;
GRANT CREATE TABLE TO c##dbzuser;
ALTER USER c##dbzuser QUOTA UNLIMITED ON USERS;

-- Return to root
ALTER SESSION SET CONTAINER=CDB$ROOT;


oc delete pod -l app=debezium-oracle
~~~

