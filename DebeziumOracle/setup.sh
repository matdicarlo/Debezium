#!/bin/bash

# --- Configuration ---
NAMESPACE="streams"
ORACLE_USER="c##dbzuser"
ORACLE_PASS="dbz"
ORACLE_SYSTEM_PASS="oracle"

echo "Starting Debezium Oracle CDC Setup..."

# 1. Create Namespace
echo "Creating namespace $NAMESPACE..."
oc create namespace $NAMESPACE || true

# 2. Deploy Kafka Cluster
echo "Deploying Kafka Cluster..."
oc apply -f 01-streams_namespace_cluster.yaml

# 3. Deploy Oracle Database
echo "Deploying Oracle XE..."
oc apply -f 02-oracle-setup.yaml

echo "Waiting for Oracle to be ready..."
until oc get pods -n $NAMESPACE -l app=oracle-xe | grep -q "Running"; do
  echo -n "."
  sleep 10
done
echo -e "\nOracle Pod is Running."

# 4. Fix Oracle Security Context
echo "Granting anyuid SCC to the default service account..."
oc adm policy add-scc-to-user anyuid -z default -n $NAMESPACE

# 5. Configure Oracle for CDC
echo "Configuring Oracle for CDC (Archivelog and Permissions)..."
ORACLE_POD=$(oc get pods -l app=oracle-xe -n $NAMESPACE -o jsonpath='{.items[0].metadata.name}')

# A. CDB CONFIGURATION (LogMiner and System privileges)
echo "Applying CDB-level grants..."
SQL_CDB="
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

GRANT CREATE SESSION TO $ORACLE_USER;
GRANT SELECT ANY TRANSACTION TO $ORACLE_USER;
GRANT SELECT ANY TABLE TO $ORACLE_USER;
GRANT SELECT ANY DICTIONARY TO $ORACLE_USER;
GRANT LOGMINING TO $ORACLE_USER;
GRANT EXECUTE ON DBMS_LOGMNR TO $ORACLE_USER;
GRANT EXECUTE ON DBMS_LOGMNR_D TO $ORACLE_USER;

COMMIT;
EXIT;
"
echo "$SQL_CDB" | oc exec -i $ORACLE_POD -n $NAMESPACE -- sqlplus sys/$ORACLE_SYSTEM_PASS as sysdba

# B. PDB CONFIGURATION (Session and Table privileges inside XEPDB1)
echo "Applying PDB-level grants..."
SQL_PDB="
GRANT CREATE SESSION TO $ORACLE_USER;
GRANT SELECT ANY TABLE TO $ORACLE_USER;
GRANT SELECT ANY DICTIONARY TO $ORACLE_USER;
COMMIT;
EXIT;
"
echo "$SQL_PDB" | oc exec -i $ORACLE_POD -n $NAMESPACE -- sqlplus system/$ORACLE_SYSTEM_PASS@//localhost:1521/XEPDB1

# 6. Deploy Kafka Connect Infrastructure
echo "Deploying Kafka Connect ImageStream..."
oc apply -f 03-connect-is.yaml

echo "Deploying Kafka Connect Cluster..."
oc apply -f 04-kafka-connect.yaml

echo "Waiting for Kafka Connect to be ready..."
until oc get pods -n $NAMESPACE | grep -q "my-connect-cluster-connect" && oc get pods -n $NAMESPACE | grep -q "1/1"; do
  echo -n "."
  sleep 10
done
echo -e "\nKafka Connect is Ready."

# 7. Deploy the Oracle Connector
echo "Deploying Oracle Source Connector..."
oc apply -f 05-oracle-connector.yaml

echo "Setup Complete."
