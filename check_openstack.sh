#!/bin/sh
#set -x # enable debug
set -e # quit on first error

# validate parameters
if [ $# -lt 3 ]
then
    echo
    echo "Checks if openstack environment is up and running."
    echo
    echo "Usage: check_openstack.sh <ec2_secret_key> <ec2_access_key> <ec2_url>"
    echo
    echo "<ec2_secret_key> - EC2 secret key"
    echo "<ec2_access_key> - EC2 access key"
    echo "<ec2_url> - EC2 service URL"
	echo
    exit 2
fi

ec2_secret_key=$1
ec2_access_key=$2
ec2_url=$3

# first add one machine
new_machine_id=`euca-run-instances ami-00000002 -t m1.tiny -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $2 }'`

if [ -z "$new_machine_id" ]
then
	echo "CRITICAL: Unable to add linux instance"
	exit 2
fi

start_time=$(date +%s)

# now we check status of machine
machine_status=`euca-describe-instances "$new_machine_id" -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $6 }'`
machine_was_running="false"

if [ -z "$machine_status" -o "$machine_status" != "running" ]
then
	start_time=$(date +%s)
	time_diff=$(($(date +%s)-$start_time))
	while [ $time_diff -lt 300 ]
	do
		time_diff=$(($(date +%s)-$start_time))
		
		# give openstack some time to create machine
		sleep 5
		
		machine_status=`euca-describe-instances "$new_machine_id" -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $6 }'`
		if [ "$machine_status" = "running" ]
		then
			machine_was_running="true"
			break
		fi
	done
else
	machine_was_running="true"
fi

# delete machine, no metter what is the status
`euca-terminate-instances "$new_machine_id" -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $6 }'`

# sleep while machine is being terminated
sleep 20

# make sure that machine is deleted
machine_status=`euca-describe-instances "$new_machine_id" -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $6 }'`
if [ -z "$machine_status" ]
then
	# machine deleted
	if [ "$machine_was_running" = "true" ]
	then
		echo "OK: Openstack working."
		exit 0
	else
		echo "CRITICAL: Unable to start linux instance"
		exit 2
	fi
else
	# machine not deleted
	echo "CRITICAL: Unable to delete linux instance"
	exit 2
fi