#!/bin/bash
MOUNT_POINT=/u01/app/fs
LOGGER="/bin/logger -t ACFSVOL"
PATH_NAME=$MOUNT_POINT/acfs_primary

ATTEMPTS=3
INTERVAL=10

LOGGER_FACILITY=user
PERL_ALARM_TIMEOUT=14
GREP=/bin/grep
ECHO=/bin/echo
SLEEP=/bin/sleep
BASENAME=/bin/basename
STAT=/usr/bin/stat
PERL=/usr/bin/perl
TOUCH=/bin/touch
RM="/bin/rm -rf"

LANG=en_US.UTF-8
NLS_LANG=American_America.AL32UTF8
export STAT MOUNT_POINT PERL_ALARM_TIMEOUT
export STATUS_TIMEOUT
export LANG NLS_LANG

if [ -z "$STATUS_TIMEOUT" ]; then STATUS_TIMEOUT=0; fi
logit () {
  ### type: info, error, debug
  type=$1
  msg=$2
  if [ "$type" = "info" ]; then
        $ECHO $msg
        $LOGGER -p ${LOGGER_FACILITY}.info "$msg"
elif [ "$type" = "error" ]; then
        $ECHO $msg
        $LOGGER -p ${LOGGER_FACILITY}.error "$msg"
elif [ "$type" = "debug" ]; then
        $ECHO $msg
        $LOGGER -p ${LOGGER_FACILITY}.debug "$msg"
  fi
}
SCRIPTPATH=$0
SCRIPTNAME=`$BASENAME $SCRIPTPATH`

$ECHO $SCRIPTPATH | $GREP ^/ > /dev/null 2>&1
if [ $? -ne 0 ]; then
        MYDIR=`pwd`
        SCRIPTPATH=${MYDIR}/${SCRIPTPATH}
fi

function check_for_standby()
{
$PERL <<'TOT'
        eval {
                $STANDBY=`/sbin/acfsutil repl info -c -v /u01/app/fs|grep "Site"|grep Standby|wc -l 2>&1`;
                if ( $STANDBY == 1 ) {
                        exit 1;
                } else {
                        exit 0;
                }
        };
TOT
        RC=$?

        if [ $RC -eq 1 ]; then
                echo 1
        else
                echo 0
        fi
}

function standby_status()
{
        OUTPUT="$(ls -1)"
        s_status="$(/sbin/acfsutil repl util verifystandby ${MOUNT_POINT}|cut -d ' ' -f3 2>&1)"

        if [ $s_status -ne 0 ]; then
        echo $s_status
        else   # FS is OKAY
                echo 0;
        fi
}

function verify_standby()
{
        for ((i=1;i<=$ATTEMPTS;i++)); do
        sresult=$(standby_status)

        if [ $sresult -eq 0 ]; then
                break
        else
                logit debug "WARNING: STANDBY not accessible (attempt $i of $ATTEMPTS))"
                if [ $i -lt $ATTEMPTS ]; then
                        $SLEEP $INTERVAL
                fi
        fi
done

if [ $i -lt $ATTEMPTS ]; then
        logit debug "SUCCESS: Remote STANDBY file system $MOUNT_POINT is ONLINE"
        presult=0
else
        logit debug "WARNING: Problem with STANDBY file system (error: $sresult)"
        presult=0
fi
}
function verify_primary()
{
        $PERL <<'TOT'
                $timeout = $ENV{'PERL_ALARM_TIMEOUT'};
                $SIG{ALRM} = sub {
                        ### we have a problem and need to cleanup
                        exit 3;
                        die "timeout" ;
                };
                alarm $timeout;
                eval {
                        $STATUSOUT=`$ENV{'STAT'} -f -c "%T" $ENV{'MOUNT_POINT'} 2>&1 `;

                        chomp($STATUSOUT);
                        if ( ( $STATUSOUT eq 'acfs' ) ) {
                                ### FS is mounted
                                exit 0       }
                        else {
                                ### filesystem is offline
                                exit 1;
                        }
                };
TOT
RC=$?
presult=0

if [ $RC -eq 3 ]; then
        STATUS_TIMEOUT=$(( $STATUS_TIMEOUT + 1 ))
        logit error "Found timeout while checking status, cleaning mount automatically"
        $SCRIPTPATH clean
        logit debug "Filesystem is OFFLINE"
        presult=1
elif [ $RC -eq 2 ]; then
        STATUS_TIMEOUT=$(( $STATUS_TIMEOUT + 1 ))
        logit error "Found error while checking status, cleaning mount automatically"
        $SCRIPTPATH clean
        logit debug "WARNING: PRIMARY file system $MOUNT_POINT OFFLINE"
        presult=1
elif [ $RC -eq 1 ]; then
        logit debug "WARNING: PRIMARY file System is not mounted"
        presult=2
elif [ $RC -eq 0 ]; then
        result=$(check_for_standby)
        if [ $result -eq 1 ]; then
                presult=1
        fi
fi
}

