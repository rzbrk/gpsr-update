#!/usr/bin/perl

# Taken from:
# http://perl-howto.de/2010/09/mikro-blogging-mit-nettwitter-und-oauth.html

use strict;
use warnings;

use Config::Simple;
use Net::Twitter;

my $config_file = 'twitter.access.ini';
my $cfg = new Config::Simple( syntax => 'ini' ) or die $!;

# You can replace the consumer tokens with your own;
# these tokens are for the Net::Twitter example app.
my %consumer_tokens = (
    consumer_key    => '2me0nEHW7ylxM4vP00hw',
    consumer_secret => 'XvhTk0TFt1OhNJ7lVQe7G2bC3dImGxfr89CFDtB9gTM',
);

my $nt = Net::Twitter->new( traits => [qw/API::REST OAuth/], %consumer_tokens );

# Authorization
my $auth_url = $nt->get_authorization_url;
print "Diese Applikation muss autorisiert werden.\n";
print "Bitte $auth_url \n";
print "in einem Browser oeffnen und den Zugang erlauben.\n";
print "Bitte Twitter-PIN eingeben: ";
my $pin = <STDIN>;    # Auf Eingabe warten
chomp $pin;

# Authorizatioon with PIN
my ( $access_token, $access_token_secret, $user_id, $screen_name ) =
  $nt->request_access_token( verifier => $pin )
  or die $!;

# Write data to config file
$cfg->param( 'access_token',         $access_token );
$cfg->param( 'accesss_token_secret', $access_token_secret );
$cfg->param( 'user_id',              $user_id );
$cfg->param( 'screen_name',          $screen_name );
$cfg->param( 'consumer_key',         $consumer_tokens{consumer_key} );
$cfg->param( 'consumer_secret',      $consumer_tokens{consumer_secret} );

$cfg->write($config_file) or die $!;
exit;
