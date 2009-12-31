#$Id$ $URL$
package    #hide from cpan
  Net::DirectConnect::clihub;
use strict;
use Time::HiRes qw(time sleep);
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 1;
use Net::DirectConnect;
use Net::DirectConnect::clicli;
#use Net::DirectConnect::http;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
use base 'Net::DirectConnect';

sub init {
  my $self = shift;
  %$self = (
    %$self,
    'Nick' => 'NetDCBot',
    'port' => 411,
    'host' => 'localhost',
    'Pass' => '',
    'key'  => 'zzz',
    #'auto_wait'        => 1,
    'supports_avail' => [ qw(
        NoGetINFO
        NoHello
        UserIP2
        UserCommand
        TTHSearch
        OpPlus
        Feed
        MCTo
        HubTopic
        )
    ],
    'search_every'     => 10,
    'search_every_min' => 10,
    'auto_connect'     => 1,
    'NoGetINFO'        => 1,                                                                                            #test
    'NoHello'          => 1, 'UserIP2' => 1, 'Version' => '1,0091', 'auto_GetNickList' => 1, 'follow_forcemove' => 1,
    #ADC
    #'connect_protocol' => 'ADC/0.10',
    #'message_type'     => 'H',
    @_,
    'incomingclass' => 'Net::DirectConnect::clicli',
    'periodic'      => sub { $self->cmd( 'search_buffer', ) if $self->{'socket'}; },
  );
  #$self->log($self, 'inited',"MT:$self->{'message_type'}", ' with', Dumper  \@_);
  $self->baseinit();
  #$self->log( $self, 'inited3', "MT:$self->{'message_type'}", ' with' );
  $self->{'parse'} ||= {
    'chatline' => sub {
      my ( $nick, $text ) = $_[0] =~ /^(?:<|\* )(.+?)>? (.+)$/s;
      #$self->log('dcdev', 'chatline parse', Dumper(\@_,$nick, $text));
      $self->log( 'warn', "[$nick] oper: already in the hub [$self->{'Nick'}]" ), $self->cmd('nick_generate'),
        $self->reconnect(),
        if ( ( !keys %{ $self->{'NickList'} } or $self->{'NickList'}->{$nick}{'oper'} )
        and $text eq 'You are already in the hub.' );
      if ( $self->{'NickList'}->{$nick}{'oper'} or $nick eq 'Hub-Security' ) {
        if (
             $text =~ /^(?:Minimum search interval is|Минимальный интервал поиска):(\d+)s/
          or $text =~ /Search ignored\.  Please leave at least (\d+) seconds between search attempts\./  #Hub-Security opendchub
          )
        {
          $self->log( 'warn', "[$nick] oper: set min interval = $1" );
          $self->{'search_every'} = int $1 || $self->{'search_every_min'};
          $self->search_retry();
        }
        if ( $text =~ /(?:Пожалуйста )?подождите (\d+) секунд перед следующим поиском\./i
                                     
          or $text eq 'Пожалуйста не используйте поиск так часто!' )
        {              
          $self->log( 'warn', "[$nick] oper: increase min interval +=", int $1 || $self->{'search_every_min'} ),
            $self->{'search_every'} += int $1 || $self->{'search_every_min'};
          $self->search_retry();
        }
      }
      $self->search_retry(),
        if $self->{'NickList'}->{$nick}{'oper'} and $text eq 'Sorry Hub is busy now, no search, try later..';
    },
    'welcome' => sub {
      my ( $nick, $text ) = $_[0] =~ /^(?:<|\* )(.+?)>? (.+)$/s;
      if ( ( !keys %{ $self->{'NickList'} } or !exists $self->{'NickList'}->{$nick} or $self->{'NickList'}->{$nick}{'oper'} )
        and $text =~ /^Bad nickname: unallowed characters, use these (\S+)/ )
      {
        my $try = $self->{'Nick'};
        $try =~ s/[^\Q$1\E]//g;
        $self->log( 'warn', "CHNICK $self->{'Nick'} -> $try" );
        $self->{'Nick'} = $try if length $try;
      }
    },
    'Lock' => sub {
      #$self->log( "lockparse", @_ );
      $self->{'sendbuf'} = 1;
      $self->cmd('Supports');
      $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
      #print "lock[$1]\n";
      $self->cmd( 'Key', $self->lock2key($1) );
      $self->{'sendbuf'} = 0;
      $self->cmd('ValidateNick');
    },
    'Hello' => sub {
      #$self->log('info', "HELLO recieved, connected. me=[$self->{'Nick'}]", @_);
      return unless $_[0] eq $self->{'Nick'};
      $self->{'sendbuf'} = 1;
      $self->cmd('Version');
      $self->{'sendbuf'} = 0 unless $self->{'auto_GetNickList'};
      $self->cmd('MyINFO');
      $self->{'sendbuf'} = 0, $self->cmd('GetNickList') if $self->{'auto_GetNickList'};
      $self->{'status'} = 'connected';
      $self->cmd('make_hub');
    },
    'Supports' => sub {
      $self->supports_parse( $_[0], $self );
    },
    'ValidateDenide' => sub {
      $self->cmd('nick_generate');
      $self->cmd('ValidateNick');
    },
    'To' => sub {
      $self->log( 'msg', "Private message to", @_ );
    },
    'MyINFO' => sub {
      my ( $nick, $info ) = $_[0] =~ /\S+\s+(\S+)\s+(.*)/;
      $self->{'NickList'}->{$nick}{'Nick'} = $nick;
      $self->info_parse( $info, $self->{'NickList'}{$nick} );
      $self->{'NickList'}->{$nick}{'online'} = 1;
    },
    'UserIP' => sub {
      /(\S+)\s+(\S+)/, $self->{'NickList'}{$1}{'ip'} = $2, $self->{'IpList'}{$2} = $self->{'NickList'}{$1},
        $self->{'IpList'}{$2}{'port'} = $self->{'PortList'}{$2}
        for grep $_, split /\$\$/, $_[0];
    },
    'HubName' => sub {
      $self->{'HubName'} = $_[0];
    },
    'HubTopic' => sub {
      $self->{'HubTopic'} = $_[0];
    },
    'NickList' => sub {
      $self->{'NickList'}->{$_}{'online'} = 1 for grep $_, split /\$\$/, $_[0];
    },
    'OpList' => sub {
      $self->{'NickList'}->{$_}{'oper'} = 1 for grep $_, split /\$\$/, $_[0];
    },
    'ForceMove' => sub {
      $self->log( 'warn', "ForceMove to $_[0]" );
      $self->disconnect();
      sleep(1);
      $self->connect(@_) if $self->{'follow_forcemove'} and @_;
    },
    'Quit' => sub {
      $self->{'NickList'}->{ $_[0] }{'online'} = 0;
    },
    'ConnectToMe' => sub {
      my ( $nick, $host, $port ) = $_[0] =~ /\s*(\S+)\s+(\S+)\:(\S+)/;
      $self->{'PortList'}->{$host} = $port;
      #$self->log('dev', "portlist: $host = $self->{'PortList'}->{$host} :=$port");
      return if $self->{'clients'}{ $host . ':' . $port }->{'socket'};
      $self->{'clients'}{ $host . ':' . $port } = Net::DirectConnect::clicli->new(
        %$self, $self->clear(),
        'host' => $host,
        'port' => $port,
#'want'         => \%{ $self->{'want'} },        'NickList'     => \%{ $self->{'NickList'} },        'IpList'       => \%{ $self->{'IpList'} },        'PortList'     => \%{ $self->{'PortList'} },        'handler'      => \%{ $self->{'handler'} },
        'want'         => $self->{'want'},
        'NickList'     => $self->{'NickList'},
        'IpList'       => $self->{'IpList'},
        'PortList'     => $self->{'PortList'},
        'handler'      => $self->{'handler'},
        'auto_connect' => 1,
      );
    },
    'RevConnectToMe' => sub {
      my ( $to, $from ) = split /\s+/, $_[0];
      $self->cmd( 'ConnectToMe', $to ) if $from eq $self->{'Nick'};
    },
    'GetPass' => sub {
      $self->cmd('MyPass');
    },
    'BadPass' => sub {
    },
    'LogedIn' => sub {
    },
    'Search' => sub {
      my $search = $_[0];
      $self->cmd('make_hub');
      my %s = ( 'time' => int( time() ), 'hub' => $self->{'hub_name'}, );
      ( $s{'who'}, $s{'cmds'} ) = split /\s+/, $search;
      $s{'cmd'} = [ split /\?/, $s{'cmds'} ];
      if ( $s{'who'} =~ /^Hub:(.+)$/ ) { $s{'nick'} = $1; }
      else                             { ( $s{'ip'}, $s{'port'} ) = split /:/, $s{'who'}; }
      if   ( $s{'cmd'}[4] =~ /^TTH:([0-9A-Z]{39})$/ ) { $s{'tth'}    = $1; }
      else                                            { $s{'string'} = $s{'cmd'}[4]; }
      $s{'string'} =~ tr/$/ /;
      $self->cmd('make_hub');

      if ( $self->{'share_tth'} and $s{'tth'} and $self->{'share_tth'}{ $s{'tth'} } ) {
        $self->log(
          'adcdev', 'Search', $s{'who'},
          $self->{'share_tth'}{ $s{'tth'} },
          -s $self->{'share_tth'}{ $s{'tth'} },
          -e $self->{'share_tth'}{ $s{'tth'} }
          ),
          $self->{'share_tth'}{ $s{'tth'} } =~ tr{\\}{/};
        $self->{'share_tth'}{ $s{'tth'} } =~ s{^/+}{};
        my $path;
        if ( $self->{'adc'} ) { $path = $self->adc_path_encode( $self->{'share_tth'}{ $s{'tth'} } ); }
        else {
          $path = $self->{'share_tth'}{ $s{'tth'} };
          $path =~ s{^\w:}{};
          $path =~ s{^\W+}{};
          $path =~ tr{/}{\\};
        }
        local @_ = (
          'SR', (
            #( $self->{'M'} eq 'P' or !$self->{'myport_tcp'} or !$self->{'myip'} )            ?
            $self->{'Nick'}
              #: $self->{'myip'} . ':' . $self->{'myport_tcp'}
          ),
          $path . "\x05" . ( -s $self->{'share_tth'}{ $s{'tth'} } or -1 ),
          $self->{'S'} . '/'
            . $self->{'S'} . "\x05" . "TTH:"
            . $s{'tth'}
            #. ( $self->{'M'} eq 'P' ? " ($self->{'host'}:$self->{'port'})" : '' ),
            #. (  " ($self->{'host'}:$self->{'port'})\x05$s{'nick'}"  ),
            . ( " ($self->{'host'}:$self->{'port'})" . ( ( $s{'ip'} and $s{'port'} ) ? '' : "\x05$s{'nick'}" ) ),
#. ( $self->{'M'} eq 'P' ? " ($self->{'host'}:$self->{'port'})\x05$s{'nick'}" : '' ),
#{ SI => -s $self->{'share_tth'}{ $params->{TR} },SL => $self->{INF}{SL},FN => $self->adc_path_encode( $self->{'share_tth'}{ $params->{TR} } ),=> $params->{TO} || $self->make_token($peerid),TR => $params->{TR}}
        );
        if ( $s{'ip'} and $s{'port'} ) { $self->send_udp( $s{'ip'}, $s{'port'}, join ' ', @_ ); }
        else                           { $self->cmd(@_); }
      }
#'SR', ( $self->{'M'} eq 'P' ? "Hub:$self->{'Nick'}" : "$self->{'myip'}:$self->{'myport_udp'}" ),        join '?',
#Hub:	[Outgoing][80.240.208.42:4111]	 	$SR prrrrroo0 distr\s60\games\10598_paintball2.zip621237 1/2TTH:3TFVOXE2DS6W62RWL2QBEKZBQLK3WRSLG556ZCA (80.240.208.42:4111)breathe|
#$SR prrrrroo0 distr\moscow\mom\Mo\P\Paintball.htm1506 1/2TTH:NRRZNA5MYJSZGMPQ634CPGCPX3ZBRLKHAACPAFQ (80.240.208.42:4111)breathe|
#$SR prrrrroo0 distr\moscow\mom\Map\P\Paintball.htm3966 1/2TTH:QLRRMET6MSNJTIRKBDLQYU6RMI5QVZDZOGAXEXA (80.240.208.42:4111)breathe|
#$SR ILICH ЕГТС_07_2007\bases\sidhouse.DBF120923801 6/8TTH:4BAKR7LLXE65I6S4HASIXWIZONBEFS7VVZ7QQ2Y (80.240.211.183:411)
#$SR gellarion7119 MuZonnO\Mark Knopfler - Get Lucky (2009)\mark_knopfler_-_you_cant_beat_the_house.mp36599140 7/7TTH:IDPHZ4AJIIWDYOFEKCCVJUNVIPGSGTYFW5CGEQQ (80.240.211.183:411)
#$SR 13th_day Картинки\еще девки\sacrifice_penthouse02.jpg62412 0/20TTH:GHMWHVBKRLF52V26VFO4M4RUQ65NC3YKWIW7FPI (80.240.211.183:411)
#DIRECT:
#$SR server1 server\Unsorted\Desperate.Housewives.S04.720p.HDTV.x264\desperate.housewives.s04e03.720p.hdtv.x264.Rus.Eng.mkv1194423977 2/2TTH:6YWRGDXNQJEOGSB4Q7Y3Y7XRM7EXPLUK7GBRJ3A (80.240.211.183:411)
#$SR MikMEBX Deep purple\1980-1988\08-The House Of Blue Light.1987 10/10[ f12p.ru ][ F12P-HUB ] - день единства... вспомните хорошее и улыбнитесь друг другу.. пусть это будет днем гармонии (80.240.211.183)
#PASSIVE
#$SR ILICH ЕГТС_07_2007\bases\sidhouse.DBF120923801 6/8TTH:4BAKR7LLXE65I6S4HASIXWIZONBEFS7VVZ7QQ2Y (80.240.211.183:411)
#$SR gellarion7119 MuZonnO\Mark Knopfler - Get Lucky (2009)\mark_knopfler_-_you_cant_beat_the_house.mp36599140 7/7TTH:IDPHZ4AJIIWDYOFEKCCVJUNVIPGSGTYFW5CGEQQ (80.240.211.183:411)
#$SR SALAGA Видео\Фильмы\XXX\xxx Penthouse.avi732665856 0/5TTH:3OFCM6GPQZNBNAMV6SRDFHFPK2X76EO6UCIO7ZQ (80.240.211.183:411)
      return \%s;
    },
    'SR' => sub {
      $self->cmd('make_hub');
      my %s = ( 'time' => int( time() ), 'hub' => $self->{'hub_name'}, );
      ( $s{'nick'}, $s{'str'} ) = split / /, $_[0], 2;
      $s{'str'} = [ split /\x05/, $s{'str'} ];
      $s{'file'} = shift @{ $s{'str'} };
      ( $s{'filename'} ) = $s{'file'}     =~ m{([^\\]+)$};
      ( $s{'ext'} )      = $s{'filename'} =~ m{[^.]+\.([^.]+)$};
      ( $s{'size'}, $s{'slots'} )  = split / /, shift @{ $s{'str'} };
      ( $s{'tth'},  $s{'ipport'} ) = split / /, shift @{ $s{'str'} };
      ( $s{'target'} ) = shift @{ $s{'str'} };
      $s{'tth'} =~ s/^TTH://;
      ( $s{'ipport'}, $s{'ip'}, $s{'port'} ) = $s{'ipport'} =~ /\(((\S+):(\d+))\)/;
      delete $s{'str'};
      ( $s{'slotsopen'}, $s{'S'} ) = split /\//, $s{'slots'};
      $s{'slotsfree'} = $s{'S'} - $s{'slotsopen'};
      $s{'string'}    = $self->{'search_last_string'};
      $self->{'NickList'}{ $s{'nick'} }{$_} = $s{$_} for qw(S ip port);
      $self->{'PortList'}->{ $s{'ip'} }     = $s{'port'};
      $self->{'IpList'}->{ $s{'ip'} }       = $self->{'NickList'}{ $s{'nick'} };
      return \%s;
    },
    'UserCommand' => sub {
    },
  };

=COMMANDS








=cut  

  $self->{'cmd'} = {
    'chatline' => sub {
      for (@_) {
        if ( $self->{'min_chat_delay'} and ( time - $self->{'last_chat_time'} < $self->{'min_chat_delay'} ) ) {
          $self->log( 'dbg', 'sleep', $self->{'min_chat_delay'} - time + $self->{'last_chat_time'} );
          $self->wait_sleep( $self->{'min_chat_delay'} - time + $self->{'last_chat_time'} );
        }
        $self->{'last_chat_time'} = time;
        $self->log(
          'dcdmp',
          "($self->{'number'}) we send [",
          "<$self->{'Nick'}> $_|",
          "]:", $self->{'socket'}->send("<$self->{'Nick'}> $_|"), $!
        );
      }
    },
    'To' => sub {
      my $self = shift if ref $_[0];
      my $to = shift;
      $self->sendcmd( 'To:', $to, "From: $self->{'Nick'} \$<$self->{'Nick'}> $_" ) for (@_);
    },
    'Key' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'Key', $_[0] );
    },
    'ValidateNick' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'ValidateNick', $self->{'Nick'} );
    },
    'Version' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'Version', $self->{'Version'} );
    },
    'MyINFO' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'MyINFO', '$ALL', $self->myinfo() );
    },
    'GetNickList' => sub {
      $self->sendcmd('GetNickList');
    },
    'GetINFO' => sub {
      my $self = shift if ref $_[0];
      @_ = grep { $self->{'NickList'}{$_}{'online'} and !$self->{'NickList'}{$_}{'info'} } keys %{ $self->{'NickList'} }
        unless @_;
      local $self->{'sendbuf'} = 1;
      $self->sendcmd( 'GetINFO', $_, $self->{'Nick'} ) for @_;
      $self->sendcmd();
    },
    'ConnectToMe' => sub {
      my $self = shift if ref $_[0];
      return if $self->{'M'} eq 'P' and !$self->{'allow_passive_ConnectToMe'};
      $self->log( 'err', "please define myip" ), return unless $self->{'myip'};
      $self->sendcmd( 'ConnectToMe', $_[0], "$self->{'myip'}:$self->{'myport'}" );
    },
    'RevConnectToMe' => sub {
      my $self = shift if ref $_[0];
      $self->log( "send", ( 'RevConnectToMe', $self->{'Nick'}, $_[0] ), ref $_[0] );
      $self->sendcmd( 'RevConnectToMe', $self->{'Nick'}, $_[0] );
    },
    'MyPass' => sub {
      my $self = shift if ref $_[0];
      my $pass = ( $_[0] or $self->{'Pass'} );
      $self->sendcmd( 'MyPass', $pass ) if $pass;
    },
    'Supports' => sub {
      $self->sendcmd( 'Supports', $self->supports() || return );
    },
    'Quit' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'Quit', $self->{'Nick'} );
      $self->disconnect();
    },
    'SR' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'SR', @_ );
    },
    'Search' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'Search', ( $self->{'M'} eq 'P' ? "Hub:$self->{'Nick'}" : "$self->{'myip'}:$self->{'myport_udp'}" ),
        join '?', @_ );
    },
    'search_tth' => sub {
      my $self = shift if ref $_[0];
      $self->{'search_last_string'} = undef;
      if ( $self->{'adc'} ) {
        #$self->cmd( 'search_buffer', { TO => $self->make_token(), TR => $_[0], } );
      }    #toauto
      else { $self->cmd( 'search_buffer', 'F', 'T', '0', '9', 'TTH:' . $_[0] ); }
    },
    'search_string' => sub {
      my $self = shift if ref $_[0];
      my $string = $_[0];
      if ( $self->{'adc'} ) {
        #$self->cmd( 'search_buffer', { TO => 'auto', map AN => $_, split /\s+/, $string } );
        #$self->cmd( 'search_buffer', ( map { 'AN' . $_ } split /\s+/, $string ), { TO => $self->make_token(), } );    #TOauto
      } else {
        $self->{'search_last_string'} = $string;
        $string =~ tr/ /$/;
        $self->cmd( 'search_buffer', 'F', 'T', '0', '1', $string );
      }
    },
    'search_send' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'Search',
        ( ( $self->{'myip'} && $self->{'myport_udp'} ) ? "$self->{'myip'}:$self->{'myport_udp'}" : 'Hub:' . $self->{'Nick'} ),
        join '?', @{ $_[0] || $self->{'search_last'} } );
    },
    'make_hub' => sub {
      my $self = shift if ref $_[0];
      $self->{'hub_name'} ||= $self->{'host'} . ( ( $self->{'port'} and $self->{'port'} != 411 ) ? ':' . $self->{'port'} : '' );
    },
    #
  };
  $self->log( 'dev', "0making listeners [$self->{'M'}]" );
  if ( $self->{'M'} eq 'A' or !$self->{'M'} ) {
    $self->log( 'dev', "making listeners: tcp" );
    $self->{'clients'}{'listener_tcp'} = $self->{'incomingclass'}->new(
      %$self, $self->clear(),
      'want'        => \%{ $self->{'want'} },
      'NickList'    => \%{ $self->{'NickList'} },
      'IpList'      => \%{ $self->{'IpList'} },
      'PortList'    => \%{ $self->{'PortList'} },
      'handler'     => \%{ $self->{'handler'} },
      'auto_listen' => 1,
      'parent'      => $self,
    );
    $self->{'myport'} = $self->{'myport_tcp'} = $self->{'clients'}{'listener_tcp'}{'myport'};
    $self->log( 'err', "cant listen tcp (file transfers)" ) unless $self->{'myport_tcp'};
    $self->log( 'dev', "making listeners: udp" );
    $self->{'clients'}{'listener_udp'} = $self->{'incomingclass'}->new(
      %$self, $self->clear(),
      'Proto' => 'udp',
      #?    'want'     => \%{ $self->{'want'} },
      #?    'NickList' => \%{ $self->{'NickList'} },
      #?    'IpList'   => \%{ $self->{'IpList'} },
      #?    'PortList' => \%{ $self->{'PortList'} },
      'handler' => \%{ $self->{'handler'} },
      #$self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, $self->clear(),
      #'LocalPort'=>$self->{'myport'},
      #'debug'=>1,
      #'nonblocking' => 0,
      'parse' => {
        'SR'  => $self->{'parse'}{'SR'},
        'PSR' => sub {                     #U
          #$self->log( 'dev', "UPSR", @_ );
        },
#2008/12/14-13:30:50 [3] rcv: welcome UPSR FQ2DNFEXG72IK6IXALNSMBAGJ5JAYOQXJGCUZ4A NIsss2911 HI81.9.63.68:4111 U40 TRZ34KN23JX2BQC2USOTJLGZNEWGDFB327RRU3VUQ PC4 PI0,64,92,94,100,128,132,135 RI64,65,66,67,68,68,69,70,71,72
#UPSR CDARCZ6URO4RAZKK6NDFTVYUQNLMFHS6YAR3RKQ NIAspid HI81.9.63.68:411 U40 TRQ6SHQECTUXWJG5ZHG3L322N5B2IV7YN2FG4YXFI PC2 PI15,17,20,128 RI128,129,130,131
#$SR [Predator]Wolf DC++\Btyan Adams - Please Forgive Me.mp314217310 18/20TTH:G7DXSTGPHTXSD2ZZFQEUBWI7PORILSKD4EENOII (81.9.63.68:4111)
#2008/12/14-13:30:50 welcome UPSR FQ2DNFEXG72IK6IXALNSMBAGJ5JAYOQXJGCUZ4A NIsss2911 HI81.9.63.68:4111 U40 TRZ34KN23JX2BQC2USOTJLGZNEWGDFB327RRU3VUQ PC4 PI0,64,92,94,100,128,132,135 RI64,65,66,67,68,68,69,70,71,72
#UPSR CDARCZ6URO4RAZKK6NDFTVYUQNLMFHS6YAR3RKQ NIAspid HI81.9.63.68:411 U40 TRQ6SHQECTUXWJG5ZHG3L322N5B2IV7YN2FG4YXFI PC2 PI15,17,20,128 RI128,129,130,131
#$SR [Predator]Wolf DC++\Btyan Adams - Please Forgive Me.mp314217310 18/20TTH:G7DXSTGPHTXSD2ZZFQEUBWI7PORILSKD4EENOII (81.9.63.68:4111)
      },
      'auto_listen' => 1,
      'parent'      => $self,
    );
    $self->{'myport_udp'} = $self->{'clients'}{'listener_udp'}{'myport'};
    $self->log( 'err', "cant listen udp (search repiles)" ) unless $self->{'myport_udp'};
  }

=z
  $self->log( 'dev', "making listeners: http" );
    $self->{'clients'}{'listener_http'} = Net::DirectConnect::http->new(
      %$self, $self->clear(),
#'want'     => \%{ $self->{'want'} },
#'NickList' => \%{ $self->{'NickList'} },
#'IpList'   => \%{ $self->{'IpList'} },
##      'PortList' => \%{ $self->{'PortList'} },
      'handler'  => \%{ $self->{'handler'} },
#$self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, $self->clear(),
      #'LocalPort'=>$self->{'myport'},
      #'debug'=>1,
      'auto_listen' => 1,
    );
    $self->{'myport_http'}  = $self->{'clients'}{'listener_http'}{'myport'};
    $self->log( 'err', "cant listen http" )
      unless $self->{'myport_http'};
=cut

  $self->{'handler_int'}{'disconnect_bef'} = sub {
    delete $self->{'sid'};
    $self->log( 'dev', 'disconnect int' ) if $self;
  };
}
1;