case "$1" in
'start')
        logit info "$SCRIPTNAME starting at $MOUNT_POINT"

        result=$(check_for_standby) # Return 0  if NOT standby file system

        if [ $result -eq 0 ]; then
                verify_primary
        else
                logit info "Detected local standby file system"
                exit 1
        fi

        if [[ $presult == 0 ]]; then

                STARTED="$(${GREP} STARTED ${PATH_NAME}|wc -l 2>&1)";

                if [ $STARTED -eq 1 ]; then # File system was previously crashed
                        logit info "WARNING: PRIMARY file system $MOUNT_POINT previously crashed"

                        sresult=$(standby_status)

                        if [ $sresult -ne 0 ]; then
                                logit debug "WARNING: STANDBY not accessible - disabling acfs_primary"
                                $ECHO "DISABLED" > $PATH_NAME
                                exit 0
                        fi
                fi

                DISABLED="$(${GREP} DISABLED ${PATH_NAME}|wc -l 2>&1)";
                if [ $DISABLED -eq 1 ]; then
                        sresult=$(standby_status)

                        if [ $sresult -ne 0 ]; then
                                logit info "WARNING: PRIMARY $MOUNT_POINT disabled to prevent split brain"
                                exit 0
                        fi
                fi

                $RM $PATH_NAME
                $ECHO "STARTED" > $PATH_NAME

                if [ -f "$PATH_NAME" ]
                then
                        logit info "acfs_primary started"

                        exit 0
                else
                        logit info "WARNING: Unable to create $PATH_NAME"
                        exit 1
                fi
                else
                        logit info "WARNING: Verify of PRIMARY failed"
                        exit 1
                fi
;;

'check'|'status')
        result=$(check_for_standby)

        if [ $result -ne 0 ]; then
                logit info "Detected local standby file system"
                exit 1
        fi

        verify_primary # Check status of primary FS
        logit info "DEBUG: presult $presult"

        if [[ $presult == 0 ]]; then
                STOPPED="$(${GREP} STOPPED ${PATH_NAME}|wc -l 2>&1)";

                if [ $STOPPED -eq 1 ]; then
                        logit info "SUCCESS: PRIMARY file system $MOUNT_POINT is STOPPED"
                        exit 1
                fi

                DISABLED="$(${GREP} DISABLED ${PATH_NAME}|wc -l 2>&1)";
                if [ $DISABLED -eq 1 ]; then
                        logit info "WARNING: Primary file system $MOUNT_POINT DISABLED"
                        exit 1
                fi

                RESTART="$(${GREP} RESTART ${PATH_NAME}|wc -l 2>&1)";
                if [ $RESTART -eq 1 ]; then
                        logit info "Restarting PRIMARY file system $MOUNT_POINT"
                        $SCRIPTPATH start
                fi

                sresult=$(standby_status)

                if [ $sresult -eq 0 ]; then  # Standby all good
                        if [ -f "$PATH_NAME" ]
                        then
                                STARTED="$(${GREP} STARTED ${PATH_NAME}|wc -l 2>&1)";
                                if [ $STARTED -eq 1 ]; then
                                        logit info "SUCCESS: STANDBY file system $MOUNT_POINT is ONLINE"
                                        exit 0
                                fi
                        else
                                logit info "WARNING: PRIMARY file $PATH_NAME does NOT exist"
                                exit 1
                        fi
                else
                        verify_standby
                fi
                elif [ $presult -eq 2 ]; then
                        exit 1
                else
                        logit info "WARNING: Problem with local PRIMARY file system."
                        exit 1
                fi
;;

'restart')
        logit info "Restart -- ACFS file system type checking..."
        $SCRIPTPATH start
;;

'stop')
        logit info "Stop -Stopping ACFS file system type checking..."
        $ECHO "STOPPED" > $PATH_NAME
        exit 0
;;

'clean'|'abort')
        logit info "Clean/Abort -Stopping ACFS file system type checking..."
        $ECHO "STOPPED" > $PATH_NAME exit 0
;;

*)
        $ECHO "Usage: $SCRIPTNAME { start | stop | check | status | restart | clean | abort }"
;;

Esac