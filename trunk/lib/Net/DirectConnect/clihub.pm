#$Id$ $URL$
package Net::DirectConnect::clihub;
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
    'connect_protocol' => 'ADC/0.10',
    'message_type'     => 'H',
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
        if ( $text =~ /Пожалуйста подождите (\d+) секунд перед следующим поиском\./
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
      return unless $_[0] eq $self->{'Nick'};
      #$self->log('info', "HELLO recieved, connected.");
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
      my %s = ( 'time' => int( time() ), 'hub' => $self->{'hub'}, );
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
      my %s = ( 'time' => int( time() ), 'hub' => $self->{'hub'}, );
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
#
#=================
#ADC dev
#
#'ISUP' => sub { }, 'ISID' => sub { $self->{'sid'} = $_[0] }, 'IINF' => sub { $self->cmd('BINF') },    'IQUI' => sub { },    'ISTA' => sub { $self->log( 'dcerr', @_ ) },
    'SUP' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #for my $feature (split /\s+/, $_[0])
      $self->log( 'adcdev', 'SUP:', @_ );
      #=z
      for ( $self->adc_strings_decode(@_) ) {
        if   ( (s/^(AD|RM)//)[0] eq 'RM' ) { delete $self->{'peers'}{$peerid}{'SUP'}{$_}; }
        else                               { $self->{'peers'}{$peerid}{'SUP'}{$_} = 1; }
      }
      #=cut

=z
      my $params = $self->adc_parse_named(@_);
      for ( keys %$params ) {
        delete $self->{'peers'}{$peerid}{'SUP'}{ $params->{$_} } if $_ eq 'RM';
        $self->{'peers'}{$peerid}{'SUP'}{ $params->{$_} } = 1 if $_ eq 'AD';
      }
=cut      
      return $self->{'peers'}{$peerid}{'SUP'};
    },
    'SID' => sub {
      my $self = shift if ref $_[0];
      $self->{'sid'} = $_[1];
      $self->log( 'adcdev', 'SID:', $self->{'sid'} );
      return $self->{'sid'};
    },
    'INF' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #test $_[1] eq 'I'!
      #$self->log('adcdev', '0INF:', "[d=$dst,p=$peerid]", join ':', @_);
      my $params = $self->adc_parse_named(@_);
      #for (@_) {
      #s/^(\w\w)//;
      #my ($code)= $1;
      #$self->log('adcdev', 'INF:', $peerid,  Dumper $params);
      #$self->{'peers'}{$peerid}{'INF'}{$code} = $_;
      #}
      my $peersid = $peerid;
      if ( $dst ne 'B' and $peerid ||= $params->{ID} ) {
        $self->{'peerid'} = $peerid;
        $self->{'peers'}{$peerid}{$_} = $self->{'peers'}{''}{$_} for keys %{ $self->{'peers'}{''} || {} };
        delete $self->{'peers'}{''};
      }
      $self->{'peers'}{$peerid}{'INF'}{$_} = $params->{$_} for keys %$params;
      $self->{'peers'}{ $params->{ID} } ||= $self->{'peers'}{$peerid};
      $self->{'peers'}{$peerid}{'SID'}  ||= $peersid;
      #$self->log( 'adcdev', 'INF:', $peerid, Dumper $params, $self->{'peers'} ) unless $peerid;
      $self->cmd( 'B', 'INF' ), $self->{'status'} = 'connected' if $dst eq 'I';    #clihub
      if ( $dst eq 'C' ) {
        $self->cmd( $dst, 'INF' ), $self->{'status'} = 'connected';                #clicli
        if   ( $params->{TO} ) { }
        else                   { }
        $self->cmd('file_select');
        $self->cmd( $dst, 'GET' );
      }
      return $self->{'peers'}{$peerid}{'INF'};
    },
    'QUI' => sub {
      my $self = shift if ref $_[0];
      my ($dst) = @{ shift() };
      #$peerid
      #$self->log( 'adcdev', 'QUI', $dst, $_[0], Dumper $self->{'peers'}{ $_[0] } );
      delete $self->{'peers'}{ $_[0] };    # or mark time
    },
    'STA' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #$self->log( 'dcerr', @_ );
      my $code = shift;
      $code =~ s/^(.)//;
      my $severity = $1;
#TODO: $severity :
#0 	Success (used for confirming commands), error code must be "00", and an additional flag "FC" contains the FOURCC of the command being confirmed if applicable.
#1 	Recoverable (error but no disconnect)
#2 	Fatal (disconnect)
#my $desc = $self->{'codesSTA'}{$code};
      @_ = $self->adc_strings_decode(@_);
      $self->log( 'adcdev', 'STA', $peerid, $severity, $code, @_, "=[$Net::DirectConnect::codesSTA{$code}]" );
      return $severity, $code, $Net::DirectConnect::codesSTA{$code}, @_;
    },
    'SCH' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid, @feature ) = @{ shift() };
      #$self->log( 'adcdev', 'SCH', ( $dst, $peerid, 'F=>', @feature ), 'S=>', @_ );
      my $params = $self->adc_parse_named(@_);
      #DRES J3F4 KULX SI0 SL57 FN/Joculete/logs/stderr.txt TRLWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ TOauto
      $self->{'share_tth'}{ $params->{TR} } =~ tr{\\}{/};
      if (  $self->{'share_tth'}
        and $params->{TR}
        and $self->{'share_tth'}{ $params->{TR} }
        and -s $self->{'share_tth'}{ $params->{TR} } )
      {
        $self->log(
          'adcdev', 'SCH',
          ( $dst, $peerid, 'F=>', @feature ),
          $self->{'share_tth'}{ $params->{TR} },
          -s $self->{'share_tth'}{ $params->{TR} },
          -e $self->{'share_tth'}{ $params->{TR} }
        );
        local @_ = (
          $peerid, {
            SI => ( -s $self->{'share_tth'}{ $params->{TR} } ) || -1,
            SL => $self->{INF}{SL},
            FN => $self->adc_path_encode( $self->{'share_tth'}{ $params->{TR} } ),
            TO => $params->{TO}                                || $self->make_token($peerid),
            TR => $params->{TR}
          }
        );
        if ( $self->{'peers'}{$peerid}{INF}{I4} and $self->{'peers'}{$peerid}{INF}{U4} ) {
          $self->log(
            'dcdev', 'SCH', 'i=', $self->{'peers'}{$peerid}{INF}{I4},
            'u=', $self->{'peers'}{$peerid}{INF}{U4},
            'T==>', 'U' . 'RES' . $self->adc_make_string(@_)
          );
          $self->send_udp(
            $self->{'peers'}{$peerid}{INF}{I4},
            $self->{'peers'}{$peerid}{INF}{U4},
            'U' . 'RES ' . $self->adc_make_string(@_)
          );
        } else {
          $self->cmd( 'D', 'RES', @_ );
        }
      }
      #$self->adc_make_string(@_);
      #TODO active send udp
      return $params;
      #TRKU2OUBVHC3VXUNOHO2BS2G4ECHYB6ESJUQPYFSY TO626120869 ]
      #TRQYKHJIZEPSISFF3T25DIGKEYI645Y7PGMSI7QII TOauto ]
      #ANthe ANhossboss TO3951841973 ]
      #FSCH ABWN +TCP4 TRKX55JDOFEBX32GLBSITTSY6KUCK4NMPU2R4XUII TOauto
    },
    'RES' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #test $_[1] eq 'I'!
      #$self->log('adcdev', '0INF:', "[d=$dst,p=$peerid]", join ':', @_);
      my $params = $self->adc_parse_named(@_);
      #$self->log('adcdev', 'RES:',"[d=$dst,p=$peerid]",Dumper $params);
      $params;
    },
    'MSG' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #@_ = map {adc_string_decode} @_;
      @_ = $self->adc_strings_decode(@_);
      #$self->log( 'adcdev', 'MSG', "<" . $self->{'peers'}{$peerid}{'INF'}{'NI'} . '>', @_ );
      @_;
    },
    'RCM' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid, $toid ) = @{ shift() };
      $self->log( 'dcdev', "( $dst, RCM, $peerid, $toid )", @_ );
      $self->cmd( $dst, 'CTM', $peerid, $_[0], $self->{'myport'}, $_[1], ) if $toid eq $self->{'sid'};

