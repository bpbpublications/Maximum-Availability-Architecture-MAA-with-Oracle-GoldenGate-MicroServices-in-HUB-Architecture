#/bin/bash
  # export OGG-related environment variables
export OGG_HOME=/u01/app/oracle/ogg/ogg21c_ma
export OGG_ETC_HOME=/u01/app/fs/ogg21c_sm/etc
export OGG_VAR_HOME=/u01/app/fs/ogg21c_sm/var
typeset line=
typeset iobuf=
 db_list=/tmp/list_schemas.list
db_schema_object_list=/tmp/schema_object_list.list
 logfile=/tmp/log_enable_schematrandata.log
  # go through the list line by line and check each schema, in case that schema doesn’t have enabled TRANDATA, enable it 
while read -r line
do
        echo ""|tee -a ${logfile}
        iobuf=`$OGG_HOME/bin/adminclient <<EOF
connect https://apphost1:7820 as oggadmin password <pwd> deployment DEPLOYMENT_<SID>
DBLOGIN USERIDALIAS GGADMIN_<SID>
INFO SCHEMATRANDATA $line
EOF
`
#echo $iobuf
trandata_enabled=`echo $iobuf|grep disabled|wc -l`
trandata_check=`echo $iobuf|grep "prepared tables for instantiation" |sed -e 's/.*has\(.*\)prepared.*/\1/'|sed -e 's/^[[:space:]]*//'`
#echo $trandata_check
         compare_schema=`cat $db_schema_object_list|grep $line`
        compare_schema_objects=`echo $compare_schema |awk -F" " '{print $2}'`
         if [[ $trandata_check -eq $compare_schema_objects && $trandata_enabled -eq 0 ]]
        then
                echo "Success> Schema $line [tradata set: $trandata_check ---- count of objects: $compare_schema_objects] ====> OK" |tee -a ${logfile}
        else
                echo "Error> Schema $line [tradata set: $trandata_check ---- count of objects: $compare_schema_objects], but it's disabled ====> NOT OK" |tee -a ${logfile}
        fi
         iobuf2=`$OGG_HOME/bin/adminclient <<EOF
connect https://apphost1:7820 as oggadmin password <pwd> deployment DEPLOYMENT_<SID>
DBLOGIN USERIDALIAS GGADMIN_<SID>
ADD SCHEMATRANDATA $line ALLCOLS
EOF
`       echo $iobuf2 >> ${logfile}
         iobuf=`$OGG_HOME/bin/adminclient <<EOF
connect https://apphost1:7820 as oggadmin password <pwd> deployment DEPLOYMENT_<SID>
DBLOGIN USERIDALIAS GGADMIN_<SID>
INFO SCHEMATRANDATA $line
EOF
`       #echo $iobuf
        trandata_enabled=`echo $iobuf|grep disabled|wc -l`
        trandata_check=`echo $iobuf|grep "prepared tables for instantiation" |sed -e 's/.*has\(.*\)prepared.*/\1/'|sed -e 's/^[[:space:]]*//'`
         #echo $trandata_check
         compare_schema=`cat $db_schema_object_list|grep $line`
        compare_schema_objects=`echo $compare_schema |awk -F" " '{print $2}'`
         if [[ $trandata_check -eq $compare_schema_objects && $trandata_enabled -eq 0 ]]
        then
                echo "Success> Schema $line [tradata set: $trandata_check ---- count of objects: $compare_schema_objects] ====> OK"|tee -a ${logfile}
        else
                echo "Error> Schema $line [tradata set: $trandata_check ---- count of objects: $compare_schema_objects], but it's disabled ====> NOT OK"|tee -a ${logfile}
        fi
         echo ""|tee -a ${logfile}
 done < $db_list