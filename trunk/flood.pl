#!/usr/bin/perl
my $Id = '$Id: dcppp.pl 107 2006-03-01 21:45:44Z pro $';

=copyright
flood tests
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
print("usage: flood.pl [dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];
$ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?$|;
my $dc = dcppp::clihub->new(
  'host' => $1,
  ( $2 ? ( 'port' => $2 ) : () ),
  'Nick' => ( $ARGV[1] or 'dcppp_flooder' . int( rand(100) ) ),
  #   'log'		=>	sub {},	# no logging
  #   'min_chat_delay'	=> 0.401,
  #   'min_cmd_delay'	=> 0.401,
);
#  $dc->connect();
#  $dc->cmd('GetNickList');
$dc->recv();
#  $dc->cmd('chatline', 't');
#  $dc->cmd('chatline', '?showstats xxx');
#  $dc->cmd('chatline', 't2');
my $i;
$dc->cmd( 'To', '[skying]pro(+)', 'zz' . $i++ . 'z' . rand(1000) ),
  #  $dc->recv(),
  1 for 0 .. 100000;

=c
  $dc->{'sharesize'} = $_,
  $dc->cmd('MyINFO'),
  $dc->recv()
#  sleep(0.1)
   for 0..1000;
=cut

$dc->recv();
sleep(5);
$dc->recv();
