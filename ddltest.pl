#!/usr/bin/perl
my $Id = '$Id$';

=copyright
test direct downloading (without hub)
Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proler@gmail.com icq#89088275

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA,
or download it from http://www.gnu.org/licenses/gpl.html
=cut

use strict;
#  use Time::HiRes;
eval { use Time::HiRes qw(time sleep); };
use lib './lib';
use dcppp::clihub;

=cu
  use dcppp::clicli;
  print ("usage: ddltest.pl nick:ip:port[/path]/file [bot_nick] [fileas]\n"), exit if !$ARGV[0];
  $ARGV[0] =~ m|^([^:]+):((?:\w+\.?)+)(?:\:(\d+))(/.+)$|;
  my ($nick, $file) = ($1,$4);
#print"[$ARGV[0]] 1=$1 2=$2 ; ";
  my $dc = dcppp::clicli->new(
   'host'		=>	$2,
#   'port'		=>	$2,
   ($2 ? ('port'	=>	$3): (6667) ),
#   'Nick'		=>	($ARGV[1] or 'dcppp_dl' . int(rand(100))),
   'Nick'		=>	($ARGV[1] or $nick),
#   'log'		=>	sub {},	# no logging
   'auto_connect' => 0,
  );
  $file =~ s|^/||;
##  $file =~ s|/|\\|g;
#    $dc->{'handler'}{'MyNick'} = sub {
#print"\n nick $dc->{'peernick'}; $_[0]; = $file; d=$dc->{'Direction'}\n";
#      $dc->{'want'}->{$dc->{'peernick'}}{$file} = $file;
  $dc->{'want'}->{$nick}{$file} = ($ARGV[2] or $file);
  $dc->cmd('connect');
  $dc->recv();
=cut

print("usage: ddltest.pl [dchub://]hub[:port]/nick[/path]/file [bot_nick] [fileas]\n"), exit if !$ARGV[0];
#  $ARGV[0] =~ m|^([^:]+):((?:\w+\.?)+)(?:\:(\d+))(/.+)$|;
$ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?/(.+?)/(.+)$|;
#print"[$ARGV[0]] 1=$1 2=$2 3=$3 4=$4 ; \n";
my ( $user_nick, $file ) = ( $3, $4 );
my $dc = dcppp::clihub->new(
  'host' => $1,
  ( $2 ? ( 'port' => $2 ) : () ),
  'Nick' => ( $ARGV[1] or 'dcpppDl' . int( rand(100) ) ),
  'log' => sub { },    # no logging
);
$dc->get( $user_nick, $file, ( $ARGV[2] or $file ) );    #.get
#  $dc->recv(); sleep(5); $dc->recv();
