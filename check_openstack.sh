#!/bin/sh
#set -x # enable debug
set -e # quit on first error

ec2_secret_key='9ca604d8-599c-4f48-b7b8-41232b4396f6'
ec2_access_key='0a316d06-5204-4a7c-baff-008e9d819fce:atomiaopenstack'
ec2_url='http://212.247.189.132:8773/services/Cloud'

# first add one machine
new_macine_id=`euca-run-instances ami-00000002 -t m1.tiny -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $2 }'`

if [ -z "$new_macine_id" ]
then
	echo "CRITICAL: Unable to add linux instance"
	exit 2
fi

start_time=$(date +%s)

# now we check status of machine
machine_status=`euca-describe-instances "$new_macine_id" -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $5 }'`
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
		
		machine_status=`euca-describe-instances "$new_macine_id" -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $5 }'`
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
`euca-terminate-instances "$new_macine_id" -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $5 }'`

# sleep while machine is being terminated
sleep 3

# make sure that machine is deleted
machine_status=`euca-describe-instances "$new_macine_id" -a "$ec2_access_key" -s "$ec2_secret_key" -U "$ec2_url" | grep INSTANCE | awk -F ' ' '{ print $5 }'`
if [ -z "$machine_status" ]
then
	# machine deleted
	if [ "$machine_was_running" = "true"]
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