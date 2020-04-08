#! /bin/bash
LOGFILE=/var/log/symlink.log
TS=`date '+%Y-%m-%d %H:%M:%S'`

OUTPUT=`grep CRITICAL $LOGFILE | tail -1`

if [[ -n $OUTPUT ]]
then
        echo "$OUTPUT. The full list can be seen in the $LOGFILE "
        exit 2
else
        echo "OK - Number of ftp accounts with symlinks as root is 0"
        exit 0
fi