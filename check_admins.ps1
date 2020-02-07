##########################################################################################
#
# Name:        check_admins.ps1
# Date:        2020-02-07
# Author:      nikola.vitanovic@atomia.com
# Version:     1.0.0
# Parameters:
#              -enterprise
#              -domain
#              -local
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
    [switch]$enterprise = $false,
    [switch]$domain = $false,
    [switch]$local = $false,
    [String[]]$usernames
)

# Get Local admins from the computer
function get-localadmin {
    param ($strcomputer)
    $admins = Gwmi win32_groupuser –computer $strcomputer   
    $admins = $admins |? {$_.groupcomponent –like '*"Administrators"'}  
    $admins |% {  
    $_.partcomponent –match “.+Domain\=(.+)\,Name\=(.+)$” > $nul  
    $matches[1].trim('"') + “\” + $matches[2].trim('"')  
    }  
}

# Perpare basic variables needed for the task
$currentDomain = Get-ADDomain -Current LocalComputer
$admins = ""
$listOfUsernames = @()
$listOfAdditionalUsernames = @()

# Get list of admins based on the type
if($enterprise)
{
    $admins = Get-ADGroupMember -Identity "Enterprise Admins" -Recursive | %{Get-ADUser -Identity $_.distinguishedName} | Select Name
} 
elseif($domain)
{
    $admins = Get-ADGroupMember -Identity "Domain Admins" -Recursive | %{Get-ADUser -Identity $_.distinguishedName} | Select Name
}
elseif($local)
{
    $admins = get-localadmin $env:computername
}
else
{
    Write-Host "UNKNOWN - No mode selected, use -domain, -enterprise or -local"
    exit 3
}

# Normalize the input of all admins and create a new listOfUSernames
foreach ($item in $admins)
{
    if($enterprise -or $domain)
    {
        $dc = $currentDomain.NetBIOSName
        $name = $item.Name
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