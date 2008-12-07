#!/usr/bin/perl
my $Id = '$Id$';

=copyright
counting users-bytes from dchub for mrtg or cacti (snmpd)
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
use lib './lib';
use dcppp::clihub;
print("usage: countub.pl [dchub://]host[:port] [bot_nick] [share_delim]\n"), exit if !$ARGV[0];
$ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?$|;
my $dc = dcppp::clihub->new(
  'host' => $1,
  ( $2 ? ( 'port' => $2 ) : () ),
  'Nick' => ( $ARGV[1] or 'dcpppCnt' ),
  'log' => sub { },    # no logging
);
$dc->connect();
#  $dc->cmd('GetNickList');
#  $dc->recv();
my ($share) = (0);
$dc->wait_sleep(3);    #for 1 .. 3;
$dc->cmd( 'GetINFO', $_ ) for grep !$dc->{'NickList'}->{$_}{'info'}, keys %{ $dc->{'NickList'} };
$dc->wait_sleep(3);    #for 1 .. 3;
$share += $dc->{'NickList'}{$_}{'sharesize'} for keys %{ $dc->{'NickList'} };
$share /= $ARGV[2] if $ARGV[2];
print( ( scalar keys %{ $dc->{'NickList'} } or 0 ), "\n$share\n$ARGV[0]\nz\n" );
