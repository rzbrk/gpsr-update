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

use strict;
use warnings;

use XML::Smart;
use LWP::UserAgent;
use HTTP::Request::Common;

=head1 NAME

gpsr-update -- Checks for software updates for GARMIN GPS handheld devices
available on GARMIN web server and publishes appropriate notifications on
Twitter.

=head1 DESCRIPTION

gpsr-update checks for software updates for GARMIN GPS handheld devices
available on GARMIN web server and publishes appropriate notifications on
Twitter. The script can handle various GARMIN devices, each has to be defined
in a common XML file (devices.xml).
Basically, gpsr-update immitates the communication of GARMINs software
WebUpdater. The answer of the GARMIN server is checked for available software
updates. Each software version is also stored in the XML file. If the script
recognizes that a new software version, a new entry will be created in the XML
file and a notification along with the links to the download and the release
notes is published on Twitter. For the latter, the external program ttytter
(http://www.floodgap.com/software/ttytter/) is used.

This work wouldn't be possible without the previous work of others. 
The basic functionality I copied from a bash script called "getgmn". The
author is called "Paul". The script can be found here:
  http://www.sbrk.co.uk/getgmn
  https://gitorious.org/quickroute-git/gant/commit/36a8ba7/diffs

=cut

our $VERSION = '0.2';

=head1 VERSION

Version 0.2

=head1 CHANGE LOG

0.1     Initial Release
0.2     Improved log output and implemented test mode in which neither
        changes to XML database nor messaging to Twitter will be performed.
        Additional other small code improvements.

=head1 SYNOPSIS

=cut

# Define some variables
my $xml_file='devices.xml';
my $LOG=1;         # Logging on/off
my $TESTMODE=0;    # In test mode neither changes to XML nor messaging will be
                   # performed

# Open the device configuration file
my $xml=XML::Smart->new($xml_file)
  or die "Cannot open XML file \"$xml_file\" - exit";
$xml=$xml->{devices};

if ($LOG)
{
    print "\n\n***** gpsr-update.pl, Version $VERSION *****\n\n";
    my $now=localtime time;
    print "Now: $now\n";
    print "XML database: $xml_file\n\n";
}

# Create list of devices by part number
my @devs=$xml->{device}('[@]','part_number');

# Loop through the devices
foreach my $part_no (@devs)
{
    # If parameter active is set to 'yes' then go ahead polling
    # Garmin for update of device software
    my $active=$xml->{device}('part_number','eq',$part_no){'active'} || 'no';
    if ($active=~ /yes/i)
    {	
	# Extract parameters for the HTTP request string
	my $name=$xml->{device}('part_number','eq',$part_no)
	{'name'} || '>>Unknown Device<<';
	my $ttype=$xml->{device}('part_number','eq',$part_no)
	{'parameter'}{'transfer_type'} || 'USB';
	my $regid=$xml->{device}('part_number','eq',$part_no)
	{'parameter'}{'region_id'} || '1';
	my $vmaj=$xml->{device}('part_number','eq',$part_no)
	{'parameter'}{'vmaj'} || '1';
	my $vmin=$xml->{device}('part_number','eq',$part_no)
	{'parameter'}{'vmin'} || '0';
    	my $btype=$xml->{device}('part_number','eq',$part_no)
	{'parameter'}{'build_type'} || 'Release';

	print "Check for device $part_no ($name) ...\n" if ($LOG);

	# Extract a list of the software versions by MD5 already found
        my @sw=$xml->{device}('part_number','eq',$part_no)
	{'software'}('[@]','md5');

	# Build the HTTP request and submit to GARMIN server
	my $ret=request($part_no, $ttype, $regid, $vmaj, $vmin, $btype);
	my $md5=${$ret}{'md5'};

	# Now check the MD5. First, if there is a valid answer from GARMIN
	# server, this entry in the data structure is not empty. Second,
	# check, if we already have the software version. If not, then add
	# to XML structure and compose a message for Twitter.
	if (! $md5 eq '')
	{
	    if (grep { $_ eq $md5 } @sw)
	    {
		print "  Software version ${$ret}{'vmaj'}.${$ret}{'vmin'} found. Already notified.\n"
		    if ($LOG);
	    } else
	    {
		print "  Software version ${$ret}{'vmaj'}.${$ret}{'vmin'} found. Uh yeah, new version!\n"
		    if ($LOG);
		my $new_sw={'vmaj'=>${$ret}{'vmaj'},
			    'vmin'=>${$ret}{'vmin'},
			    'file'=>${$ret}{'file'},
			    'info'=>${$ret}{'info'},
			    'size'=>${$ret}{'size'},
			    'md5'=>$md5};
		push(@{$xml->{device}('part_number','eq',$part_no){'software'}}, $new_sw);
		$xml->save($xml_file) if (! $TESTMODE);

		twitter($name, ${$ret}{'file'}, ${$ret}{'info'});
	    }
	}
	print "\n" if ($LOG);
    } else
    {
	print "Skip device $part_no\n\n" if ($LOG);
    }
}


################################################################################

=head1 SUBROUTINES/METHODS

=head2 request

Sends a request to check for the latest software version for a given device
($part_no) to the GARMIN server. Returns a structure reference with the
appropriate information.  

=cut

sub request
{
    my ($part_no, $ttype, $regid, $vmaj, $vmin, $btype)=@_;

    # The request message
    my $msg="req=<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>
	     <Requests xmlns=\"http://www.garmin.com/xmlschemas/UnitSoftwareUpdate/v3\">
	       <Request>
	         <PartNumber>$part_no</PartNumber>
	         <TransferType>$ttype</TransferType>
	         <Region>
	           <RegionId>$regid</RegionId>
	           <Version>
	             <VersionMajor>$vmaj</VersionMajor>
	             <VersionMinor>$vmin</VersionMinor>
	             <BuildType>$btype</BuildType>
	           </Version>
	         </Region>
	       </Request>
	     </Requests>";

    # Poll the GARMIN server
    my $userAgent = LWP::UserAgent->new(agent => 'perl post');
    my $url="http://www.garmin.com/support/WUSoftwareUpdate.jsp";
    my $response = $userAgent->request(POST $url,
      Content_Type => 'application/x-www-form-urlencoded',
      Content => $msg);

    # Check the response and extract data when possible
    my $ret;
    if ($response->is_success && $response->as_string=~m/.*<Update>.+<\/Update>.*/)
    {
	my $ref = $response->as_string;
  
	my $vmaj=$1 if ($ref=~m/.*<VersionMajor>(\d+)<\/VersionMajor>.*/);
	my $vmin=$1 if ($ref=~m/.*<VersionMinor>(\d+)<\/VersionMinor>.*/);
	my $file=$1 if ($ref=~m/.*<Location>(.+)<\/Location>.*/);
	my $info=$1 if ($ref=~m/.*<AdditionalInfo>(.+)<\/AdditionalInfo>.*/);
	my $size=$1 if ($ref=~m/.*<Size>(\d+)<\/Size>.*/);
	my $md5=$1 if ($ref=~m/.*<MD5Sum>([\w\d]+)<\/MD5Sum>.*/);

	$ret={'md5'=>$md5,
	      'vmaj'=>$vmaj,
	      'vmin'=>$vmin,
	      'file'=>$file,
	      'info'=>$info,
	      'size'=>$size};
    } else
    {
	# Sorry :( no result from GARMIN server.
	$ret={'md5'=>'',
	      'vmaj'=>'',
	      'vmin'=>'',
	      'file'=>'',
	      'info'=>'',
	      'size'=>''};
    }

    return $ret;
}

=head2 url_shortener

Accepts one URL, forwards it to the service http://is.gd and finally returns
the shortened URL.

=cut

sub url_shortener
{
    my $long_url=shift;

    my $userAgent = LWP::UserAgent->new(agent => 'perl post');
    my $serv_url="http://is.gd/api.php?longurl=$long_url";
    my $response = $userAgent->request(POST $serv_url,
      Content_Type => 'application/x-www-form-urlencoded',
      Content => '');
    my $short_url;
    if ($response->is_success && $response->as_string=~m|.*(http://is.gd/.+)|)
    {
	$short_url=$1;
    } else
    {
	$short_url='';
    }

    return $short_url;
}

=head2 twitter

Compiles and submits a update notification message to Twitter. As up to now,
this routine uses the external program ttytter for the communication with the
Twitter service. In a later version this will be replaced by using Net::Twitter
or similar.

=cut

sub twitter
{
    my ($devname, $file, $info)=@_;

    # $file and $info contain URLs. Shorten them:
    my $file_sh=url_shortener($file);
    my $info_sh=url_shortener($info);

    my $msg="Update available for device $devname. Download: $file_sh. Change Log: $info_sh.";
    my $len=length($msg);

    my $cmd="/usr/bin/ttytter -hold -status=\"$msg\"";
    print "  Send message to Twitter\n" if ($LOG);
    print "  Message: \"$msg\"\n" if ($TESTMODE);
    my $ret="";
    $ret=system($cmd) if (! $TESTMODE);
    print "$ret\n" if ($LOG);
}
