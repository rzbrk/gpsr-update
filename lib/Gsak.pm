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
package Gsak;
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

Gsak.pm -- Package for gpsr-update.pl defining classes and methods for
the geocaching software tool "GSAK - Geocaching Swiss Army Knife"
(http://www.gsak.net).

=head1 DESCRIPTION

This package defines the classes and routines needed to check available
patches (builds) for GSAK. GSAK is a MSWindows software and the builds
are available as downloads on http://gsak.net. For GSAK version 8.2.1
the format of the download URL is
"http://gsak.net/GSAK821B<build-no>.exe". The <build-no> is an
ascending integer. For checking for new builds the existance of download
files with higher <build-no> is checked.

=head1 SYNOPSIS

Constructs a new Gsak device object by calling the method new:

  my $dev=Gsak->new({ devpar=>$devpar });
  
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

Constructs a Gsak object.

=cut

sub new
{
	my $class=shift;
	
	my $self={};
	
	if (@_)
	{
		my ($arg_ref)=@_;
		my $devpar=$arg_ref->{'devpar'} or die "Gsak->new(): Need devpar argument\n";

		$self->{'name'}=$devpar->{'name'}->content || 'Unknown Device';
		$self->{'class'}=$class;
		$self->{'url'}=$devpar->{'parameter'}{'url'}->content || 'http://gsak.net/GSAK000B*.exe';
		$self->{'ver'}=$devpar->{'ver'}->content || '000';
		$self->{'sw'}=$devpar->{'software'} || ();
    	$self->{'new_sw'}=undef;
	}

	bless($self, $class);
	return $self;
}

=head2

Checks for updates for the Gsak object. If no update is available
the return string is empty. If an update is available the return string
contains the twitter tweed and the new update parameters are stored in
the object parameter new_sw. In the latter case, call the method
"save_device_data" to store the new update parameter to the XML file.

=cut

sub check_update
{
	my $self=shift;

	# Get a reference to a hash containing the routine's arguments
	my ($arg_ref)=@_;

	my $NOLOG=$arg_ref->{'NOLOG'} || 0; # Default: Logging on
	my $TESTMODE=$arg_ref->{'TESTMODE'} || 0; # Default: Testmode off
	my $name=$self->{'name'} || 'Unknown Device';
	my $url=$self->{'url'} || 'http://gsak.net/GSAK000B*.exe';
	
	print "Check for builds for \"$name\" ...\n" if (! $NOLOG);

	# Get the latest build from the build array
	my @builds=$self->{'sw'}('[@]', 'build');
	@builds=sort {$a <=> $b} @builds;
	my $lastbuild=$builds[-1];

	# Test for a newer build. Therefor do *not* only check for the next
	# build number but for the next couple of build numbers. This can
	# also handle situations where we missed a build or the next build
	# number is not new=old+1
	my $nextbuild=$lastbuild;
	my $nexturl;
	foreach my $n (1 ... 19)
	{
		my $testbuild=$lastbuild+$n;
		my $testurl = do { (my $tmp = $url) =~ s/[*]/$testbuild/; $tmp };
		my $userAgent = LWP::UserAgent->new(agent => 'perl post');
		my $request = new HTTP::Request ('HEAD', $testurl);
		my $response = $userAgent->request($request);
		my $return_code=$response->status_line;
		$return_code=substr($return_code, 0, 3);
		if ($return_code eq "200")
		{
			$nextbuild=$testbuild;
			$nexturl=$testurl;
		}
	}

	# Initialize return value
	my $msg="";

	if ($nextbuild != $lastbuild)
	{
		my $today=localtime time;
		$self->{'new_sw'}={'file'=>$nexturl,
						   'info'=>'',
						   'ver'=>$self->{'ver'},
						   'build'=>$nextbuild,
						   'found'=>$today};
		print "  Build $nextbuild found. Uh yeah, new build!\n" if (! $NOLOG);
		my $nexturl_sh=Tools::url_shortener($nexturl);
		$msg="#GSAK: Build $nextbuild available. Download: $nexturl_sh. For info visit http://gsak.net/board. #geocaching";		
	} else
	{
		print "  Build $nextbuild found. Already notified.\n" if (! $NOLOG);
	}

	return $msg;
}

1;
