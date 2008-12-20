#!/usr/bin/perl
#my $Id = '$Id$';

=copyright
test direct downloading (without hub)
=cut
use strict;
#  use Time::HiRes;
eval { use Time::HiRes qw(time sleep); };
use lib '../lib';
use Net::DC::clihub;
print("usage: ddltest.pl [dchub://]hub[:port]/nick[/path]/file [bot_nick] [fileas]\n"), exit if !$ARGV[0];
#  $ARGV[0] =~ m|^([^:]+):((?:\w+\.?)+)(?:\:(\d+))(/.+)$|;
$ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?/(.+?)/(.+)$|;
#print"[$ARGV[0]] 1=$1 2=$2 3=$3 4=$4 ; \n";
my ( $user_nick, $file ) = ( $3, $4 );
my $dc = Net::DirectConnect::clihub->new(
  'host' => $1,
  ( $2 ? ( 'port' => $2 ) : () ),
  'Nick' => ( $ARGV[1] or 'dcpppDl' . int( rand(100) ) ),
  'log' => sub { },    # no logging
);
$dc->get( $user_nick, $file, ( $ARGV[2] or $file ) );    #.get
#  $dc->recv(); sleep(5); $dc->recv();
