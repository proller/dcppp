#$Id$ $URL$
package Net::DirectConnect::clihub;
use Time::HiRes qw(time sleep);
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
use Net::DirectConnect;
use Net::DirectConnect::clicli;
#use Net::DirectConnect::http;
use strict;
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
    'NoGetINFO'        => 1,          #test
    'NoHello'          => 1,
    'UserIP2'          => 1,
    'Version'          => '1,0091',
    'auto_GetNickList' => 1,
    'follow_forcemove' => 1,
    @_,
    'incomingclass' => 'Net::DirectConnect::clicli',
    'periodic'      => sub { $self->cmd( 'search_buffer', ) if $self->{'socket'}; },
    'codesSTA'      => {
      '00' => 'Generic, show description',
      'x0' => 'Same as 00, but categorized according to the rough structure set below',
      '10' => 'Generic hub error',
      '11' => 'Hub full',
      '12' => 'Hub disabled',
      '20' => 'Generic login/access error',
      '21' => 'Nick invalid',
      '22' => 'Nick taken',
      '23' => 'Invalid password',
      '24' => 'CID taken',
      '25' =>
'Access denied, flag "FC" is the FOURCC of the offending command. Sent when a user is not allowed to execute a particular command',
      '26' => 'Registered users only',
      '27' => 'Invalid PID supplied',
      '30' => 'Kicks/bans/disconnects generic',
      '31' => 'Permanently banned',
      '32' =>
'Temporarily banned, flag "TL" is an integer specifying the number of seconds left until it expires (This is used for kick as well…).',
      '40' => 'Protocol error',
      '41' =>
qq{Transfer protocol unsupported, flag "TO" the token, flag "PR" the protocol string. The client receiving a CTM or RCM should send this if it doesn't support the C-C protocol. },
      '42' =>
qq{Direct connection failed, flag "TO" the token, flag "PR" the protocol string. The client receiving a CTM or RCM should send this if it tried but couldn't connect. },
      '43' => 'Required INF field missing/bad, flag "FM" specifies missing field, "FB" specifies invalid field.',
      '44' => 'Invalid state, flag "FC" the FOURCC of the offending command.',
      '45' => 'Required feature missing, flag "FC" specifies the FOURCC of the missing feature.',
      '46' => 'Invalid IP supplied in INF, flag "I4" or "I6" specifies the correct IP.',
      '47' => 'No hash support overlap in SUP between client and hub.',
      '50' => 'Client-client / file transfer error',
      '51' => 'File not available',
      '52' => 'File part not available',
      '53' => 'Slots full',
      '54' => 'No hash support overlap in SUP between clients.',
    },
    'connect_protocol' => 'ADCS/0.10',
  );
  $self->baseinit();
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
      $self->log( "lockparse", @_ );
      $self->{'sendbuf'} = 1;
      $self->cmd('Supports');
      $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
      print "lock[$1]\n";
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
        'host'         => $host,
        'port'         => $port,
        'want'         => \%{ $self->{'want'} },
        'NickList'     => \%{ $self->{'NickList'} },
        'IpList'       => \%{ $self->{'IpList'} },
        'PortList'     => \%{ $self->{'PortList'} },
        'handler'      => \%{ $self->{'handler'} },
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
      my ( $dst, $peerid ) = @{ shift() };
      #for my $feature (split /\s+/, $_[0])
      $self->log( 'adcdev', 'SUP:', @_ );

=z
      for (@_) {
        if ( (s/^(AD|RM)//)[0] eq 'RM' ) {
          delete $self->{'peers'}{$peerid}{'SUP'}{$_};
        } else {
          $self->{'peers'}{$peerid}levf{'SUP'}{$_} = 1;
        }
      }
=cut      

      my $params = adc_parse_named(@_);
      for ( keys %$params ) {
        delete $self->{'peers'}{$peerid}{'SUP'}{ $params->{$_} } if $_ eq 'RM';
        $self->{'peers'}{$peerid}{'SUP'}{ $params->{$_} } = 1 if $_ eq 'AD';
      }
      return $self->{'peers'}{$peerid}{'SUP'};
    },
    'SID' => sub {
      $self->{'sid'} = $_[1];
      $self->log( 'adcdev', 'SID:', $self->{'sid'} );
      return $self->{'sid'};
    },
    'INF' => sub {
      my ( $dst, $peerid ) = @{ shift() };
      #test $_[1] eq 'I'!
      #$self->log('adcdev', '0INF:', "[d=$dst,p=$peerid]", join ':', @_);
      my $params = adc_parse_named(@_);
      #for (@_) {
      #s/^(\w\w)//;
      #my ($code)= $1;
      #$self->log('adcdev', 'INF:', $peerid, "[$code=$_]");
      #$self->{'peers'}{$peerid}{'INF'}{$code} = $_;
      #}
      $self->{'peers'}{$peerid}{'INF'}{$_} = $params->{$_} for keys %$params;
      $self->cmd( 'B', 'INF' ), $self->{'status'} = 'connected' if $dst eq 'I';
      return $self->{'peers'}{$peerid}{'INF'};
    },
    'QUI' => sub {
      my ($dst) = @{ shift() };
      #$peerid
      $self->log( 'adcdev', 'QUI', $dst, $_[0], Dumper $self->{'peers'}{ $_[0] } );
      delete $self->{'peers'}{ $_[0] };    # or mark time
    },
    'STA' => sub {
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
      adc_strings_decode(@_);
      $self->log( 'adcdev', 'STA', $severity, $code, @_, "[$self->{'codesSTA'}{$code}]" );
      return $severity, $code, $self->{'codesSTA'}{$code}, @_;
    },
    'SCH' => sub {
      my ( $dst, $peerid ) = @{ shift() };
      my $params = adc_parse_named(@_);
      return $params;
#TRKU2OUBVHC3VXUNOHO2BS2G4ECHYB6ESJUQPYFSY TO626120869 ]
#TRQYKHJIZEPSISFF3T25DIGKEYI645Y7PGMSI7QII TOauto ]
#ANthe ANhossboss TO3951841973 ]
#FSCH ABWN +TCP4 TRKX55JDOFEBX32GLBSITTSY6KUCK4NMPU2R4XUII TOauto
      
      
    },
    'MSG' => sub {
      my ( $dst, $peerid ) = @{ shift() };
      #@_ = map {adc_string_decode} @_;
      adc_strings_decode(@_);
      $self->log( 'adcdev', 'MSG', "<" . $self->{'peers'}{$peerid}{'INF'}{'NI'} . '>', @_ );
      @_;
    },
     'RCM' => sub {
      my ( $dst, $peerid, $toid ) = @{ shift() };
      $self->log( 'dcerr', "( $dst, $peerid, $toid )", @_ );
      $self->cmd($dst, 'CTM',  $self->{'sid'},$peerid,
      $_[0],
$self->{'myport'},
      $_[1],     ) if $toid eq $self->{'sid'} ;
=z      
       $self->{'clients'}{ $host . ':' . $port } = Net::DirectConnect::clicli->new(
        %$self, $self->clear(),
        'host'         => $host,
        'port'         => $port,
#        'want'         => \%{ $self->{'want'} },
 #       'NickList'     => \%{ $self->{'NickList'} },
  #      'IpList'       => \%{ $self->{'IpList'} },
   #     'PortList'     => \%{ $self->{'PortList'} },
    #    'handler'      => \%{ $self->{'handler'} },
        'auto_connect' => 1,
      );
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
      my $to = shift;
      $self->sendcmd( 'To:', $to, "From: $self->{'Nick'} \$<$self->{'Nick'}> $_" ) for (@_);
    },
    'Key' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'Key', $_[0] );
    },
    'ValidateNick' => sub {
      $self->sendcmd( 'ValidateNick', $self->{'Nick'} );
    },
    'Version' => sub {
      $self->sendcmd( 'Version', $self->{'Version'} );
    },
    'MyINFO' => sub {
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
      $self->sendcmd( 'Quit', $self->{'Nick'} );
      $self->disconnect();
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
#$self->log( 'dcdev', "search too fast [$self->{'search_every'}], len=", scalar @{ $self->{'search_todo'} } )        if @_ and scalar @{ $self->{'search_todo'} } > 1;
      return if time() - $self->{'search_last_time'} < $self->{'search_every'} + 2;
      $self->{'search_last'} = shift( @{ $self->{'search_todo'} } );
      $self->{'search_todo'} = undef unless @{ $self->{'search_todo'} };
      $self->sendcmd( 'Search', $self->{'M'} eq 'P' ? 'Hub:' . $self->{'Nick'} : "$self->{'myip'}:$self->{'myport'}",
        join '?', @{ $self->{'search_last'} } );
      $self->{'search_last_time'} = time();
    },
    'search_tth' => sub {
      my $self = shift if ref $_[0];
      $self->{'search_last_string'} = undef;
      $self->cmd( 'search_buffer', 'F', 'T', '0', '9', 'TTH:' . $_[0] );
    },
    'search_string' => sub {
      my $self = shift if ref $_[0];
      my $string = $_[0];
      $self->{'search_last_string'} = $string;
      $string =~ tr/ /$/;
      $self->cmd( 'search_buffer', 'F', 'T', '0', '1', $string );
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
      $self->{'hub'} ||= $self->{'host'} . ( ( $self->{'port'} and $self->{'port'} != 411 ) ? ':' . $self->{'port'} : '' );
    },
    'nick_generate' => sub {
      $self->{'nick_base'} ||= $self->{'Nick'};
      $self->{'Nick'} = $self->{'nick_base'} . int( rand( $self->{'nick_random'} || 100 ) );
    },
    #
    #=================
    #ADC dev
    #
    'connect_aft' => sub {
      #print "RUNADC![$self->{'protocol'}:$self->{'adc'}]";
      $self->cmd( 'H', 'SUP' ) if $self->{'adc'};
    },
    'SUP' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      $self->{'SUPADS'} ||= [qw(BAS0 BASE TIGR UCM0 BLO0)];
      $self->{'SUPAD'} ||= { map { $_ => 1 } @{ $self->{'SUPADS'} } };
      $self->sendcmd(
        $dst, 'SUP',
        ( map { 'AD' . $_ } @{ $self->{'SUPADS'} } ),
        ( map { 'RM' . $_ } keys %{ $self->{'SUPRM'} } ),
      );
      #ADBAS0 ADBASE ADTIGR ADUCM0 ADBLO0
    },
    'INF' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      $self->{'BINFS'} ||= [qw(ID PD I4 I6 U4 U6 SS SF VE US DS SL AS AM EM NI DE HN HR HO TO CT AW SU RF)];
      $self->{'NI'} ||= $self->{'Nick'} || 'perlAdcDev';
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
      $self->{'PID'} ||= MIME::Base32::decode $self->{'PD'} if $self->{'PD'};
      $self->{'CID'} ||= MIME::Base32::decode $self->{'ID'} if $self->{'ID'};
      $self->{'PID'} ||= tiger 'perl' . $self->{'myip'} . $self->{'NI'};
      $self->{'CID'} ||= tiger $self->{'PID'};
      $self->{'PD'}  ||= base32 $self->{'PID'};
      $self->{'ID'}  ||= base32 $self->{'CID'};
      $self->{'SL'} ||= $self->{'S'}         || '2';
      $self->{'SS'} ||= $self->{'sharesize'} || 20025693588;
      $self->{'SF'} ||= 30999;
      $self->{'HN'} ||= $self->{'H'}         || 1;
      $self->{'HR'} ||= $self->{'R'}         || 0;
      $self->{'HO'} ||= $self->{'O'}         || 0;
      $self->{'VE'} ||= $self->{'client'} . $self->{'V'}
        || 'perl' . $VERSION . '_' . ( split( ' ', '$Revision$' ) )[1];    #'++\s0.706';
      $self->{'US'} ||= 10000;
      $self->{'U4'} ||=$self->{'myport'};
      $self->{'I4'} ||= $self->{'myip'};
      $self->{'SU'} ||= 'ADC0,TCP4,UDP4';
      #$self->{''} ||= $self->{''} || '';
     $self->sendcmd( $dst, 'INF', $self->{'sid'}, map { $_ . $self->{$_} } grep { length $self->{$_} } @{ $self->{'BINFS'} } );
  #    $self->cmd_adc( $dst, 'INF', $self->{'sid'}, map { $_ . $self->{$_} } grep { $self->{$_} } @{ $self->{'BINFS'} } );
      #BINF UUXX IDFXC3WTTDXHP7PLCCGZ6ZKBHRVAKBQ4KUINROXXI PDP26YAWX3HUNSTEXXYRGOIAAM2ZPMLD44HCWQEDY NIпырыо SL2 SS20025693588
      #SF30999 HN2 HR0 HO0 VE++\s0.706 US5242 SUADC0
      }, 
      
       'CTM' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      
      #$self->sendcmd( $dst, 'CTM', $self->{'connect_protocol'},@_);
      $self->cmd_adc( $dst, 'CTM', @_);
      },
  };
  if ( $self->{'M'} eq 'A' ) {
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

}
1;
