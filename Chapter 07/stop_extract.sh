curl -k -X "POST" "https://5.75.142.233/services/DEPLOYMENT_TESTDB01/v2/commands/execute" \
-u oggadmin:"<PWD>" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-d '{ "name":"stop", "processName":"EXT02"}'