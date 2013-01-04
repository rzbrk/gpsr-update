gpsr-update
===========

Description
-----------

This Perl script checks for software updates for GARMIN GPS handheld devices
available on GARMIN web server and publishes appropriate notifications on
Twitter.

Installation
------------

Prerequisites/Dependencies

I developed the script on a Linux machine (OpenSUSE). Without modifications,
it will not run on other operating systems.

1. Perl modules

You need the following Perl modules available from CPAN:
 XML::Smart
 LWP::UserAgent
 HTTP::Request::Common

2. Installation of ttytter

Install the Twitter command line client ttytter. You can download this
software from http://www.floodgap.com/software/ttytter/. Before you can use
ttytter with gpsr-update, ttytter has to create a key file to be able to
communicate with the Twitter servers. Please follow the instructions on the
website of ttytter. You need to have a Twitter account.

3. Installation of Perl script

Simply copy at least gpsr-update.pl and devices.xml on your hard drive. If
needed, add additional device profiles in devices.xml.

Execution
---------

To start the script, open a terminal window, change to the directory
gpsr-update.pl is located and type

`./gpsr-update.pl`

There are (currently) no command line options.
