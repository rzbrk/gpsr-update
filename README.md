gpsr-update
===========

Description
-----------

gpsr-update checks for software updates for GARMIN GPS handheld devices
available on GARMIN web server and publishes appropriate notifications on
Twitter. The script can handle various GARMIN devices, each has to be defined
in a common XML file (e.g. devices.xml).
Basically, gpsr-update immitates the communication of GARMINs software
WebUpdater. The answer of the GARMIN server is checked for available software
updates. Each software version is also stored in the XML file. If the script
recognizes that a new software version is available, a new entry will be
created in the XML file and a notification along with the links to the
download and the release notes is published on Twitter.

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
 XML::Smart;
 LWP::UserAgent;
 HTTP::Request::Common;
 Getopt::Long;
 Config::Simple;
 Net::Twitter;

2. Installation of Perl script

Simply copy at least gpsr-update.pl and devices.xml on your hard drive. If
needed, add additional device profiles in devices.xml.

3. Registration of application at Twitter

To connect the application to a Twitter account you first have to register
the application. After that you have to grant access to your Twitter account.
For the latter part you find a Perl script in the tools/ directory. Simply
follow the instructions described here:
  http://perl-howto.de/2010/09/mikro-blogging-mit-nettwitter-und-oauth.html


Execution
---------

  gpsr-update.pl [--nolog] [--testmode] [--twitter="twitter.ini"]
                 [--devconf="devices.xml"]

  --nolog	 Disable log output. Default is log output.
  --testmode	 In test mode Twitter notifications are suppressed.
  		 Default is to notificate via Twitter
  --twitter	 Specify the file holding the Twitter account details.
  		 Default is file "twitter.ini" in same directory as the script.
  --devconf	 Specify the file with the device configurations. Default is
  		 file "devices.xml" in same directory as the script.