This is a set of simple nagios plugins written in perl and shell-script
for testing that for example [Atomia Hosting Control Panel](http://www.atomia.com/) logins
work.

## Usage

For check_hcp_login.pl:

```sh
./check_hcp_login.pl --uri https://some.uri.of.hcp/ --user somelowprivuser --pass 'somepass' --timeout 5 --match somestring-only-found-after-successfull-login
```

For check_stats_report.sh, place the following in nrpe.conf on the awstats host:

```sh
command[check_stats_lin]=/home/atomia/nagios/check_stats_report.sh some.linux.site 50 3
command[check_stats_win]=/home/atomia/nagios/check_stats_report.sh some.windows.site 50 3
```

Dependencies:

* WWW::Mechanize (on ubuntu, just apt-get install libwww-mechanize-perl)
