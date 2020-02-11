param (
    [string[]]$logonTypes = @('10','11'),
    [string[]]$ignore
)

#Get-EventLog -LogName Security -InstanceId 4624 -Newest 10 | Select-Object -Property *
#exit 0

$listOfAdditionalIPs = @()
$listOfAdditionalIndexes = @()
$listOfAdditionalUsernames = @()
$logLocation = "$env:TEMP\check_logons.last"

# Load the file that contains the last timestamp.
# If there is an issue assume that current time
# is the last time checked.
$lastCheck = Get-Date -Format "yyyy-MM-dd HH:mmm:ssK"
echo $lastCheck
try
{
    $lastCheck = Get-Content -Path $logLocation
    if([string]::IsNullOrEmpty($lastCheck))
    {
        throw
    }
}
catch
{
    $lastCheck = Get-Date -Format "yyyy-MM-dd HH:mmm:ssK"
    Out-File -FilePath $logLocation -InputObject $lastCheck
}

Write-Host $logLocation
$var = Get-EventLog -LogName Security -InstanceId 4624 -After $lastCheck | Select Message,ReplacementStrings,TimeGenerated,Index
$numberOfProcessedLogs = 0

foreach($item in $var)
{
    # Gather the data from the log entry that is needed
    $currentTime = $item.TimeGenerated.ToString("yyyy-MM-dd HH:mmm:ssK")
    $currentIp = $item.ReplacementStrings[18]
    $currentUser = $item.ReplacementStrings[5]
    $currentLogonType = $item.ReplacementStrings[8]
    $currentComputerNameDomain = $item.ReplacementStrings[6]
    $currentIndex = $item.Index

    Write-Host $currentIndex $currentTime $currentIp $currentUser $currentLogonType

    if($logonTypes -contains $currentLogonType)
    {
        Write-Host "Login detected - User: $currentComputerNameDomain\$currentUser IP: $currentIp Index: $currentIndex"
    }

    # Since the logs are sorted from newest to the oldest we need to
    # capture the first timestamp and store it in the file.
    # This helps us to parse only unparsed logs.
    if($numberOfProcessedLogs -eq 0)
    {
        Out-File -FilePath $logLocation -InputObject $currentTime
    }
    $numberOfProcessedLogs++
}

Write-Host "OK - Processed $numberOfProcessedLogs logs"