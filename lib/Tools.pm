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
package Tools;

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request::Common;

=head1 NAME

Tools.pm -- Package for gpsr-update.pl defining common routines.

=head1 DESCRIPTION

This package defines common routines.

=head1 SUBROUTINES/METHODS

=head2 url_shortener

Accepts one URL, forwards it to the service http://is.gd and finally
returns the shortened URL.

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

1;
