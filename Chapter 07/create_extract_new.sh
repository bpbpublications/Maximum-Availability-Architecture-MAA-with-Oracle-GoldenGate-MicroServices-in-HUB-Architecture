curl -k -X POST https://5.75.142.233/services/DEPLOYMENT_TESTDB01/v2/extracts/EXT02 \
-s -u oggadmin:"<PWD>" \
-H "Accept: application/json" \
-d '{
"config":["EXTRACT EXT02","USERIDALIAS GGADMIN_TESTDB01 DOMAIN OracleGoldenGate","EXTTRAIL a2","TABLE OT.LOCATIONS;"],
"source": "tranlogs","credentials":{"domain": "OracleGoldenGate","alias":"GGADMIN_TESTDB01"},"intent": "Unidirectional","registration": {"share": true},"targets": [{"name": "a2","remote": false,"sequence": 0,"sizeMB": 500,"offset": 0}],"begin":"now","status": "running"
}'