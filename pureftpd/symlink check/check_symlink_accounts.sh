#! /bin/bash
MYSQL=/usr/bin/mysql
LOGFILE=/var/log/symlink.log
TS=`date '+%Y-%m-%d %H:%M:%S'`
sylinks=0
$MYSQL --defaults-file=/etc/mysql/debian.cnf -N -e "use pureftpd; select Dir from users;" | \
(while read dir; do
        dir1=`echo "$dir" | sed 's/\/$//'`
        if [ -L "${dir1}" ] && [ -e ${dir1} ] ; then
                TS=`date '+%Y-%m-%d %H:%M:%S'`
                echo "$TS $dir1 is symlink" >> $LOGFILE
                ((sylinks++))
        fi
done

if [[ $sylinks -gt 0 ]]
then
        echo "CRITICAL - Number of ftp accounts with symlinks as root is $sylinks" >> $LOGFILE
fi
)