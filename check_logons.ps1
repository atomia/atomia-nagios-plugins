##########################################################################################
#
# Name:        check_logons.ps1
# Date:        2020-02-11
# Author:      nikola.vitanovic@atomia.com
# Version:     1.0.0
# Parameters:
#              -logonTypes '10','3'
#              -ignoreUsers 'VAGRANT\WINMASTER$','VAGRANT\Administrator'
#              -ignoreIPs '127.0.0.1','192.168.33.10','192.168.33.22'
#              -debug
#              -id some_id_if_multiple_checks
#              -testOnly
#              -logLocation "C:\logs\"
#
# Returns:
#              0 - OK
#              2 - CRITICAL
#              3 - UNKNOWN
#
# Description: Nagios plugin that alerts if there are 4624 EventIDs aka logins in the
#              Security event log of the system.
#
#              In case there are unknown users CRITICAL message will be shown and exit
#              code will be 2. Additional users with computer name or NetBIOS domain will
#              be shown in the new lines after the CRITICAL message.
#              In case there are unknown source IPs they will also be logged as CRITICAL.
#
#              The plugin logs a timestamp of last processed log in the TEMP folder. This
#              timestamp is used to process only logs after the timestamp. Last processed
#              log timestamp will be stored and all logs from that time forward will be
#              processed.
#
#              ATTENTION: You will get CRITICAL every next time the check occurs, after
#              the first CRITICAL was encountered. Path to the file that should be deleted
#              is shown in the CRITICAL Nagios message.
#
#              All parameters are optional. Ignore parameters are essentially whitelist.
#
#              If you don't specify -logonTypes parameter only RDP logins will be checked.
#              You can specify any LogonType. Valid types: https://bit.ly/2ULjexx
#
#              If you don't specify -ignoreUsers any username will be treated as unknown.
#              Usernames need to be specified in format "DOMAIN\Username" or
#              "COMPUTER\Username". NetBIOS short name should be used.
#
#              If you don't specify -ignoreIPs any IP will be treated as suspcious.
#              You can specify multiple IPs or only one. Any event that has different IP
#              than the one available in the list will be reported as suspicious.
#              Make sure that all IPs are specified.
#
#              If you specify -disableIPCheck IPs from the login events won't be checked,
#              the parameter -ignoreIPs won't have any effect.
#
#              There is a -debug parameter that can be used to show more info about what
#              events the script is currently processing and other details of the run.
#
#              If you specify -id a folder will be created in the temp directory where the
#              log and lock files will be created.
#
#              If you specify -testOnly it will just check if there is last lock file that
#              is not removed. If it exists message from that log will be written else the
#              OK message will be written to the user.
#
#              If you specify -logLocation script will create and check the lock files
#              in that location. You should specify absolute path.
#
##########################################################################################

param (
    [string]$logonTypes = '10',
    [string]$ignoreUsers,
    [string]$ignoreIPs,
    [switch]$disableIPCheck,
    [switch]$debug,
    [string]$id,
    [switch]$testOnly,
    [string]$logLocation
)

# Initialize basic variables and paths
$log = @()
$tempLocation = "$env:TEMP\$id"

# If there is an override for the tempLocation
# set it via parameter
if($logLocation)
{
    $tempLocation = "$logLocation\$id"
}

$lastLogLocation = "$tempLocation\check_logons.LOG-REMOVE.lock"
$lastCheckLocation = "$tempLocation\check_logons.DONT-REMOVE.last"

# Split the data if needed
$ignoreIPsList = $ignoreIPs.Split(',').Trim()
$logonTypesList = $logonTypes.Split(',').Trim()
$ignoreUsersList = $ignoreUsers.Split(',').Trim()

# Show temp location in case DEBUG mode is on
if($debug)
{
    Write-Host "DEBUG: Temp location $tempLocation"
}

# Force creation of the directory if it does not exist
New-Item -ItemType Directory -Force -Path $tempLocation > $null

