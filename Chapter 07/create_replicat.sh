curl -k -X POST https://5.75.142.233/services/DEPLOYMENT_TESTDB02/v2/replicats/REP02 \
-s -u oggadmin:"<PWD>" \
-H "Accept: application/json" \
-d '{
"config":["REPLICAT REP02","USERIDALIAS C##GGADMIN_TESTDB02_PDB01 DOMAIN OracleGoldenGate","MAP OT.LOCATIONS, TARGET OT.LOCATIONS;"],
"source": {"name": "b1"},"credentials":{"domain": "OracleGoldenGate","alias":"C##GGADMIN_TESTDB02_PDB01"}, "checkpoint":{"table":"PDB01.C##GGADMIN.CKPT_TBL"},"begin":"now","status": "running"
}'