#!/bin/bash
#script to run the kmeans jobs with weka 
#dependent script wekacsv.sh 
#kmeans_no.jar required in the same directory with this script

RES_DIR="/opt/Weka_jobs/4cores_4GBram/ds6/dim10"
RRDS="/var/lib/ganglia/rrds/thesis-cluster"
RRDS_MASTER="${RRDS}/master"
MASTER_METRICS=(bytes_in.rrd bytes_out.rrd mem_buffers.rrd mem_cached.rrd mem_free.rrd cpu_idle.rrd cpu_system.rrd cpu_steal.rrd cpu_user.rrd cpu_wio.rrd)

function check_args {

    if ! [ $1 -eq 2 ]
    then
        echo -e "[-]Invalid usage\n   USAGE: ./run_weka.sh <csv_data> <heap_size(MB)>"
        exit 1
    fi
    
    if ! [ -e "wekacsv.sh" ]
    then
        echo "wekacsv.sh script must exist in the `pwd` dir "
        exit 1
    fi
       
    if ! [ -e "$2" ]
    then
        echo -e "[-]Invalid file\n   File does not exist in the current directory"
        exit 1
    fi
    return
}

function log {
    echo "[+]$@">>$LOGFILE
    return
}

function report_time {
    STRING_START_TIME="`date -d@$JOB_START_TIME`"  #job start time in human readable format
    STRING_STOP_TIME="`date -d@$JOB_END_TIME`" #job end time in human readable format
    TIME_DIF="$[$JOB_END_TIME-$JOB_START_TIME]"
    echo "$JOB_START_TIME,$STRING_START_TIME" >$JOB_DIR/time
    echo "$JOB_END_TIME,$STRING_STOP_TIME" >>$JOB_DIR/time
    echo "$TIME_DIF" >>$JOB_DIR/time
    return
}

function place_event {
    #use of the ganglia event api 
    res=`curl "http://master/ganglia/api/events.php?action=add&start_time=${GANGLIA_EVENT_START}&summary=${JOB_NAME}&host_regex=*&end_time=${GANGLIA_EVENT_STOP}" 2>/dev/null`
    log "Just placed an event in ganglia for the job"
    return
}

function gather_metrics {
    #fetch the metrics for the master first excluding the disk IOs
    for METRIC in ${MASTER_METRICS[*]}
    do
        rrdtool fetch ${RRDS_MASTER}/${METRIC} AVERAGE --start $GANGLIA_EVENT_START --end $GANGLIA_EVENT_STOP >"${JOB_DIR}/${METRIC%.*}"
    done
    return
}


check_args $# $1
INFILE=$1
JVM_HEAP=$2
#add attribute numbers to be the first line of the csv file
#the name of the file remains unchanged
LOGFILE=script_output
[ -e "$LOGFILE" ] && rm -f $LOGFILE
touch $LOGFILE
log "Creating the correct csv file for weka"
[ -e "${INFILE##*/}" ] || ./wekacsv.sh $INFILE

#number of iterations
for i in 10
do
    #number of clusters
    for c in 100 #100
    do
        JOB_DIR="${RES_DIR}/clus${c}/iter${i}"
        JOB_NAME="Weka_ds6_dim10_clus${c}_iter10"
        log "Flushing caches, we want nothing buffered in memory"
        sync ; echo 3 >/proc/sys/vm/drop_caches
        log "Starting iostat process" 
        iostat -dm 5 > $JOB_DIR/iostat_unformatted &
        IOSTAT_PID=$!
        GANGLIA_EVENT_START=`date +%s`
        log "Sleeping for 30 secs..."
        sleep 30
        log "Starting job $JOB_NAME with $JVM_HEAP heap size and input file ${INFILE}"
        JOB_START_TIME=`date +%s`
        java -Xmx${JVM_HEAP}m -jar kmeans_no.jar $INFILE $c 10 >$JOB_DIR/stdout 2>$JOB_DIR/stderr &
        JOB_PID=$!
        log "Waiting for the job to complete..."
        wait $JOB_PID
        JOB_END_TIME=`date +%s`
        log "Job has just ended, sleeping for 45 secs..."
	sleep 45
        GANGLIA_EVENT_STOP=`date +%s`
        log "Killing iostat process"
        kill -SIGTERM $IOSTAT_PID
        log "Reporting time statistics for the job"
        report_time
        log "Placing event to ganglia for the job"
        place_event
        log "Gathering metrics from rrd database and formatting iostat output"
        gather_metrics
        sed -n '7~3p' $JOB_DIR/iostat_unformatted | tr -s ' ' ',' >$JOB_DIR/iostat_csv
        log "Everything ok"
        log "Sleeping for 30 secs until next job..."
    done
done



