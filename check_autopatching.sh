#!/bin/bash
##########################################################################################
#
# Name:        check_autpatching.sh
# Date:        2020-07-22
# Author:      nikola.vitanovic@atomia.com
# Version:     20.7.0
# Parameters:
#
# Returns:
#              0 - OK
#              1 - WARNING
#              2 - CRITICAL
#              3 - UNKNOWN
#
# Description:  In case there are issues with Autopatching process a apropriate severity
#               will be returned.
#
#               The script relies on the fact that it check for a file that has a Sunday
#               timestamp in it that points to last Sunday, so previous autopatch run.
#
#               Severities:
#                OK       - No issues.
#                WARNING  - There were fatal errors in the file.
#                CRITICAL - No log file is available to be read from.
#                UNKNOWN  - Other issue with the Nagios check has occured.
##########################################################################################

# Get the current week
current_date=`date +"%Y-%m-%d"`
sunday_date=$(date -d "$current_date -$(date -d $current_date +%u) days" +"%Y-%m-%d")

# Try to find the last log file
log_path=`find /var/log/atomia-security-autopatching/ -name "*$sunday_date*"`
if [ $? -ne 0 ]; then
    echo "UNKNOWN: Could not find /var/log/atomia-security-autopatching/ directory, check if autopatching is installed!"
    exit 3
fi

if [ -z $log_path ] || [ ! -f $log_path ]; then
    echo "CRITICAL: Autopatching run from $sunday_date is missing or not yet complete!"
    exit 2
fi

# Try to find out if everything is OK no failiures
failiures=`grep "Total failed:       0" $log_path`
if [ $? -ne 0 ]; then
    num_fails=`grep "Total failed:" $log_path | awk '{ print $4 }'`
    echo -e "WARNING: Upgrade of packages on $sunday_date failed for $num_fails servers!\nLog available at: $log_path"
    exit 1
fi

# Print out OK message
echo "OK: Autopatching has completed without issues on $sunday_date!"
exit 0