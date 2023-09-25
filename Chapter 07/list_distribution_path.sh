curl -k -X GET https://5.75.142.233/services/DEPLOYMENT_TESTDB01/v2/sources \
-s -u oggadmin:"<PWD>" \
-H "Accept: application/json" | json_pp