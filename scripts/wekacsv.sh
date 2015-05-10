#!/bin/bash

if ! [ $# -eq 1 ]
then
	echo "[-]Usage: ./wekacsv <raw-csv>"
	exit 1
fi

CSV=$1
TEMP_CSV="temp_csv"

ARGS=`head -1 $1 | awk -F, '{print NF}'`

echo "`seq -s ','  1 $ARGS`">$TEMP_CSV
cat $CSV >>$TEMP_CSV
#rm -f $CSV
#mv $TEMP_CSV $CSV
