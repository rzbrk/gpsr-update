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
package Ocm;
use parent qw(Device);

use strict;
use warnings;
use Data::Dumper;
use Try::Tiny;

use Tools;
use XML::Smart;
use Getopt::Long;
use LWP::UserAgent;
use HTTP::Request::Common;

=head1 NAME

Ocm.pm -- Package for gpsr-update.pl defining classes and methods for
the geocaching software tool "OCM - OpenCacheManager"
(http://opencachemanage.sourceforge.net/).

=head1 DESCRIPTION

This package defines the classes and routines needed to check available
updates for OCM. OCM is an open source software that is hosted on
SourceForge. SourceForge provides a RSS file for updates on the project
files. This RSS is scanned to search for updates.

=head1 SYNOPSIS

Constructs a new Ocm device object by calling the method new:

  my $dev=Ocm->new({ devpar=>$devpar });
  
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

Constructs a Ocm object.

=cut

sub new
{
	my $class=shift;
	
	my $self={};
	
	if (@_)
	{
		my ($arg_ref)=@_;
		my $devpar=$arg_ref->{'devpar'} or die "Ocm->new(): Need devpar argument\n";

		$self->{'name'}=$devpar->{'name'}->content || 'Unknown Device';
		$self->{'class'}=$class;
		$self->{'url'}=$devpar->{'parameter'}{'url'}->content || '';
		$self->{'sw'}=\@{$devpar->{'software'}} || ();
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
	my $url=$self->{'url'} || '';
	my @sw=@{$self->{'sw'}};

	print "Check for updates for \"$name\" ...\n" if (! $NOLOG);
	
	# Initialize some variables
	my @new_sw=();
	my $msg="";
	my $today=localtime time;
	
	# Open the RSS file
	my $rss=try { XML::Smart->new($url) } catch { undef };
	
	if (defined $rss)
	{
		# Change to root
		$rss=$rss->{'rss'};
		
		# Print the RSS publication date
		if (! $NOLOG)
		{
			print "  RSS publication date: ", $rss->{'channel'}->{'pubDate'}, "\n";
		}
		
		# Loop through all the items in the RSS feed
		my @items=$rss->{'channel'}->{'item'}('@');
		foreach my $i (@items)
		{
			# Filter out the items for OCM Updates
			if ($i->{'title'}=~m/^\/OpenCacheManager\/([0-9]+).([0-9]+)[.]*([0-9]*)$/)
			{
				# Determine if update is already in the XML file. First,
				# assume that the version from RSS is newer
				# ($newer_than_in_xml=1). Then, loop through the SW
				# version in the XML (@sw). If we there find a newer
				# version then set $newer_than_in_xml=0.
				my $newer_than_in_xml=1;
				foreach my $s (@sw)
				{
					$newer_than_in_xml=0 if (! newer($s->{'vmaj'},$s->{'vmin'},$s->{'rev'},$1,$2,$3));
				}
				# If update from RSS is newer than those in the XML file
				# than save it to array @new_sw.
				if ($newer_than_in_xml)
				{
					push @new_sw, {'vmaj'=>$1,
								   'vmin'=>$2,
								   'rev'=>$3,
								   'file'=>$i->{'link'}->content,
								   'found'=>$today};
				}
			}
		}
		# In general, the array @new_sw can contain more than one entry.
		# We have to find the lastest version. Therefore we sort the
		# array to get the latest version as the first element
		@new_sw=sort{$b->{'vmaj'}<=>$a->{'vmaj'}
			         || $b->{'vmin'}<=>$a->{'vmin'}
			         || $b->{'rev'}<=>$a->{'rev'}} @new_sw;

		# Now put the first element in $self->{'new_sw'}. Is undef if
		# no new update was found and @new_sw is empty.
		$self->{'new_sw'}=$new_sw[0];
     
		# if we have a new update then compose a message
		if (defined $self->{'new_sw'})
		{
			my $new_ver_sh=$self->{'new_sw'}->{'vmaj'}.
			     ".".$self->{'new_sw'}->{'vmin'}.
			     ".".$self->{'new_sw'}->{'rev'};
			print "  Version $new_ver_sh found. Uh yeah, new version!\n" if (! $NOLOG);
			my $file_sh=Tools::url_shortener($self->{'new_sw'}->{'file'});
			$msg="#OCM: Version $new_ver_sh available. Download: $file_sh #geocaching";
		} else
		{
			print "  No new version found.\n" if (! $NOLOG);
		}
	}
	return $msg;
}

=head2

"Private" method to compare to version numbers to decide which one is
newer.

=cut

sub newer
{
	# Compares version v1 and v2 and determines if v2 is newer than v1
	my ($v1maj, $v1min, $v1rev, $v2maj, $v2min, $v2rev)=@_;

	my $ret=0;

	if ($v2maj>$v1maj || (($v2maj==$v1maj) && ($v2min>$v1min)) 
	    || (($v2maj==$v1maj) && ($v2min==$v1min) && ($v2rev>$v1rev)))
	{
		$ret=1;
	}
	
	return $ret;
}

1;
