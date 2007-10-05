#!/usr/bin/perl
# $Id$ $URL$
# flood default config
#
$config{'flood_tries'}      = 100;
$config{'connect_wait'}     = 30;
$config{'connect_aft_wait'} = 5;
$config{'send_tries'}       = 100;
$config{'send_sleep'}       = 2;
$config{'after_sleep'}      = 2;
$config{'dcbot_param'}      = sub {
  return {
    #      'Timeout'       => 15,
    'Nick' => ( $ARGV[1] or rand_str( rand_int( 1, 10 ) ) ),
    'sharesize'   => rand_int( 1,           1000000000000 ),
    'client'      => rand_str( rand_int( 1, 5 ) ),
    'description' => rand_str( rand_int( 1, 20 ) ),
    'email'   => rand_str( rand_int( 2, 10 ) ) . '@' . rand_str( rand_int( 2, 10 ) ) . '.com',
    'Version' => rand_int( 1,           1000 ),
    'V'       => rand_int( 1,           1000 ),
    'M'       => 'P',                   #mode - passive
                                                                                              #   'log'		=>	sub {},	# no logging
           #   'log'		=>	sub {return if $_[0] =~ /dbg|dmp/},	# no logging
           #   'min_chat_delay'	=> 0.401,
           #   'min_cmd_delay'	=> 0.401,
  };
};
$config{'handler'}{'create_aft'} = sub {
  my ($dc) = @_;
  $dc->{'handler'}{'To'} = $dc->{'handler'}{'welcome'} = sub {
    for (@_) {
      #            print("ban test[$_]\n");
      print("[$dc->{'number'}]BANNED! disconnect.\n"), $dc->disconnect(), last
        if
        /навсегда лишен права говорить в чате и привате|Sorry you are permanently banned|Вы были забанены|временно забанены/i;
    }
  };
  $dc->{'handler'}{'Hello'} = sub {
    print("[$dc->{'number'}] logged in.\n");
  };
};
$config{'handler'}{'send'} = sub {
  my ( $dc, $n ) = @_;
#
# simple chat line
# $dc->cmd( 'chatline', 'Доброго времени суток! Пользуясь случаем, хотим сказать вам: ВЫ Э@3Б@ЛИ СПАМИТЬ!' );
#
# randomized line
# $dc->cmd('chatline',rand_str_ex( 'Доброго времени суток! Пользуясь случаем, хотим попросить Вас больше никогда не рекламировать свой хаб где попало. Спасибо. '. $n ) );
#
# to every private
#  $dc->cmd('To', $_, 'HUB заражен вирусом срочно покиньте его!') for keys %{$dc->{'NickList'}};
#
};

=example with ip changing
my ($ip, $ipa, $ipb, $ipc, $ipd);

sub genip { return (10, 131, rand_int( 230, 255 ), rand_int( 1, 255 ) );}
sub ipglue {return join'.', (@_ or ($ipa, $ipb, $ipc, $ipd))}

$config{'handler'}{'param'} = sub {
  return ('sockopts'    => { 'LocalAddr' => ipglue() });
};

sub if_del {
  print "if del $ip\n";
  print `ifconfig lo1 $ip  -alias`;
}
$config{'handler'}{'create_bef'} = sub {
  ($ipa, $ipb, $ipc, $ipd) = genip();
  $ip = ipglue();
  print "if create $ip\n";
  print `ifconfig lo1 alias $ip/32`;
  print "ok\n";
};
$config{'handler'}{'destroy'} = sub {
  my ($dc) = @_;
  if_del();
};
=cut
