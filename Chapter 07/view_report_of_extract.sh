curl -k -u oggadmin:"<PWD>" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-X "GET" "https://5.75.142.233/services/DEPLOYMENT_TESTDB01/v2/extracts/EXT02/info/reports/EXT02.rpt" | json_pp