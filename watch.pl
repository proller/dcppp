#!/usr/bin/perl
# $Id$ $URL$

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
eval { use Time::HiRes qw(time sleep); };
use lib './lib';
use dcppp::clihub;
print("usage: flood.pl [dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];
$ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?$|;
for ( 0 .. 1000 ) {
  my $dc = dcppp::clihub->new(
    'host' => $1,
    ( $2 ? ( 'port' => $2 ) : () ),
    'Nick' => ( $ARGV[1] or int( rand(100000000) ) ),
    #   'Nick'		=>	'xxxx',
    'sharesize' => int( rand 1000000000000 ) + int( rand 100000000000 ) * int( rand 100 ),
    #   'log'		=>	sub {},	# no logging
    #   'min_chat_delay'	=> 0.401,
    #   'min_cmd_delay'	=> 0.401,
    'client'      => '++',
    'V'           => '0.698',
    'description' => '',
    'M'           => 'P',
  );
  #  print("BOT SEND all\n"),
  #    $dc->cmd( 'chatline', 'Доброго времени суток! Пользуясь случаем, хотим сказать вам: ВЫ Э@3Б@ЛИ СПАМИТЬ!' );
  #  print("BOT SEND to $_\n"), $dc->cmd( 'To', $_, ' HUB заражен вирусом срочно покиньте его!' )
  #    for keys %{ $dc->{'NickList'} };
  while (1) {
    $dc->wait();    #sleep(5); $dc->recv();
  }
  $dc->destroy();
  sleep(2);
}
