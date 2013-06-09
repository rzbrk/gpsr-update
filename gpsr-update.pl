#!/usr/bin/perl

#    Copyright (C) 2013  Jan Grosser (email@jan-grosser.de)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

use v5.10.1;

use strict;
use warnings;
use Data::Dumper;

use Try::Tiny;
use XML::Smart;
use LWP::UserAgent;
use HTTP::Request::Common;
use Getopt::Long;
use Net::Twitter;

# Manufacturer dependend libraries
use lib "lib";
use Device;
use Garmin;
use Gsak;
use Ocm;
use Tools;

=head1 NAME

gpsr-update -- Checks for firmware updates for GPS handheld devices and
some geocaching related software tools. If updates are available an
appropriate notifications will be send via Twitter.

=head1 DESCRIPTION

gpsr-update checks for software updates. First of all, it is meant to
check for updates for GPS handheld devices. Thanks to its object
oriented design it can principally handle GPSr from different 
manufacturers like Garmin or Magellan. Additionally, by defining
"virtual GPSr" it can check also for software updates for non-hardware.
This can be used to check for the existence of updates for e.g. GSAK or
other stuff.

If new updates are available, an appropriate notification is send via
Twitter. In addition, this update found is stored into an XML file.
This way, the script can remember all the updates found in the past for
which no notification is needed when the script is called in the future.

This script can be extended basically by adding appropriate packages.

This work wouldn't be possible without the previous work of others. 
The basic functionality I copied from a bash script called "getgmn". The
author is called "Paul". The script can be found here:
  http://www.sbrk.co.uk/getgmn
  https://gitorious.org/quickroute-git/gant/commit/36a8ba7/diffs

=cut

our $VERSION = '0.5';

=head1 VERSION

Version 0.5

=head1 CHANGE LOG

0.1     Initial Release
0.2     Improved log output and implemented test mode in which neither
        changes to XML database nor messaging to Twitter will be performed.
        Additional other small code improvements.
0.3     Implemented Net::Twitter and command line options. Additional other
        small code improvements.
0.4     Changed format of Twitter notification. The device name is mentioned at
        the beginning and the tweet includs the version number.
0.5		Rewrote complete code to OOP. The twitter credentials are now
		integrated to the XML configuration file. Changed command line
		options.

=head1 SYNOPSIS

  ./gpsr-update.pl [--nolog] [--testmode] [--conf="config.xml"]

=cut

# Define some variables
my $NOLOG=0;       # Logging on/off; default on
my $TESTMODE=0;    # In test mode neither changes to XML nor messaging will be
                   # performed
my $xml_file='config.xml';

# Check for command line options and override above default values if necessary
my $resopt=GetOptions("nolog" => \$NOLOG,
                      "testmode" => \$TESTMODE,
                      "conf=s" => \$xml_file);

if (! $NOLOG)
{
    print "\n\n***** gpsr-update.pl, Version $VERSION *****\n\n";
    my $now=localtime time;
    print "Now: $now\n";
}

# Open the configuration file
my $xml=XML::Smart->new($xml_file) or die $!;
$xml=$xml->{config} or die "$xml_file is no valid configuration file.";

# Get the Twitter credentials
my $access_token=$xml->{'twitter'}{'access_token'}->content || "";
my $access_token_secret=$xml->{'twitter'}{'access_token_secret'}->content || "";
my $user_id=$xml->{'twitter'}{'user_id'}->content || "";
my $screen_name=$xml->{'twitter'}{'screen_name'}->content || "";
my $consumer_key=$xml->{'twitter'}{'consumer_key'}->content || "";
my $consumer_secret=$xml->{'twitter'}{'consumer_secret'}->content || "";

# Connect to Twitter
my $nt = Net::Twitter->new(
    traits => [qw/API::REST OAuth/],
    ( consumer_key => $consumer_key,
      consumer_secret => $consumer_secret,
      access_token => $access_token,
      access_token_secret => $access_token_secret )
);

if (! $NOLOG)
{
    print "XML database: $xml_file\n\n";
}

# Create list of devices by id
my @devs=$xml->{'device'}('[@]','id');


# Loop through the devices
foreach my $id (@devs)
{
	# Extract the parameter for the device selected from the xml
	# structure
	my $devpar=$xml->{'device'}('id','eq',$id);

    # If parameter active is set to 'yes' then go ahead polling
    # Garmin for update of device software
    my $active=$devpar->{'active'}->content || 'no';
    if ($active=~ /yes/i)
    {
	# Determine the manufacturer and the module to use. First letter of 
	# $class needs to be uppercase, rest lowercase
	my $class=$devpar->{'class'}->content || "Default";
	$class=lc $class; $class=ucfirst $class;
	my $name=$devpar->{'name'}->content || "";

	no strict 'refs';
	my $gpsr=try { $class->new({ devpar=>$devpar }) } catch { undef };
	
	my $msg=try { $gpsr->check_update({ NOLOG=>$NOLOG,
								        TESTMODE=> $TESTMODE }) } catch { "" };

	$gpsr->save_device_data({ NOLOG=>$NOLOG,
							  TESTMODE=> $TESTMODE,
							  id=>$id,
							  xml=>$xml,
							  xml_file=>$xml_file });
							  		  
	twitter($nt, $msg) if (! $msg eq '');

	print "\n" if (! $NOLOG);
    } else
    {
	print "Skip device $id\n\n" if (! $NOLOG);
    }
}

# Finally, close connection to Twitter
$nt->end_session();

################################################################################

=head1 SUBROUTINES/METHODS

=head2 twitter

Submits an update notification message to Twitter.

=cut

sub twitter
{
	my ($nt, $msg)=@_;

    my $len=length($msg);

    print "  Send message to Twitter\n" if (! $NOLOG);
    print "  Message: \"$msg\" ($len characters)\n" if (! $NOLOG);
    if (! $TESTMODE)
    {
		$nt->update($msg) or die $!;
    }
}
