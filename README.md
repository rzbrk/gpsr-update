gpsr-update
===========

Description
-----------

gpsr-update checks for software updates. First of all, it is meant to
check for updates for GPS handheld devices. Thanks to its object
oriented design it can principally handle GPSr from different 
manufacturers like Garmin or Magellan. Additionally, by defining
"virtual GPSr" it can check also for software updates for non-hardware.
This can be used to check for the existence of updates for e.g. GSAK or
other stuff.

If new updates are available, an appropriate notification is send to
twitter. In addition, this update found is stored into an XML file.
This way, the script can remember all the updates found in the past for
which no notification is needed when the script is called in the future.

This script can be extended basically by adding appropriate packages.

This work wouldn't be possible without the previous work of others. 
The basic functionality I copied from a bash script called "getgmn". The
author is called "Paul". The script can be found here:
  http://www.sbrk.co.uk/getgmn
  https://gitorious.org/quickroute-git/gant/commit/36a8ba7/diffs


Installation
------------

Prerequisites/Dependencies

I developed the script on a Linux machine (Fedora Core 18). Without
modifications, it may not run on other operating systems.

1. Perl modules

You need the following Perl modules available from CPAN:
 Try::Tiny
 XML::Smart;
 LWP::UserAgent;
 HTTP::Request::Common;
 Getopt::Long;
 Config::Simple;
 Net::Twitter;

2. Installation of Perl script

Simply copy at gpsr-update.pl, config.xml and lib/* on your hard drive.
If needed, make changes to config.xml.

3. Registration of application at Twitter

To connect the application to a Twitter account you first have to register
the application. After that you have to grant access to your Twitter account.
For the latter part you find a Perl script in the tools/ directory. Simply
follow the instructions described here:
  http://perl-howto.de/2010/09/mikro-blogging-mit-nettwitter-und-oauth.html


Execution
---------

  gpsr-update.pl [--nolog] [--testmode] [--conf="config.xml"]

  --nolog	 	Disable log output. Default is log output.
  --testmode	In test mode Twitter notifications are suppressed and no
				changes are made to the configuration files (updates
				found).	Default is testmode off.
  --conf		Specify the configuration file. Default is file
				"config.xml" in same directory as the script.