=z      
       $self->{'clients'}{ $host . ':' . $port } = Net::DirectConnect::clicli->new(
        %$self, $self->clear(),
        'host'         => $host,
        'port'         => $port,
#'want'         => \%{ $self->{'want'} },
#'NickList'     => \%{ $self->{'NickList'} },
#'IpList'       => \%{ $self->{'IpList'} },
#'PortList'     => \%{ $self->{'PortList'} },
#'handler'      => \%{ $self->{'handler'} },
        'auto_connect' => 1,
      );
=cut
    },
    'CTM' => sub {
      my $self = shift if ref $_[0];
      my ( $dst,   $peerid, $toid )  = @{ shift() };
      my ( $proto, $port,   $token ) = @_;
      my $host = $self->{'peers'}{$peerid}{'INF'}{'I4'};
      $self->log( 'dcdev', "( $dst, CTM, $peerid, $toid ) - ($proto, $port, $token)", );
      $self->log( 'dcerr', 'CTM: unknown host', "( $dst, CTM, $peerid, $toid ) - ($proto, $port, $token)" ) unless $host;
      $self->{'clients'}{ $self->{'peers'}{$peerid}{'INF'}{ID} or $host . ':' . $port } = Net::DirectConnect::clicli->new(
        %$self, $self->clear(),
        'host'  => $host,
        'port'  => $port,
        'parse' => $self->{'parse'},
        'cmd'   => $self->{'cmd'},
        'want'  => $self->{'want'},
        #'want'         => \%{ $self->{'want'} },
        #'NickList'     => \%{ $self->{'NickList'} },
        #'IpList'       => \%{ $self->{'IpList'} },
        #'PortList'     => \%{ $self->{'PortList'} },
        #'handler'      => \%{ $self->{'handler'} },
        #'TO' => $token,
        'INF'          => { %{ $self->{'INF'} }, 'TO' => $token },
        'message_type' => 'C',
        'auto_connect' => 1,
      );
    },
    'SND' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid, $toid ) = @{ shift() };
      #CSND file files.xml.bz2 0 6117
      $self->{'filetotal'} = $_[3];
      return $self->file_open();
    },
    #CGET file TTH/YDIXOH7A3W233WTOQUET3JUGMHNBYNFZ4UBXGNY 637534208 6291456
    'GET' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid, $toid ) = @{ shift() };
      $self->file_send_parse(@_);

