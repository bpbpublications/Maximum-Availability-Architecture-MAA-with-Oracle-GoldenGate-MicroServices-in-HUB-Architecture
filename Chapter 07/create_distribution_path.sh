curl -k -X POST https://5.75.142.233/services/DEPLOYMENT_TESTDB01/v2/sources/PATH_TESTAPI \
-s -u oggadmin:"<PWD>" \
-H "Accept: application/json" \
-d '{
"name":"PATH_TESTAPI",
"status":"running",
"source":{"uri":"trail://5.75.142.233/services/DEPLOYMENT_TESTDB01/distsrvr/v2/sources?trail=a2"},
"target":{"uri":"ogg://localhost:9003/services/v2/targets?trail=b2"}
}'