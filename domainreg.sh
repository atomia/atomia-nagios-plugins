#!/bin/sh

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
	echo "usage: $0 url user pass domain [domain ...]"
	exit 1
fi

url="$1"
user="$2"
pass="$3"

shift 3

success=0
fail=0
for domain in $*; do 
	echo domainreg_client --uri "$url" --username "$user" --password "$pass" --method DomainCheck --arg "$domain"
	exit
	output=`domainreg_client --method DomainCheck --arg "$domain" | grep "'success' => '1'"`
	if [ -n "$output" ]; then
		success=$(($success + 1))
	else
		fail=$((fail + 1))
	fi
done

if [ "$fail" = 0 ] && [ "$success" != 0 ]; then
	echo "OK: Got $success successfull responses for DomainCheck($1)."
	exit 0
elif [ "$success" = 0 ]; then
	echo "CRITICAL: Got error in all responses for DomainCheck of $*."
	exit 2
else
	echo "WARNING: Got error in $fail responses and success in $success for DomainCheck of $*."
	exit 1
fi
