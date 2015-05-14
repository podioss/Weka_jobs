#This script is made to sum up a report for a kmeans job submitted to Weka
#It depends on metricsparser.py and memparser.py scripts 

METRICSPARSER="./metricsparser.py"
MEMPARSER="./memparser.py"
for ds in 6 #dataset sizes
do
    for d in 10 100 50 #dimensions
    do
        for c in 10 100 200 #clusters
        do
            for i in 10 #iterations
            do
                BASE_DIR="/opt/Weka_jobs/4cores_4GBram/ds${ds}/dim${d}/clus${c}/iter${i}"
                PARSED="$BASE_DIR/parsed"
                MODEL_DATA="$BASE_DIR/model_data"
                
                mkdir -p $PARSED #folder to store the parsed metrics
                #parse all the memory metrics at first
                $METRICSPARSER $BASE_DIR/mem_cached $PARSED/mem_cached
                $METRICSPARSER $BASE_DIR/mem_free $PARSED/mem_free
                $METRICSPARSER $BASE_DIR/mem_buffers $PARSED/mem_buffers
                #copy the iostat and time metric to the parsed folder
                cp $BASE_DIR/iostat_csv $PARSED/iostat_csv
                tail -1 $BASE_DIR/time > $PARSED/time
                
                #cut to take only the mem fields
                cut -d',' -f2 $PARSED/mem_free > $PARSED/mem_free_tmp
                cut -d',' -f2 $PARSED/mem_cached > $PARSED/mem_cached_tmp
                cut -d',' -f2 $PARSED/mem_buffers > $PARSED/mem_buffers_tmp
                
                #chop the first 3 lines and the last two from the file
                head -n -2 $PARSED/mem_free_tmp | tail -n +3 > $PARSED/mem_free_tmp1
                head -n -2 $PARSED/mem_cached_tmp | tail -n +3 > $PARSED/mem_cached_tmp1
                head -n -2 $PARSED/mem_buffers_tmp | tail -n +3 > $PARSED/mem_buffers_tmp1
                paste -d"," $PARSED/mem_free_tmp1 $PARSED/mem_cached_tmp1 $PARSED/mem_buffers_tmp1 > $PARSED/mem_all
                rm -f $PARSED/{mem_buffers_tmp,mem_cached_tmp,mem_free_tmp}
                rm -f $PARSED/{mem_buffers_tmp1,mem_cached_tmp1,mem_free_tmp1}
                $MEMPARSER $PARSED/mem_all $PARSED/average_mem_used
                
                #create the 4 final data point for the job
                mkdir -p $MODEL_DATA
                POINTS=$(echo "10^$ds" | bc)
                DISK_IO_IN=`cut -d',' -f5 $PARSED/iostat_csv | paste -sd+ | bc`
                DISK_IO_OUT=`cut -d',' -f6 $PARSED/iostat_csv | paste -sd+ | bc`
                
                echo "data_points,dimensions,k,time"> $MODEL_DATA/time_data
                echo "data_points,dimensions,k,mem_used_kb"> $MODEL_DATA/average_mem_data
                echo "data_points,dimensions,k,diskio_in"> $MODEL_DATA/diskio_in_data
                echo "data_points,dimensions,k,diskio_out"> $MODEL_DATA/diskio_out_data
                
                #echo $DISK_IO_IN
                #echo $DISK_IO_OUT
                echo "$POINTS,$d,$c,`cat $PARSED/time`" >> $MODEL_DATA/time_data
                echo "$POINTS,$d,$c,`cat $PARSED/average_mem_used`" >> $MODEL_DATA/average_mem_data
                echo "$POINTS,$d,$c,$DISK_IO_IN" >> $MODEL_DATA/diskio_in_data
                echo "$POINTS,$d,$c,$DISK_IO_OUT" >> $MODEL_DATA/diskio_out_data
            done
        done
    done 
done
