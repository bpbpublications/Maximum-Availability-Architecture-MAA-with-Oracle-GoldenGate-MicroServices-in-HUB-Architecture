curl -k -u oggadmin:"<PWD>" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-X "POST" "https://5.75.142.233/services/DEPLOYMENT_TESTDB01/v2/commands/execute" \
-d '{
"name": "report",
"thresholds": [
{
"type": "info",
"units": "seconds",
"value": 0
},
{
"type": "critical",
"units": "seconds",
"value": 5
}
],
"reportType": "lag"
}' | json_pp