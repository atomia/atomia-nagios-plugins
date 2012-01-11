#!/bin/sh

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
	echo "UNKNOWN: usage: $0 domain min_hourly_visits hours_process_delay"
	exit 3
fi

domain="$1"
min_hourly_visits="$2"
hours_process_delay="$3"

current_hour=`date +%H | sed 's/^0*//'`
if [ -z "$current_hour" ]; then
	echo "UNKNOWN: Error fetching current hour"
	exit 3
fi

if [ "$current_hour" -lt "$hours_process_delay" ]; then
	echo "OK: Ignoring since we are not $hours_process_delay hours into the day yet"
	exit 0
else
	curdate=`date +"%d %b %Y"`
	if [ -z "$curdate" ]; then
		echo "UNKNOWN: Error fetching current date"
		exit 3
	fi

	hits=`grep "<tr[^>]*><td>$curdate" /storage/content/statistics/awstats_reports/"$domain"/awstats."$domain".html | sed 's/^.*\(<tr[^>]*><td>.*\)$/\1/' | awk -F "<.?td>" '{ print $8 }'`
	if [ -z "$hits" ]; then
		echo "CRITICAL: Error finding row for $curdate in report-file for $domain"
		exit 2
	elif [ -z "$(echo "$hits" | grep -E '^[0-9]+$')" ]; then
		echo "CRITICAL: Unknown format of hits for $curdate: $hits"
		exit 2
	else
		let limit="($current_hour-$hours_process_delay)*$min_hourly_visits"
		if [ "$hits" -lt "$limit" ]; then
			echo "CRITICAL: Hit count $hits for $domain is below limit $limit for hour $current_hour"
			exit 2
		else
			echo "OK: Hit count $hits for $domain is within limit $limit for hour $current_hour"
			exit 0
		fi
	fi
fi

echo "CRITICAL: Unreachable code reached"
exit 2
