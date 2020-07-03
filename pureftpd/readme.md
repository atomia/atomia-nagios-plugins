This is a set of simple nagios plugins written in perl, python, shell-script & powershell
for testing pureftpd-related parameters

# Usage

## check_symlink_log.sh:

This script checks is there are FTP accounts with root folcers set to paths that are symlinks. It relies on check_symlink_accounts.sh to fill in the logs first, and based on the log output check_symlink_log.sh will report OK or CRITICAL

```sh
./check_symlink_log.sh
```

### Exit codes
```
    0 - OK
    2 - CRITICAL
```

### Examples
Example call when there are users with symlink root directories
```sh
./check_symlink_log.sh
```
Returns:
```sh
CRITICAL - Number of ftp accounts with symlinks as root is 4. The full list can be seen in the /var/log/symlink.log
```

Example call when there are no users with symlink root directories
```sh
./check_symlink_log.sh
```
Returns:
```sh
OK - Number of ftp accounts with symlinks as root is 0
```
### Nagios client setup

Assuming you are using nrpe client on Linux, the check scripts should be put into: `/usr/lib/nagios/plugins/atomia/`

#### cron.d
New file in cron.d should be added with the content line this:

```sh
*/5 * * * * root /usr/lib/nagios/plugins/atomia/check_symlink_accounts.sh
```

#### nrpe.cfg 

Configuratoin should be as follwong:

```sh
command[check_pureftpd_symlinks] = /usr/lib/nagios/plugins/atomia/check_symlink_log.sh
```

### Nagios server sertup

Since the script is a shell script that is triggered with `check_nrpe` example call for domain admins would be:

```sh
/usr/lib/nagios/plugins/check_nrpe -H ftp01.atomia.hostcenter.com -t 150 -c check_pureftpd_symlinks
```