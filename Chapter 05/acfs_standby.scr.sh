#!/bin/bash


MOUNT_POINT=/u01/app/fs
LOGGER="/bin/logger -t ACFSVOL"
PATH_NAME=$MOUNT_POINT/acfs_standby

ATTEMPTS=3
INTERVAL=10

LOGGER_FACILITY=user
PERL_ALARM_TIMEOUT=14
ECHO=/bin/echo
GREP=/bin/grep
SLEEP=/bin/sleep
BASENAME=/bin/basename
STAT=/usr/bin/stat
PERL=/usr/bin/perl
TOUCH=/bin/touch
RM="/bin/rm -rf"


LANG=en_US.UTF-8
NLS_LANG=American_America.AL32UTF8

export STAT MOUNT_POINT PERL_ALARM_TIMEOUT
export STATUS_TIMEOUT ATTEMPTS INTERVAL
export LANG NLS_LANG

if [ -z "$STATUS_TIMEOUT" ]; then STATUS_TIMEOUT=0; fi

logit () {

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
                $STANDBY=`/sbin/acfsutil repl info -c -v $ENV{'MOUNT_POINT'}|grep "Site"|grep Standby|wc -l 2>&1`;

                if ( $STANDBY == 1 ) {
                        exit 1;
                }
                else {
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

function verify_primary()
{
        $PERL <<'TOT'
        eval {
                $p_status=`/sbin/acfsutil repl util verifyprimary $ENV{'MOUNT_POINT'}|cut -d ' ' -f4 2>&1`;

                if ( $p_status > 0 ) {
                        exit $p_status;
                }
                else {
                        exit 0;
                }
        };

TOT
RC=$?
        if [ $RC -ne 1 ]; then
                echo $RC
        else
                echo 0
        fi
}

case "$1" in
'start')
        logit info "$SCRIPTNAME starting to check ACFS remote primary at $MOUNT_POINT"

        result=$(check_for_standby)

        if [ $result -ne 1 ]; then
                logit info "local file system ($MOUNT_POINT) is a PRIMARY"
        fi

        $RM $PATH_NAME
        $ECHO "STARTED" > $PATH_NAME
        if [ -f "$PATH_NAME" ]
        then
                exit 0
        else
                logit info "ERROR: Unable to create standby file system status file ($PATH_NAME)"
                exit 1
        fi
;;
'check'|'status')
        $PERL <<'TOT'
        $timeout = $ENV{'PERL_ALARM_TIMEOUT'};
        $SIG{ALRM} = sub {
                exit 3;
                die "timeout" ;
        };
        alarm $timeout;
        eval {
                $STATUSOUT=`$ENV{'STAT'} -f -c "%T" $ENV{'MOUNT_POINT'} 2>&1`;
                chomp($STATUSOUT);

                if ( ( $STATUSOUT eq 'acfs' ) ) {
                        exit 0
                }
                else {
                        exit 1;
                }
        };

TOT
        RC=$?

        if [ $RC -eq 3 ]; then
                STATUS_TIMEOUT=$(( $STATUS_TIMEOUT + 1 ))
                logit error "Found timeout while checking status, cleaning mount automatically"
                $SCRIPTPATH clean
                logit debug "File system check encountered a problem"
                exit 1
        elif [ $RC -eq 1 ]; then
                logit debug "File system is OFFLINE"
                exit 1
        elif [ $RC -eq 0 ]; then
                result=$(check_for_standby)
                if [ $result -eq 1 ]; then


                        for ((i=1;i<=$ATTEMPTS;i++)); do
                                presult=$(verify_primary)

                                if [ $presult == 0 ]; then
                                        logit debug "SUCCESS: PRIMARY file system $MOUNT_POINT is ONLINE"
                                        exit 0
                                elif [ $presult -eq 222 ] || [ $presult -eq 255 ] || [ $presult -eq 237 ]; then
                                        logit debug "WARNING: PRIMARY not accessible (attempt $i of $ATTEMPTS)"
                                        if [ $i -lt $ATTEMPTS ]; then
                                                $SLEEP $INTERVAL
                                        fi
                                fi
                        done
                        logit debug "WARNING: Problem with PRIMARY file system (error: $presult)"
                        exit 0
                else
                        logit debug "Local PRIMARY file system $MOUNT_POINT"
                        exit 1
                fi
        fi
;;
'restart')
        logit info "Restarting ACFS remote primary checking..."
        $SCRIPTPATH start
;;

'stop')
        logit info "Stop ping ACFS remote primary checking..."
        $ECHO "STOPPED" > $PATH_NAME
        exit 0
;;

'clean'|'abort')
        logit info "Stopping ACFS file system type checking..."
        $ECHO "STOPPED" > $PATH_NAME
        exit 0
;;

*)
        $ECHO "Usage: $SCRIPTNAME { start | stop | check | status | restart | clean | abort }"
;;
esac
