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
package Device;

use strict;
use warnings;

use Tools;

=head1 NAME

Device.pm -- Package for gpsr-update.pl defining common classes and
methods.

=head1 DESCRIPTION

This package defines common classes and routines.

=head1 SUBROUTINES/METHODS

=head2 save_device_data

Save found updates to XML file.

=cut

sub save_device_data
{
	my $self=shift;
	
	# Get a reference to a hash containing the routine's arguments
	my ($arg_ref)=@_;

	my $NOLOG=$arg_ref->{'NOLOG'} || 0; # Default: Logging on
	my $TESTMODE=$arg_ref->{'TESTMODE'} || 0; # Default: Testmode off
	my $id=$arg_ref->{'id'} or die "Garmin->save_device_data(): Need id argument\n";
	my $xml=$arg_ref->{'xml'} or die "Garmin->save_device_data(): Need xml argument\n";
	my $xml_file=$arg_ref->{'xml_file'} or die "Garmin->save_device_data(): Need xml_file argument\n";
	
	if (defined $self->{'new_sw'})
	{
		push @{$xml->{device}('id','eq',$id){'software'}}, $self->{'new_sw'};
		$xml->save($xml_file) if (! $TESTMODE);
	}
}

1;