=z
      if ( $_[0] eq 'file' ) {
        my $file = $_[1];
        if ( $file =~ s{^TTH/}{} ) { $self->file_send_tth( $file, $_[2], $_[3] ); }
        else {
          #$self->file_send($file, $_[2], $_[3]);
        }
      } else {
        $self->log( 'dcerr', 'SND', "unknown type", @_ );
      }
=cut
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
    'search_buffer' => sub {
      my $self = shift if ref $_[0];
      push( @{ $self->{'search_todo'} }, [@_] ) if @_;
      return unless @{ $self->{'search_todo'} || return };
#$self->log($self, 'search', Dumper \@_);
#$self->log( 'dcdev', "search too fast [$self->{'search_every'}], len=", scalar @{ $self->{'search_todo'} } )        if @_ and scalar @{ $self->{'search_todo'} } > 1;
      return if time() - $self->{'search_last_time'} < $self->{'search_every'} + 2;
      $self->{'search_last'} = shift( @{ $self->{'search_todo'} } );
      $self->{'search_todo'} = undef unless @{ $self->{'search_todo'} };
      if ( $self->{'adc'} ) { $self->cmd_adc( 'B', 'SCH', @{ $self->{'search_last'} } ); }
      else {
#$self->sendcmd( 'Search', $self->{'M'} eq 'P' ? 'Hub:' . $self->{'Nick'} : "$self->{'myip'}:$self->{'myport_udp'}", join '?', @{ $self->{'search_last'} } );
        $self->sendcmd(
          'Search',
          ( ( $self->{'myip'} && $self->{'myport_udp'} ) ? "$self->{'myip'}:$self->{'myport_udp'}" : 'Hub:' . $self->{'Nick'} ),
          join '?',
          @{ $self->{'search_last'} }
        );
      }
      $self->{'search_last_time'} = time();
    },
    'search_tth' => sub {
      my $self = shift if ref $_[0];
      $self->{'search_last_string'} = undef;
      if ( $self->{'adc'} ) { $self->cmd( 'search_buffer', { TO => $self->make_token(), TR => $_[0], } ); }    #toauto
      else                  { $self->cmd( 'search_buffer', 'F', 'T', '0', '9', 'TTH:' . $_[0] ); }
    },
    'search_string' => sub {
      my $self = shift if ref $_[0];
      my $string = $_[0];
      if ( $self->{'adc'} ) {
        #$self->cmd( 'search_buffer', { TO => 'auto', map AN => $_, split /\s+/, $string } );
        $self->cmd( 'search_buffer', ( map { 'AN' . $_ } split /\s+/, $string ), { TO => $self->make_token(), } );    #TOauto
      } else {
        $self->{'search_last_string'} = $string;
        $string =~ tr/ /$/;
        $self->cmd( 'search_buffer', 'F', 'T', '0', '1', $string );
      }
    },
    'search' => sub {
      my $self = shift if ref $_[0];
      return $self->cmd( 'search_tth', @_ ) if length $_[0] == 39 and $_[0] =~ /^[0-9A-Z]+$/;
      return $self->cmd( 'search_string', @_ ) if length $_[0];
    },
    'search_retry' => sub {
      my $self = shift if ref $_[0];
      unshift( @{ $self->{'search_todo'} }, $self->{'search_last'} ) if ref $self->{'search_last'} eq 'ARRAY';
      $self->{'search_last'} = undef;
    },
    'make_hub' => sub {
      my $self = shift if ref $_[0];
      $self->{'hub'} ||= $self->{'host'} . ( ( $self->{'port'} and $self->{'port'} != 411 ) ? ':' . $self->{'port'} : '' );
    },
    'nick_generate' => sub {
      my $self = shift if ref $_[0];
      $self->{'nick_base'} ||= $self->{'Nick'};
      $self->{'Nick'} = $self->{'nick_base'} . int( rand( $self->{'nick_random'} || 100 ) );
    },
    #
    #=================
    #ADC dev
    #
    'connect_aft' => sub {
      #print "RUNADC![$self->{'protocol'}:$self->{'adc'}]";
      my $self = shift if ref $_[0];
      #$self->log($self, 'connect_aft inited',"MT:$self->{'message_type'}", ' ');
      $self->cmd( $self->{'message_type'}, 'SUP' ) if $self->{'adc'};
    },
    'SUP' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->log($self, 'SUP inited',"MT:$self->{'message_type'}", "=== $dst");
      $self->{'SUPADS'} ||= [qw(BAS0 BASE TIGR UCM0 BLO0 BZIP )];    #PING ZLIG
      $self->{'SUPRMS'} ||= [qw()];
      $self->{'SUP'} ||= { ( map { $_ => 1 } @{ $self->{'SUPADS'} } ), ( map { $_ => 0 } @{ $self->{'SUPRMS'} } ) };
      #$self->{'SUPAD'} ||= { map { $_ => 1 } @{ $self->{'SUPADS'} } };
      $self->cmd_adc                                                 #sendcmd
        ( $dst, 'SUP', ( map { 'AD' . $_ } @{ $self->{'SUPADS'} } ), ( map { 'RM' . $_ } keys %{ $self->{'SUPRM'} } ), );
      #ADBAS0 ADBASE ADTIGR ADUCM0 ADBLO0
    },
    'INF' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->{'BINFS'} ||= [qw(ID PD I4 I6 U4 U6 SS SF VE US DS SL AS AM EM NI DE HN HR HO TO CT AW SU RF)];
      $self->{'INF'}{'NI'} ||= $self->{'Nick'} || 'perlAdcDev';
      #eval "use MIME::Base32 qw( RFC );  use Digest::Tiger;" or $self->log( 'err', 'cant use', $@ );
      eval "use MIME::Base32 qw( RFC ); 1;"        or $self->log( 'err', 'cant use', $@ );
      eval "use Net::DirectConnect::TigerHash; 1;" or $self->log( 'err', 'cant use', $@ );
      sub base32 ($) { MIME::Base32::encode( $_[0] ); }
      sub hash ($)   { base32( tiger( $_[0] ) ); }

      sub tiger ($) {
        local ($_) = @_;
        #use Mhash qw( mhash mhash_hex MHASH_TIGER);
        #eval "use MIME::Base32 qw( RFC ); use Digest::Tiger;" or $self->log('err', 'cant use', $@);
        #$_.=("\x00"x(1024 - length $_));        print ( 'hlen', length $_);
        #Digest::Tiger::hash($_);
        Net::DirectConnect::TigerHash::tthbin($_);
        #mhash(Mhash::MHASH_TIGER, $_);
      }
      #$self->log('tiger of NULL is', hash(''));#''=      LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ
      #
      $self->{'PID'} ||= MIME::Base32::decode $self->{'INF'}{'PD'} if $self->{'INF'}{'PD'};
      $self->{'CID'} ||= MIME::Base32::decode $self->{'INF'}{'ID'} if $self->{'INF'}{'ID'};
      $self->{'ID'}  ||= 'perl' . $self->{'myip'} . $self->{'INF'}{'NI'};
      $self->{'PID'} ||= tiger $self->{'ID'};
      $self->{'CID'} ||= tiger $self->{'PID'};
      $self->{'INF'}{'PD'} ||= base32 $self->{'PID'};
      $self->{'INF'}{'ID'} ||= base32 $self->{'CID'};
      $self->{'INF'}{'SL'} ||= $self->{'S'} || '2';
      $self->{'INF'}{'SS'} ||= $self->{'sharesize'} || 20025693588;
      $self->{'INF'}{'SF'} ||= 30999;
      $self->{'INF'}{'HN'} ||= $self->{'H'} || 1;
      $self->{'INF'}{'HR'} ||= $self->{'R'} || 0;
      $self->{'INF'}{'HO'} ||= $self->{'O'} || 0;
      $self->{'INF'}{'VE'} ||= $self->{'client'} . $self->{'V'}
        || 'perl' . $VERSION;    #. '_' . ( split( ' ', '$Revision$' ) )[1];    #'++\s0.706';
      $self->{'INF'}{'US'} ||= 10000;
      $self->{'INF'}{'U4'} ||= $self->{'myport_udp'};
      $self->{'INF'}{'I4'} ||= $self->{'myip'};
      $self->{'INF'}{'SU'} ||= 'ADC0,TCP4,UDP4';
     #$self->{''} ||= $self->{''} || '';
     #$self->sendcmd( $dst, 'INF', $self->{'sid'}, map { $_ . $self->{$_} } grep { length $self->{$_} } @{ $self->{'BINFS'} } );
      $self->cmd_adc             #sendcmd
        (
        $dst, 'INF',             #$self->{'sid'},
        map { $_ . $self->{'INF'}{$_} } $dst eq 'C' ? qw(ID TO) : sort keys %{ $self->{'INF'} }
        );
      #grep { length $self->{$_} } @{ $self->{'BINFS'} } );
      #$self->cmd_adc( $dst, 'INF', $self->{'sid'}, map { $_ . $self->{$_} } grep { $self->{$_} } @{ $self->{'BINFS'} } );
      #BINF UUXX IDFXC3WTTDXHP7PLCCGZ6ZKBHRVAKBQ4KUINROXXI PDP26YAWX3HUNSTEXXYRGOIAAM2ZPMLD44HCWQEDY NIпырыо SL2 SS20025693588
      #SF30999 HN2 HR0 HO0 VE++\s0.706 US5242 SUADC0
    },
    'GET' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->sendcmd( $dst, 'CTM', $self->{'connect_protocol'},@_);
      local @_ = @_;
      if ( !@_ ) {
        @_ = ( 'file', $self->{'filename'}, '0', '-1' ) if $self->{'filename'};
        $self->log( 'err', "Nothing to get" ), return unless @_;
      }
      $self->cmd_adc( $dst, 'GET', @_ );
    },
  };

=auto    
      'CTM' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->sendcmd( $dst, 'CTM', $self->{'connect_protocol'},@_);
      $self->cmd_adc( $dst, 'CTM', @_ );
    },
     'RCM' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->sendcmd( $dst, 'CTM', $self->{'connect_protocol'},@_);
      $self->cmd_adc( $dst, 'RCM', @_ );
    },
    'SND' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->sendcmd( $dst, 'CTM', $self->{'connect_protocol'},@_);
      $self->cmd_adc( $dst, 'SND', @_ );
    },
=cut    
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
    $self->log( 'dev', 'disconnect int' );
  };
}
1;
