curl -k -u oggadmin:"<PWD>" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-X "GET" "https://5.75.142.233/services/DEPLOYMENT_TESTDB02/v2/replicats/REP02/info/reports/REP02.rpt" | json_pp