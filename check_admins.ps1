##########################################################################################
#
# Name:        check_admins.ps1
# Date:        2020-02-07
# Author:      nikola.vitanovic@atomia.com
# Version:     1.1.0
# Parameters:
#              -domain 'Domain Admins'
#              -local 'Administrators'
#              -usernames "SOMECOMPUTER\User","SOMEDOMAIN\User2"
#
# Returns:
#              0 - OK
#              2 - CRITICAL
#              3 - UNKNOWN
#
# Description: Nagios plugin that alerts in case there are additional users on the server
#              that belong to a certain group Enterprise, Domain or Local admins.
#              In case there are additonal users CRITICAL message will be shown and exit
#              code will be 2. Additional users with computer name or NetBIOS domain will
#              be shown in the new lines after the CRITICAL message.
#
##########################################################################################

param (
    [string]$domain = $null,
    [string]$local = $null,
    [string[]]$usernames
)

# Get Local admins from the computer
function get-localadmin {
    param (
        [string]$strcomputer = $env:computername,
        [string]$groupname = "Administrators"
    )
    $admins = Gwmi win32_groupuser –computer $strcomputer
    $groupname = '*"{0}"' -f $groupname
    $admins = $admins |? {$_.groupcomponent –like $groupname}  
    $admins |% {  
    $_.partcomponent –match “.+Domain\=(.+)\,Name\=(.+)$” > $nul  
    $matches[1].trim('"') + “\” + $matches[2].trim('"')  
    }  
}

# Perpare basic variables needed for the task
$currentDomain = ""
$admins = ""
$listOfUsernames = @()
$listOfAdditionalUsernames = @()
# Get list of admins based on the type
if($domain)
{
    try
    {
        $currentDomain = Get-ADDomain -Current LocalComputer
        $admins = Get-ADGroupMember -Identity $domain -Recursive | %{Get-ADUser -Identity $_.distinguishedName} | Select SamAccountName
    }
    catch
    {
        Write-Host "UNKNOWN - domain AD commands not successful or invalid group"
        exit 3
    }
}
elseif($local)
{
    try
    {
        $admins = get-localadmin -strcomputer $env:computername -groupname $local
    }
    catch
    {
        Write-Host "UNKNOWN - local WMI commands not successful or invalid group"
        exit 3
    }
}
else
{
    Write-Host "UNKNOWN - No mode selected, use -domain or -local"
    exit 3
}

# Normalize the input of all admins and create a new listOfUSernames
foreach ($item in $admins)
{
    if($enterprise -or $domain)
    {
        $dc = $currentDomain.NetBIOSName
        $name = $item.SamAccountName
        $listOfUsernames += "$dc\$name"
    }
    else
    {
        $listOfUsernames  += $item
    }
}

# Create a list of additional users that are not in the input list
foreach($item in $listOfUsernames)
{
    if( $usernames -contains $item)
    {
    }
    else
    {
        $listOfAdditionalUsernames += $item
    }
}

# Nagios check now needs to print CRITICAL if needed
if($listOfAdditionalUsernames.Count -eq 0)
{
    Write-Host "OK - No additional users found"
    exit 0
}
else
{
    $response = "CRITICAL - {0} additional users" -f $listOfAdditionalUsernames.Count
    Write-Host $response
    foreach($item in $listOfAdditionalUsernames)
    {
        Write-Host $item
    }
    exit 2
}