# Check if the lock file exists with the log.
# Show that log and exit as CRITICAL.
if(Test-Path $lastLogLocation)
{
    $output = Get-Content -Path $lastLogLocation -Encoding UTF8 -Raw
    Write-Host $output
    Write-Host "Check out the activity and remove $lastLogLocation to recover"
    exit 2
}
if($testOnly)
{
    # Display OK if no suspicious activity was detected.
    Write-Host "OK - No suspicious activity in  the last scan"
    exit 0
}

# Load the file that contains the last timestamp.
# If there is an issue assume that current time
# is the last time checked.
$lastCheck = Get-Date -Format "yyyy-MM-dd HH:mmm:ssK"
try
{
    if(!(Test-Path $lastCheckLocation))
    {
        throw "Does not exist"
    }

    $lastCheck = Get-Content -Path $lastCheckLocation
    if([string]::IsNullOrEmpty($lastCheck))
    {
        throw "Empty lastlog"
    }
}
catch
{
    # Write current time as last event time, new events will be
    # parsed from this current time. This happens because the
    # needed file does not exist or is empty and needs to be
    # initialized in order for the app to work.
    $lastCheck = Get-Date -Format "yyyy-MM-dd HH:mmm:ssK"
    Out-File -FilePath $lastCheckLocation -InputObject $lastCheck
}

# Gather the Security event logs from the DB and process them.
$eventLogs = Get-EventLog -LogName Security -InstanceId 4624 -After $lastCheck | Select Message,ReplacementStrings,TimeGenerated,Index
$numberOfProcessedLogs = 0

foreach($item in $eventLogs)
{
    # Gather the data from the log entry that is needed.
    $currentTime = $item.TimeGenerated.ToString("yyyy-MM-dd HH:mmm:ssK")
    $currentIp = $item.ReplacementStrings[18]
    $currentUser = $item.ReplacementStrings[5]
    $currentLogonType = $item.ReplacementStrings[8]
    $currentComputerNameDomain = $item.ReplacementStrings[6]
    $currentIndex = $item.Index

    if($debug)
    {
        Write-Host "DEBUG: EventIndex: $currentIndex Time: $currentTime IP: $currentIp User: $currentUser LogonType: $currentLogonType"
    }

    # Check if the logged in account is specific type.
    if($logonTypesList -contains $currentLogonType)
    {
        # Logic to check if the users is whitelisted or not.
        if($ignoreUsersList -contains "$currentComputerNameDomain\$currentUser")
        {
            if($debug)
            {
                Write-Host "DEBUG: User $currentComputerNameDomain\$currentUser is in the list"
            }
        }
        else
        {
            $log += "Suspicious user - User: $currentComputerNameDomain\$currentUser IP: $currentIp EventIndex: $currentIndex LogonType: $currentLogonType"
        }

        # Logic to check if the IP is whitelisted or not.
        if( -not $disableIPCheck)
        {
            if($ignoreIPsList -contains $currentIp)
            {
                if($debug)
                {
                    Write-Host "DEBUG: IP $currentIp is in the list"
                }
            }
            else
            {
                $log += "Suspicious IP - User: $currentComputerNameDomain\$currentUser IP: $currentIp EventIndex: $currentIndex LogonType: $currentLogonType"
            }
        }
    }

    # Since the logs are sorted from newest to the oldest we need to
    # capture the first timestamp and store it in the file.
    # This helps us to parse only unparsed logs.
    if($numberOfProcessedLogs -eq 0)
    {
        Out-File -FilePath $lastCheckLocation -InputObject $currentTime
    }
    $numberOfProcessedLogs++
}

# Display CRITICAL if there are unauthorised events and log it into a file.
if($log.Count -gt 0)
{
    $unauthorisedLogs = $log.Count
    $criticalMessage = "CRITICAL - There are $unauthorisedLogs unauthorised logins"
    foreach($item in $log)
    {
        $criticalMessage += "`r`n$item"
    }
    Write-Host $criticalMessage
    Out-File -FilePath $lastLogLocation -InputObject $criticalMessage
    exit 2
}

# Display OK if no suspicious activity was detected.
Write-Host "OK - Processed $numberOfProcessedLogs logs"
exit 0