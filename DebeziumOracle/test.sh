#!/bin/bash

# --- Configuration ---
NAMESPACE="streams"
ORACLE_USER="c##dbzuser"
ORACLE_PASS="dbz"
# We define the topic name explicitly here
TOPIC_NAME="oracle_cdc.APP_USER.CUSTOMERS"

echo "Starting Debezium Oracle CDC End-to-End Test..."

# 1. Verify Infrastructure is Ready
echo "Checking infrastructure status..."
ORACLE_POD=$(oc get pods -n $NAMESPACE -l app=oracle-xe -o jsonpath='{.items[0].metadata.name}')
CONNECT_POD=$(oc get pods -n $NAMESPACE -l strimzi.io/cluster=my-connect-cluster -o jsonpath='{.items[0].metadata.name}')

if [ -z "$ORACLE_POD" ] || [ -z "$CONNECT_POD" ]; then
    echo "Error: Oracle or Kafka Connect pods are not running."
    exit 1
fi

CONNECTOR_STATUS=$(oc get kafkaconnector oracle-source-connector -n $NAMESPACE -o jsonpath='{.status.conditions[0].status}')
if [ "$CONNECTOR_STATUS" != "True" ]; then
    echo "Error: Oracle Source Connector is not in READY state."
    exit 1
fi
echo "Infrastructure is healthy."

# 2. Insert Test Data into Oracle
echo "Inserting test record into Oracle..."
TIMESTAMP=$(date +%s)
TEST_NAME="Test_User_$TIMESTAMP"

oc exec -i $ORACLE_POD -n $NAMESPACE -- sqlplus -S /nolog <<EOF
connect $ORACLE_USER/$ORACLE_PASS@//localhost:1521/XEPDB1
INSERT INTO APP_USER.CUSTOMERS (id, name) VALUES ($TIMESTAMP, '$TEST_NAME');
COMMIT;
EXIT;
EOF

if [ $? -eq 0 ]; then
    echo "Successfully inserted: $TEST_NAME"
else
    echo "Error: Failed to insert record into Oracle."
    exit 1
fi

# 3. Consume and Verify Data from Kafka
echo "Listening for change event in Kafka topic: $TOPIC_NAME..."
TIMEOUT_SECONDS=60
START_TIME=$(date +%s)

# Find a broker pod once
KAFKA_POD=$(oc get pods -n $NAMESPACE --no-headers | grep broker | awk '{print $1}' | head -n 1)

if [ -z "$KAFKA_POD" ]; then
    echo "Error: Could not find a Kafka broker pod."
    exit 1
fi

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [ $ELAPSED -gt $TIMEOUT_SECONDS ]; then
        echo "Error: Timed out waiting for event in Kafka."
        exit 1
    fi

    # We use a double-quoted string and call the shell explicitly to avoid variable stripping
    CMD="bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic $TOPIC_NAME --from-beginning --max-messages 1"
    EVENT=$(oc exec -i $KAFKA_POD -n $NAMESPACE -- sh -c "$CMD" | grep "$TEST_NAME")

    if [ ! -z "$EVENT" ]; then
        echo -e "\n✅ SUCCESS: Event found in Kafka!"
        echo "Event Data: $EVENT"
        break
    fi

    echo -n "."
    sleep 2
done

echo "------------------------------------------------------------------"
echo "End-to-End Test Passed Successfully."
echo "------------------------------------------------------------------"
