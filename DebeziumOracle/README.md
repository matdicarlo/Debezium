


# Test oracle
oc exec -it $(oc get pods -l app=oracle-xe -n streams -o name) -n streams -- sqlplus system/oracle@//localhost:1521/XE

