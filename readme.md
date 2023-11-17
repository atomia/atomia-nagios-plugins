This is a set of simple nagios plugins written in perl, python, shell-script & powershell
for testing that for example [Atomia Hosting Control Panel](http://www.atomia.com/) logins
work.

# Usage

## check_hcp_login.pl:

```sh
./check_hcp_login.pl --uri https://some.uri.of.hcp/ --user somelowprivuser --pass 'somepass' --timeout 5 --match somestring-only-found-after-successfull-login
```

## check_stats_report.sh

Place the following in nrpe.conf on the awstats host:
```sh
command[check_stats_lin]=/home/atomia/nagios/check_stats_report.sh some.linux.site 50 3
command[check_stats_win]=/home/atomia/nagios/check_stats_report.sh some.windows.site 50 3
```

## check_login.py

```sh
python3 check_login.py --url <login_form_url> --username <username> --password <password> [--timeout 5] [--match <matchstring>]
python check_login.py --url <login_form_url> --username <username> --password <password> [--timeout 5] [--match <matchstring>]
```

Dependencies:

* **WWW::Mechanize** (on ubuntu, just `apt-get install libwww-mechanize-perl`)
* **BeautifulSoup4** (ubuntu: `apt-get install python-bs4 python3-bs4`)

## check_certs.ps1
This script checks certificate expiration dates on the Windows server. The script will list all certificates from store, and alert if they are near expiration dates and due for renewal.

### Parameters
Without parameters, the script will by default use "Cert:\LocalMachine\My" cert store and values 15 and 30 for warning and critical thresholds, respectively. The script will automatically recognize lower value and use it as critical threshold instead. Custom values can be set:
```
.\check_certs.ps1
    -CriticalThreshold 10
    -WarningThreshold 20
    -storeLocation "Cert:\LocalMachine\Root"
```

### Exit codes
```
    0 - OK
    1 - WARNING
    2 - CRITICAL
```

## check_admins.ps1
This script checks users on the Windows server. Users can be either local or domain based. The script will compare the list of accounts provided and if there are more users on the system than on the list the script will output CRITICAL.

### Parameters
```
check_admins.ps1
    -domain    "Domain group name"
    -local     "Local group name"
    -usernames "COMPUTER\User1,DOMAIN\User2"
```

### Exit codes
```
    0 - OK
    2 - CRITICAL
    3 - UNKNOWN
```
### Examples
Example call when all users are there, and there are no additional in group **Domain Admins**:
```
./check_admins.ps1 -domain "Domain Admins" -usernames "ATOMIA\Administrator,ATOMIA\apppooluser,ATOMIA\WindowsAdmin"
```
Returns:
```
OK - No additional users found
```
Example call when there is for example additional user that is not in the list:
Example call when all users are there, and there are no additional in group **Domain Admins**:
```
./check_admins.ps1 -domain "Domain Admins" -usernames "ATOMIA\Administrator,ATOMIA\WindowsAdmin"
```
Returns:
```
CRITICAL - 1 additional users
ATOMIA\apppooluser
```
As we can see here in the list above we did not specify the **apppooluser** which has now been shown.

### Nagios client setup
Assuming you are using NSClient++ on Windows, the check script needs to be put into: `C:\Program Files\NSClient++\scripts`.

#### nsclient.ini
Configuration should be as following:
```
[/settings/NRPE/server]

...

allow arguments = true
allow nasty characters = true

[/settings/external scripts]
allow arguments = true
allow nasty characters = true

[/settings/external scripts/scripts]
check_domain_admins = cmd /c echo scripts\check_admins.ps1 -domain "Domain Admins" -usernames $ARG1$; exit($lastexitcode) | powershell.exe -command -
check_enterprise_admins = cmd /c echo scripts\check_admins.ps1 -domain "Enterprise Admins" -usernames $ARG1$; exit($lastexitcode) | powershell.exe -command -
check_local_admins = cmd /c echo scripts\check_admins.ps1 -local "Administrators" -usernames $ARG1$; exit($lastexitcode) | powershell.exe -command -
```

Here we define three most common commands for checking **Domain Admins and Enterprise Admins** domain groups and **Administrators** local group.

### Nagios server setup

Since the script is a shell script that is triggered with `check_nrpe` example call for domain admins would be:
```
/usr/local/nagios/libexec/check_nrpe -H 192.168.33.20 -t 30 -c check_domain_admins -a "ATOMIA\Administrator,ATOMIA\WindowsAdmin"
```
This would call **check_domain_admins** command in the client which then accepts parameters as on the script.

The command in Nagios would be setup like this:

Command: `$USER1$/check_nrpe -H $HOSTADDRESS$ -t 30 -c $ARG1$ -a $ARG2$`

$ARG1$: `check_domain_admins`

$ARG2$: `'"ATOMIA\Administrator","ATOMIA\WindowsAdmin"'`

or

$ARG2$: `'"ATOMIA\Administrator,ATOMIA\WindowsAdmin"'`

> **Important:** Use double quotes `'"` - wrap whole argument in `'` quotes


> **Important:** 
> Use `check_nrpe_1arg` instead `check_nrpe` as _Check command_ in Nagios UI interface.
>
> `check_nrpe_1arg` passes `$ARG2$` argument via `-a` as required, where `check_nrpe` passes `$ARG2$` via `-c` and it is not properly substituted. Powershell script will get `$` as parameter value instead value in `$ARG2$`

## check_logons.ps1
Nagios plugin that alerts if there are 4624 EventIDs aka logins in the Security event log of the system.

In case there are unknown users CRITICAL message will be shown and exit code will be 2. Additional users with computer name or NetBIOS domain will be shown in the new lines after the CRITICAL message. In case there are unknown source IPs they will also be logged as CRITICAL.

The plugin logs a timestamp of last processed log in the TEMP folder. This timestamp is used to process only logs after the timestamp. Last processed log timestamp will be stored and all logs from that time forward will be processed.

You will get CRITICAL every next time the check occurs, after the first CRITICAL was encountered. Path to the file that should be deleted is shown in the CRITICAL Nagios message.

The script can be run in two ways via Nagios:
1. Normally with all options via NSClient++ configuration.
2. As separate Windows scheduled task, and one instance with `-checkOnly` option in NSClient++ configuration.

The option 2 is preferred because this check may take longer since it parses the EventLog. Option 1 is still possible but would involve in increasing the NRPE timeout which is not covered by this guide.

### Parameters
```
check_logons.ps1
    -logonTypes '10','3'
    -ignoreUsers 'VAGRANT\WINMASTER$','VAGRANT\Administrator'
    -ignoreIPs '127.0.0.1','192.168.33.10','192.168.33.22'
    -debug
    -id
```
All parameters are optional. Ignore parameters are essentially whitelists that say that the users or ips in the list are ignored and entries that contain them are ok. They will not result in critical if the ignore value is matched.

#### logonTypes
This parameters tells the script which 4624 Event logon types to check from the Security logs. Parameters are a list of logon type ids. For example 10 is Terminal services meaning RDP connection to the server is checked. There are various options available shown on the table below:

<table class="table">
<thead>
<tr class="header">
<th>Logon type</th>
<th>Logon title</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td><p>2</p></td>
<td><p>Interactive</p></td>
<td><p>A user logged on to this computer.</p></td>
</tr>
<tr class="even">
<td><p>3</p></td>
<td><p>Network</p></td>
<td><p>A user or computer logged on to this computer from the network.</p></td>
</tr>
<tr class="odd">
<td><p>4</p></td>
<td><p>Batch</p></td>
<td><p>Batch logon type is used by batch servers, where processes may be executing on behalf of a user without their direct intervention.</p></td>
</tr>
<tr class="even">
<td><p>5</p></td>
<td><p>Service</p></td>
<td><p>A service was started by the Service Control Manager.</p></td>
</tr>
<tr class="odd">
<td><p>7</p></td>
<td><p>Unlock</p></td>
<td><p>This workstation was unlocked.</p></td>
</tr>
<tr class="even">
<td><p>8</p></td>
<td><p>NetworkCleartext</p></td>
<td><p>A user logged on to this computer from the network. The user's password was passed to the authentication package in its unhashed form. The built-in authentication packages all hash credentials before sending them across the network. The credentials do not traverse the network in plaintext (also called cleartext).</p></td>
</tr>
<tr class="odd">
<td><p>9</p></td>
<td><p>NewCredentials</p></td>
<td><p>A caller cloned its current token and specified new credentials for outbound connections. The new logon session has the same local identity, but uses different credentials for other network connections.</p></td>
</tr>
<tr class="even">
<td><p>10</p></td>
<td><p>RemoteInteractive</p></td>
<td><p>A user logged on to this computer remotely using Terminal Services or Remote Desktop.</p></td>
</tr>
<tr class="odd">
<td><p>11</p></td>
<td><p>CachedInteractive</p></td>
<td><p>A user logged on to this computer with network credentials that were stored locally on the computer. The domain controller was not contacted to verify the credentials.</p></td>
</tr>
</tbody>
</table>

Detailed information can be found on: https://bit.ly/2ULjexx

#### ignoreUsers
This parameter requires a list of users that are ignored and allowed by the script. Idea is to specify the list of all users that require access to the server where the check is running.

If you don't specify `-ignoreUsers` any username will be treated as unknown. Usernames need to be specified in format "DOMAIN\Username" or "COMPUTER\Username". NetBIOS short name should be used.

#### ignoreIPs
If you don't specify `-ignoreIPs` any IP will be treated as suspcious. You can specify multiple IPs or only one. Any event that has different IP than the one available in the list will be reported as suspicious. Make sure that all IPs are specified.

#### disableIPCheck
Disables checking of the IPs from the Security log. By default you need to specify a list of IPs that will be whitelisted or you will get a CRITICAL alert if any IP shows.
If you specify `-disableIPCheck` IPs from the login events won't be checked, the parameter `-ignoreIPs` won't have any effect.

#### debug
This parameter gives more info about the running of the script, of all logs that are processed and various other info such as locations of lock files and temp directory. This should be only specified when you are debugging the output of the script, in case some logs are there that are not correctly parsed.

#### id
If you specify `-id` option a folder will be created in the temp directory where the log and lock files will be created.

#### testOnly
If you specify `-testOnly` it will just check if there is last lock file that is not removed. If it exists message from that log will be written else the OK message will be written to the user.

There is no need to specify any other options other than `-id` if you are running `-testOnly` since they would not be checked, only the lock file is checked.

#### logLocation
If you specify `-logLocation` script will create and check the lock files in that location. You should specify absolute path. By default it's the temp location available from the environment variable.

### Exit codes
```
    0 - OK
    2 - CRITICAL
    3 - UNKNOWN
```

### Examples
Example call that will incorporate all options and no weird settings.
```
./check_logons.ps1 -logonTypes 10 -ignoreIPs '127.0.0.1','192.168.33.10','192.168.33.22' -ignoreUsers 'VAGRANT\WINMASTER$'
```
Response:
```
OK - Processed 3883 logs
```
This means that everything was OK and no suspicious activity was detected.

If you specified the `-checkOnly` option and are running the actual check in the task scheduler then if everything was ok you would get the following response:
```
OK - No suspicious activity in  the last scan
```

Next example shows how the script works in User mode only and shows how unknown user `vitanovic` has logged into the server. In case that the `Administrator` has logged no alert would have happened.

Call:
```
./check_logons.ps1 -logonTypes 10 -disableIPCheck -ignoreUsers 'VAGRANT\WINMASTER$','VAGRANT\Administrator'
```

Response:
```
CRITICAL - There are 2 unauthorised logins
Suspicious user - User: VAGRANT\vitanovic IP: 192.168.33.1 EventIndex: 148446 LogonType: 10
Suspicious user - User: VAGRANT\vitanovic IP: 192.168.33.1 EventIndex: 148445 LogonType: 10
```
Example call where you just check for the existance of lock file. This is useful when you are running the script as Nagios check. This example assumes that you already run the script like above with parameters that you want and only check for the existance of the lock file.
```
./check_logons.ps1 -id SOME_ID -checkOnly
```
### Task scheduler setup
In order for the script not to timeout, it's needed to set it up as a Scheduled task in Windows. You would need to set this up on each and every server that you want to run the script.
Let's say that we want to run the script with the following arguments:
```
./check_logons.ps1 -logonTypes 10 -disableIPCheck -ignoreUsers 'VAGRANT\WINMASTER$','VAGRANT\Administrator' -id LOGON
```
You should first try to run this manually and see if the desired output is generated:
```
powershell.exe -executionPolicy bypass -file "C:\Program Files (x86)\Atomia\Security\check_logons.ps1" "-disableIPCheck" "-id" "LOGON" "-ignoreUsers" "VAGRANT\Administrator,VAGRANT\WINMASTER$"
```
Make sure that you put the full path to the location of the script that you are trying to run.

If your folder and files are generated as expected proceed with task creation in the scheduled tasks.
1. Create a new Task (not basic task).
2. Select the options like on the image:

![](https://i.imgur.com/np49eVP.png)

3. Go to the Triggers tab and set a Daily trigger that repeats every 5 minutes:

![](https://i.imgur.com/Y4dJV6n.png)

4. On the Actions tab fill out the image like the above powershell call:

![](https://i.imgur.com/RVkRd4c.png)

5. You can manually trigger the task to run it for the first time and afterwards it would repeat.

### Nagios client setup
Assuming you are using NSClient++ on Windows, the check script needs to be put into: `C:\Program Files\NSClient++\scripts`.

#### nsclient.ini
Configuration should be as following:
```
[/settings/NRPE/server]

...

allow arguments = true
allow nasty characters = true

[/settings/external scripts]
allow arguments = true
allow nasty characters = true

[/settings/external scripts/scripts]
check_logons = cmd /c echo scripts\check_logons.ps1 -id $ARG1$ -checkOnly  ; exit($lastexitcode) | powershell.exe -command -
```

Here we define three most common commands for checking **Domain Admins and Enterprise Admins** domain groups and **Administrators** local group.

### Nagios server setup

Since the script is a shell script that is triggered with `check_nrpe` example call for domain admins would be:
```
/usr/local/nagios/libexec/check_nrpe -H 192.168.177.26 -t 30 -c check_logons -a SOME_ID
```
This would call **check_logons** command in the client which then accepts parameters as on the script.

The command in Nagios would be setup like this:

Command: `$USER1$/check_nrpe -H $HOSTADDRESS$ -t 30 -c $ARG1$ -a $ARG2$ $ARG3$ $ARG4$ $ARG5$`

$ARG1$: `check_logons`

$ARG2$: `SOME_ID`