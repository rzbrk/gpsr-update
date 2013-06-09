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

use 5.10.1;
package Garmin;
use parent qw(Device);

use strict;
use warnings;
use Data::Dumper;

use Tools;
use XML::Smart;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Request::Common;

=head1 NAME

Garmin.pm -- Package for gpsr-update.pl defining classes and methods for
GPS handheld receivers from Garmin.

=head1 DESCRIPTION

This package defines the classes and routines needed to check available
firmware updates for Garmin GPS heldheld devices. Therefore, it contacts
a Garmin web server and uses the communication protocoll that is used by
the Garmin software "WebUpdater". Details regarding the protocol can be
found here:

  http://www.sbrk.co.uk/getgmn
  https://gitorious.org/quickroute-git/gant/commit/36a8ba7/diffs

=head1 SYNOPSIS

Constructs a new Garmin device object by calling the method new:

  my $dev=Garmin->new({ devpar=>$devpar });
  
Check for updates:

  my $msg=$dev->check_update({ NOLOG=>"no", TESTMODE=>"no" });

Save new updates to XML file, if new updates were found:

  $dev->save_device_data({ NOLOG=>"no",
							  TESTMODE=>"no",
							  id=>$id,
							  xml=>$xml,
							  xml_file=>$xml_file });

=head1 SUBROUTINES/METHODS

=head2 new

Constructs a Garmin object.

=cut

sub new
{
	my $class=shift;
	
	my $self={};
	
	if (@_)
	{
		my ($arg_ref)=@_;
		my $devpar=$arg_ref->{'devpar'} or die "Garmin->new(): Need devpar argument\n";

		$self->{'name'}=$devpar->{'name'}->content || 'Unknown Device';
		$self->{'class'}=$class;
		$self->{'part_no'}=$devpar->{'parameter'}{'part_number'}->content || '001-X00000-00';
		$self->{'ttype'}=$devpar->{'parameter'}{'transfer_type'}->content || 'USB';
		$self->{'regid'}=$devpar->{'parameter'}{'region_id'}->content || '1';
		$self->{'vmaj'}=$devpar->{'parameter'}{'vmaj'}->content || '1';
		$self->{'vmin'}=$devpar->{'parameter'}{'vmin'}->content || '0';
    	$self->{'btype'}=$devpar->{'parameter'}{'build_type'}->content || 'Release';
    	$self->{'sw'}=$devpar->{'software'} || ();
    	$self->{'new_sw'}=undef;
	}

	bless($self, $class);
	return $self;
}

=head2

Checks for updates for the Garmin object. If no update is available
the return string is empty. If an update is available the return string
contains the twitter tweed and the new update parameters are stored in
the object parameter new_sw. In the latter case, call the method
"save_device_data" to store the new update parameter to the XML file.

=cut

sub check_update
{
	my $self=shift;
	my $class=$self->{'class'};
	
	# Get a reference to a hash containing the routine's arguments
	my ($arg_ref)=@_;

	my $NOLOG=$arg_ref->{'NOLOG'} || 0; # Default: Logging on
	my $TESTMODE=$arg_ref->{'TESTMODE'} || 0; # Default: Testmode off
	my $part_no=$self->{'part_no'} || '001-X00000-00';
	my $name=$self->{'name'} || 'Unknown Device';
	my $ttype=$self->{'ttype'} || 'USB';
	my $regid=$self->{'regid'} || '1';
	my $vmaj=$self->{'vmaj'} || '1';
	my $vmin=$self->{'vmin'} || '0';
    my $btype=$self->{'build_type'} || 'Release';

	print "Check for device \"$name\" ...\n" if (! $NOLOG);

	# Date string to mark date when update was found
	my $today=localtime time;

	# Initilaize return value $msg
	my $msg='';

	# Build the HTTP request and submit to GARMIN server
    my $req="req=<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>
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
      Content => $req);

    # Check the response and extract data when possible
    my $ret={'md5'=>'',
	     'vmaj'=>'',
	     'vmin'=>'',
	     'file'=>'',
	     'info'=>'',
	     'size'=>''};

    if ($response->is_success && $response->as_string=~m/.*<Update>.+<\/Update>.*/)
    {
	my $ref = $response->as_string;
  
	$ret->{'vmaj'}=$1 if ($ref=~m/.*<VersionMajor>(\d+)<\/VersionMajor>.*/);
	$ret->{'vmin'}=$1 if ($ref=~m/.*<VersionMinor>(\d+)<\/VersionMinor>.*/);
	$ret->{'file'}=$1 if ($ref=~m/.*<Location>(.+)<\/Location>.*/);
	$ret->{'info'}=$1 if ($ref=~m/.*<AdditionalInfo>(.+)<\/AdditionalInfo>.*/);
	$ret->{'size'}=$1 if ($ref=~m/.*<Size>(\d+)<\/Size>.*/);
	$ret->{'md5'}=$1 if ($ref=~m/.*<MD5Sum>([\w\d]+)<\/MD5Sum>.*/);
    }

	# Now check the MD5. First, if there is a valid answer from GARMIN
	# server, this entry in the data structure is not empty. Second,
	# check, if we already have the software version. If not, then add
	# to array $self->{'sw'} and compose a message for Twitter.
	if (! ${$ret}{'md5'} eq '')
	{
	    if (grep { $_ eq ${$ret}{'md5'} } $self->{'sw'}('[@]', 'md5'))
	    {
		print "  Software version ${$ret}{'vmaj'}.${$ret}{'vmin'} found. Already notified.\n"
		    if (! $NOLOG);
	    } else
	    {
		print "  Software version ${$ret}{'vmaj'}.${$ret}{'vmin'} found. Uh yeah, new version!\n"
		    if (! $NOLOG);
		$self->{'new_sw'}={'vmaj'=>${$ret}{'vmaj'},
						   'vmin'=>${$ret}{'vmin'},
						   'file'=>${$ret}{'file'},
						   'info'=>${$ret}{'info'},
						   'size'=>${$ret}{'size'},
						   'md5'=>${$ret}{'md5'},
						   'found'=>$today};

		# ${$ret}{'file'} and ${$ret}{'$info'} contain URLs. Shorten them:
		my $file_sh=Tools::url_shortener(${$ret}{'file'});
		my $info_sh=Tools::url_shortener(${$ret}{'info'});

		$msg="#Garmin $name: Update to V${$ret}{'vmaj'}.${$ret}{'vmin'} available. Download: $file_sh. Change Log: $info_sh.";
		}
	}
	return $msg;
}

1;
