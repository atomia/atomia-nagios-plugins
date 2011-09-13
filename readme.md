This is a simple nagios plugin written in perl for testing that [Atomia Hosting Control Panel](http://www.atomia.com/) logins
work.

Usage is like:
./check_hcp_login.pl --uri https://some.uri.of.hcp/ --user somelowprivuser --pass 'somepass' --timeout 5 --match somestring-only-found-after-successfull-login

Dependencies:
* WWW::Mechanize (on ubuntu, just apt-get install libwww-mechanize-perl)
