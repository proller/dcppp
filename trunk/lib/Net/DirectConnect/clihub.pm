# $Id$ $URL$
package Net::DirectConnect::clihub;
use Time::HiRes qw(time sleep);
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
use Net::DirectConnect;
use Net::DirectConnect::clicli;
use Net::DirectConnect::http;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
#our @ISA = ('Net::DirectConnect');
use base 'Net::DirectConnect';
#todo! move to main module
#  my %clear = ('clients' => {},'socket' => '', 'select' => '','accept' => 0, 'filehandle'=>undef, 'parse'=>{},  'cmd'=>{}, );
sub init {
  my $self = shift;
  %$self = (
    %$self,
    'Nick' => 'NetDCBot',
    'port' => 411,
    'host' => 'localhost',
    #        'myport' => 6779 + int(rand(1000)),
    #	'Version'	=> '++ V:0.673,M:A,H:0/1/0,S:2',
    'Pass' => '',
    'key'  => 'zzz',
    #    'auto_wait'        => 1,
    #        %$self,
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
    'periodic'      => sub {
      $self->cmd( 'search_buffer', ) if $self->{'socket'};
    },
  );
  #print "2: $self->{'Nick'}\n";
  $self->baseinit();
  #print('dcdbg', "myip : $self->{'myip'}", "\n");
  #  %{
  $self->{'parse'}
    #}
    ||= {
    'chatline' => sub {
      #      my ( $nick, $text ) = $_[0] =~ /^[*<]([^>]+?)>? (.+)$/s;
      my ( $nick, $text ) = $_[0] =~ /^(?:<|\* )(.+?)>? (.+)$/s;
  #      my ( $nick, $text ) ;( $nick, $text ) = $_[0] =~ /^<([^>]+)> (.+)$/s or ( $nick, $text ) = $_[0] =~ /^\* (\S+) (.+)$/s;
  #      $self->log('dcdev', 'chatline parse', Dumper(\@_,$nick, $text));
  #v: chatline <[++T]шэюъ> You are already in the hub.
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
      #
      $self->search_retry(),
        if $self->{'NickList'}->{$nick}{'oper'} and $text eq 'Sorry Hub is busy now, no search, try later..';
    },    #print("welcome:", @_) unless $self->{'no_print_welcome'}; },
    'welcome' => sub {
      my ( $nick, $text ) = $_[0] =~ /^(?:<|\* )(.+?)>? (.+)$/s;
      #$nick, $text
      if ( ( !keys %{ $self->{'NickList'} } or !exists $self->{'NickList'}->{$nick} or $self->{'NickList'}->{$nick}{'oper'} )
        and $text =~ /^Bad nickname: unallowed characters, use these (\S+)/ )
      {
        my $try = $self->{'Nick'};
        $try =~ s/[^\Q$1\E]//g;
        $self->log( 'warn', "CHNICK $self->{'Nick'} -> $try" );
        $self->{'Nick'} = $try if length $try;
      }
    },    #print("welcome:", @_)
    'Lock' => sub {
      $self->log( "lockparse", @_ );
      $self->{'sendbuf'} = 1;
      $self->cmd('Supports');
      #        $_[0] =~ /EXTENDEDPROTOCOL::\S+::(CTRL\[[^\]]+)\]/ or $_[0] =~ /(\S+)/;
      $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
      print "lock[$1]\n";
      #my $k = $self->lock2key($1);
      #      $self->log( "key=", $k);
      #      $self->cmd( 'Key', $k );
      $self->cmd( 'Key', $self->lock2key($1) );
      #Net::DirectConnect::
      #	$self->cmd('Key', Net::DirectConnect::lock2key($_[0]));
      #!!!!!ALL $self->cmd
      $self->{'sendbuf'} = 0;
      $self->cmd('ValidateNick');
      #	$self->recv();
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
      #        $self->{'no_print_welcome'} = 1;
      #      	$self->wait();
      #$self->log('info', "HELLO end rec st:[$self->{'status'}]");
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
      #        print("Bad nick:[$_[0]]"), return unless length $nick;
      $self->{'NickList'}->{$nick}{'Nick'} = $nick;
      #        $self->{'NickList'}->{$nick}{'info'} = $info;
      #print "preinfo[$info] to $self->{'NickList'}->{$nick}\n";
      $self->info_parse( $info, $self->{'NickList'}{$nick} );
      $self->{'NickList'}->{$nick}{'online'} = 1;
      #        print  "info:$nick [$info]\n";
    },
    'UserIP' => sub {
      /(\S+)\s+(\S+)/, $self->{'NickList'}{$1}{'ip'} = $2, $self->{'IpList'}{$2} =
        #\%{
        $self->{'NickList'}{$1}
        #}
        , $self->{'IpList'}{$2}{'port'} = $self->{'PortList'}{$2} for grep $_, split /\$\$/, $_[0];
    },
    'HubName' => sub {
      $self->{'HubName'} = $_[0];
    },
    'HubTopic' => sub {
      $self->{'HubTopic'} = $_[0];
    },
    'NickList' => sub {
      $self->{'NickList'}->{$_}{'online'} = 1 for grep $_, split /\$\$/, $_[0];
      #        print 'nicklist:', join(';', sort keys %{$self->{'NickList'}}), "\n"
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
      #print "ALREADY CONNECTED",
      #         my $hp = $host .':'. $port;
      #         $self->{'NickList'}->{$nick}{'ip'} = $hp;
      #         $self->{'IpList'}->{$hp} = \%{ $self->{'NickList'}->{$nick} };
      $self->{'PortList'}->{$host} = $port;
      #$self->log('dev', "portlist: $host = $self->{'PortList'}->{$host} :=$port");
      return if $self->{'clients'}{ $host . ':' . $port }->{'socket'};
      $self->{'clients'}{ $host . ':' . $port } = Net::DirectConnect::clicli->new(
        %$self, $self->clear(),
        'host'     => $host,
        'port'     => $port,
        'want'     => \%{ $self->{'want'} },
        'NickList' => \%{ $self->{'NickList'} },
        'IpList'   => \%{ $self->{'IpList'} },
        'PortList' => \%{ $self->{'PortList'} },
        'handler'  => \%{ $self->{'handler'} },
#         $self->{'clients'}{$host .':'. $port} = Net::DirectConnect::clicli->new(%$self, $self->clear(), 'host' => $host,  'port' => $port,
#'clients' => {},
#'debug'=>1,
#    'auto_listen' => 0,
        'auto_connect' => 1,
      );
      #$self->log( 'cldmp',Dumper $self->{'clients'}{ $host . ':' . $port });
      #      $self->{'clients'}{ $host . ':' . $port }->cmd('connect_aft');
    },
    'RevConnectToMe' => sub {
      my ( $to, $from ) = split /\s+/, $_[0];
      $self->cmd( 'ConnectToMe', $to ) if $from eq $self->{'Nick'};
    },
    'GetPass' => sub {
      $self->cmd('MyPass');
    },
    'BadPass' => sub {
    },    # print("BadPassword\n");
    'LogedIn' => sub { },    # print("$_[0] is LogedIn\n");
    'Search' => sub {
      my $search = $_[0];
      $self->cmd('make_hub');
      my %s = (
        'time' => int( time() ),
        'hub'  => $self->{'hub'},
      );
      ( $s{'who'}, $s{'cmds'} ) = split /\s+/, $search;
      #my @cmd =
      $s{'cmd'} = [ split /\?/, $s{'cmds'} ];
      #my ($nick, $ip, $port);
      if ( $s{'who'} =~ /^Hub:(.+)$/ ) {
        $s{'nick'} = $1;
      } else {
        ( $s{'ip'}, $s{'port'} ) = split /:/, $s{'who'};
      }
      #my ($tth, string);
      #      if ( $s{'cmd'}[4] =~ /^TTH:(.*)$/ ) {
      if ( $s{'cmd'}[4] =~ /^TTH:([0-9A-Z]{39})$/ ) {
        #      if ( $s{'cmd'}[4] =~ /^TTH:\w{39}$/ ) {
        $s{'tth'} = $1;
        #       $s{'string'} = $s{'tth'}, $s{'tth'} = undef unless length $s{'tth'} == 39 and $s{'tth'} =~ /^[0-9A-Z]+$/;
      } else {
        $s{'string'} = $s{'cmd'}[4];
      }
      $s{'string'} =~ tr/$/ /;
      #$self->log('dcdev', 'separse',"[$s{'cmd'}[4]]",Dumper \%s);
      return \%s;
    },    #todo
    'SR' => sub {
      #=z
      $self->cmd('make_hub');
      my %s = (
        'time' => int( time() ),
        'hub'  => $self->{'hub'},
      );
      #$self->log($self,'dcdv','SR===',$_[0]);
      ( $s{'nick'}, $s{'str'} ) = split / /, $_[0], 2;
      $s{'str'} = [ split /\x05/, $s{'str'} ];
      $s{'file'} = shift @{ $s{'str'} };
      ( $s{'filename'} ) = $s{'file'}     =~ m{([^\\]+)$};
      ( $s{'ext'} )      = $s{'filename'} =~ m{[^.]+\.([^.]+)$};
      ( $s{'size'}, $s{'slots'} )  = split / /, shift @{ $s{'str'} };
      ( $s{'tth'},  $s{'ipport'} ) = split / /, shift @{ $s{'str'} };
      ( $s{'target'} ) = shift @{ $s{'str'} };
      $s{'tth'} =~ s/^TTH://;
      #print "ipport[$s{'ipport'}]\n";
      ( $s{'ipport'}, $s{'ip'}, $s{'port'} ) = $s{'ipport'} =~ /\(((\S+):(\d+))\)/;
      delete $s{'str'};
      ( $s{'slotsopen'}, $s{'S'} ) = split /\//, $s{'slots'};
      $s{'slotsfree'} = $s{'S'} - $s{'slotsopen'};
      $s{'string'}    = $self->{'search_last_string'};
      $self->{'NickList'}{ $s{'nick'} }{$_} = $s{$_} for qw(S ip port);
      $self->{'PortList'}->{ $s{'ip'} } = $s{'port'};
      $self->{'IpList'}->{ $s{'ip'} }   = $self->{'NickList'}{ $s{'nick'} };
      # 'TTH:SA3IRQKXK52A6QC4MCGNLC4HYIICFR2F5ARYEOY (80.240.208.42:4111)'
      #$self->log($self, 'dcdv', Dumper(\%s));
      #=cut
      return \%s;
    },
    #         $self->{'IpList'}->{$self->{'peerip'}} = \%{ $self->{'NickList'}->{$self->{'peernick'} } };
    #
    #      'UserIP' => sub { print"todo[UserIP]$_[0]\n"}, #todo
    #      'ConnectToMe' => sub { print"todo[ConnectToMe]$_[0]\n"}, #todo
    'UserCommand' => sub { },                          # useless
                                                       #
                                                       #
                                                       #
                                                       #
                                                       # ADC dev
    'ISUP'        => sub { },
    'ISID'        => sub { $self->{'sid'} = $_[0] },
    'IINF'        => sub { $self->cmd('BINF') },
    #todo
    'IQUI' => sub { },
    'ISTA' => sub { $self->log( 'dcerr', @_ ) },
    };
  #  %{
  $self->{'cmd'}
    #}
    = {
    'chatline' => sub {
      for (@_) {
        #  	  sleep($self->{'min_chat_delay'}) if $self->{'min_chat_delay'};
        #          if ($self->{'min_chat_delay'}) {
        #        return unless $self->{'socket'};
        if ( $self->{'min_chat_delay'} and ( time - $self->{'last_chat_time'} < $self->{'min_chat_delay'} ) ) {
          $self->log( 'dbg', 'sleep', $self->{'min_chat_delay'} - time + $self->{'last_chat_time'} );
          $self->wait_sleep( $self->{'min_chat_delay'} - time + $self->{'last_chat_time'} );
        }
        $self->{'last_chat_time'} = time;
        #	  }
        $self->log(
          'dcdmp',
          "($self->{'number'}) we send [",
          "<$self->{'Nick'}> $_|",
          "]:", $self->{'socket'}->send("<$self->{'Nick'}> $_|"), $!
        );
        #$self->log('dbg', 'sleep', $self->{'min_chat_delay'}),
      }
    },
    #$To: <othernick> From: <nick> $<<nick>> <message>|
    'To' => sub {
      my $to = shift;
      #	$self->sendcmd('To:', "$to From: $self->{'Nick'} \$<$self->{'Nick'}> $_|") for(@_);
      $self->sendcmd( 'To:', $to, "From: $self->{'Nick'} \$<$self->{'Nick'}> $_" ) for (@_);
      #	$self->sendcmd('To :', "$to From: $self->{'Nick'} \$<$self->{'Nick'}> $_") for(@_);
      #	$self->{'socket'}->send('To :', "$to From: $self->{'Nick'} \$<$self->{'Nick'}> $_|") for(@_);
    },
    'Key' => sub {
      my $self = shift if ref $_[0];
      $self->log( 'dev', "sendkey", $_[0] );
      $self->sendcmd( 'Key', $_[0] );
    },
    'ValidateNick' => sub {
      $self->sendcmd( 'ValidateNick', $self->{'Nick'} );
    },
    'Version' => sub {
      $self->sendcmd( 'Version', $self->{'Version'} );
    },
    #      'Version'	=> sub { $self->sendcmd('Version', $self->tag()); },
    'MyINFO' => sub { $self->sendcmd( 'MyINFO', '$ALL', $self->myinfo() ); },
#      'MyINFO'	=> sub { $self->sendcmd('MyINFO', '$ALL', $self->{'Nick'}, $self->{'MyINFO'}); },
#      'MyINFO'	=> sub { $self->sendcmd('MyINFO', '$ALL', $self->{'Nick'}, $self->{'description'} . '$ $' . $self->{'connection'} . chr($self->{'flag'}) . '$' . $self->{'email'} . '$' . $self->{'sharesize'} . '$'); },
    'GetNickList' => sub { $self->sendcmd('GetNickList'); },
    'GetINFO'     => sub {
      my $self = shift if ref $_[0];
      #$self->sendcmd( 'GetINFO', $_[0], $self->{'Nick'} ), return if scalar @_ == 1;
      @_ = grep { $self->{'NickList'}{$_}{'online'} and !$self->{'NickList'}{$_}{'info'} } keys %{ $self->{'NickList'} }
        unless @_;
      local $self->{'sendbuf'} = 1;
      $self->sendcmd( 'GetINFO', $_, $self->{'Nick'} ) for @_;
      #$dc->{'sendbuf'} = 0;
      $self->sendcmd();
    },
    'ConnectToMe' => sub {
      my $self = shift if ref $_[0];
      #print "ctm [$self->{'M'}][$self->{'allow_passive_ConnectToMe'}]\n";
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
      #$self->log('dcdev', 'Search', @_);
      $self->sendcmd( 'Search', ( $self->{'M'} eq 'P' ? "Hub:$self->{'Nick'}" : "$self->{'myip'}:$self->{'myport_udp'}" ),
        join '?', @_ );
    },
    'search_buffer' => sub {
      my $self = shift if ref $_[0];
      #      $self->log('dcdev', 'Search_buffer', @_);
      #return;
      push( @{ $self->{'search_todo'} }, [@_] ) if @_;
      return unless @{ $self->{'search_todo'} || return };
#      $self->log( 'dcdev', "search too fast [$self->{'search_every'}], len=", scalar @{ $self->{'search_todo'} } )        if @_ and scalar @{ $self->{'search_todo'} } > 1;
      return if time() - $self->{'search_last_time'} < $self->{'search_every'} + 2;
      #      my $s = shift( @{ $self->{'search_todo'} } );
      $self->{'search_last'} = shift( @{ $self->{'search_todo'} } );
      $self->{'search_todo'} = undef unless @{ $self->{'search_todo'} };
      #      $self->{'search_last'} = [@$s];
      #      $self->{'search_last'} = $s;
      $self->sendcmd(
        'Search', $self->{'M'} eq 'P' ? 'Hub:' . $self->{'Nick'} : "$self->{'myip'}:$self->{'myport'}",
        join '?',
        #@$s
        @{ $self->{'search_last'} }
      );
      $self->{'search_last_time'} = time();
    },
    'search_tth' => sub {
      my $self = shift if ref $_[0];
      #      $self->Search(  'F', 'T', '0', '9', 'TTH:'.$_[0]);
      $self->{'search_last_string'} = undef;
      $self->cmd( 'search_buffer', 'F', 'T', '0', '9', 'TTH:' . $_[0] );
    },
    'search_string' => sub {
      my $self = shift if ref $_[0];
      my $string = $_[0];
      $self->{'search_last_string'} = $string;
      $string =~ tr/ /$/;
      #      $self->Search(  'F', 'T', '0', '1', @_);
      $self->cmd( 'search_buffer', 'F', 'T', '0', '1', $string );
    },
    'search' => sub {
      my $self = shift if ref $_[0];
      return $self->cmd( 'search_tth', @_ ) if length $_[0] == 39 and $_[0] =~ /^[0-9A-Z]+$/;
      return $self->cmd( 'search_string', @_ ) if length $_[0];
    },
    'search_retry' => sub {
      my $self = shift if ref $_[0];
      #      $self->cmd( 'search_buffer', @{$self->{'search_last'}})
      #unshift( @{ $self->{'search_todo'} }, [@{$self->{'search_last'}}] )
      unshift( @{ $self->{'search_todo'} }, $self->{'search_last'} )
        if ref $self->{'search_last'} eq 'ARRAY';
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
    #
    #
    # ADC dev
    'connect_aft' => sub { $self->cmd('HSUP') if $self->{'protocol'} eq 'adc' },
    'HSUP' => sub {
      $self->{'SUPADS'} ||= [qw(BAS0 BASE TIGR UCM0 BLO0)];
      $self->{'SUPAD'} ||= { map { $_ => 1 } @{ $self->{'SUPADS'} } };
      $self->sendcmd( 'HSUP', ( map { 'AD' . $_ } @{ $self->{'SUPADS'} } ), ( map { 'RM' . $_ } keys %{ $self->{'SUPRM'} } ), );
      #ADBAS0 ADBASE ADTIGR ADUCM0 ADBLO0
    },
    'BINF' => sub {
      $self->{'BINFS'} ||= [qw(ID PD NI SL SS SF HN HR HO VE US SU)];
      #$self->{'ID'} ||= 'FXC3WTTDXHP7PLCCGZ6ZKBHRVAKBQ4KUINROXXI';
      #$self->{'PD'} ||='P26YAWX3HUNSTEXXYRGOIAAM2ZPMLD44HCWQEDY';
      $self->{'NI'} ||= $self->{'Nick'} || 'perlAdcDev';
      # hash() returns a 192 bit hash
      #$self->log('TIGERTE',  Digest::Tiger::hash('Tiger'));
      #$self->log('TIGERTEST',  MIME::Base32::encode(Digest::Tiger::hash('Tiger')));
      sub hash {
        local ($_) = @_;
        eval "use MIME::Base32 qw( RFC ); use Digest::Tiger;";
        #$_.=("\x00"x(1024 - length $_));print ( 'hlen', length $_);
        MIME::Base32::encode( Digest::Tiger::hash($_) );
      }
      #$self->log('TIGERTEST',  hash('Tiger'));
      #$self->log('TIGERTESTid',  hash('FXC3WTTDXHP7PLCCGZ6ZKBHRVAKBQ4KUINROXXI'));
      #$self->log('TIGERTESTpd', hash('P26YAWX3HUNSTEXXYRGOIAAM2ZPMLD44HCWQEDY'));
      $self->{'PD'} ||= hash( 'perl' . $self->{'myip'} . $self->{'NI'} . time );
      $self->{'ID'} ||= hash( $self->{'PD'} );
      $self->{'SL'} ||= $self->{'S'} || '2';
      $self->{'SS'} ||= $self->{'sharesize'} || 20025693588;
      $self->{'SF'} ||= 30999;
      $self->{'HN'} ||= $self->{'H'} || 1;
      $self->{'HR'} ||= $self->{'R'} || 0;
      $self->{'HO'} ||= $self->{'O'} || 0;
      $self->{'VE'} ||= $self->{'V'} || '++\s0.706';
      $self->{'US'} ||= 10000;
      $self->{'SU'} ||= 'ADC0';
      #$self->{''} ||= $self->{''} || '';
      $self->sendcmd( 'BINF', $self->{'sid'}, map { $_ . $self->{$_} } grep { $self->{$_} } @{ $self->{'BINFS'} } );
      #BINF UUXX IDFXC3WTTDXHP7PLCCGZ6ZKBHRVAKBQ4KUINROXXI PDP26YAWX3HUNSTEXXYRGOIAAM2ZPMLD44HCWQEDY NIпырыо SL2 SS20025693588
      #SF30999 HN2 HR0 HO0 VE++\s0.706 US5242 SUADC0
      }
    };
#print "[$self->{'number'}]BEF";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";
#print "[$self->{'number'}]CLR";print "[$_ = $clear{$_}]"for sort keys %clear;print "\n";
#    $self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, %clear, 'socket' => $_, 'LocalPort'=>$self->{'myport'}, 'want' => \%{$self->{'want'}},
#print "Listen on port $self->{'myport'} \n";
  if ( $self->{'M'} eq 'A' ) {
  $self->log( 'dev', "making listeners: tcp" );
    $self->{'clients'}{'listener_tcp'} = $self->{'incomingclass'}->new(
      %$self, $self->clear(),
      'want'     => \%{ $self->{'want'} },
      'NickList' => \%{ $self->{'NickList'} },
      'IpList'   => \%{ $self->{'IpList'} },
      'PortList' => \%{ $self->{'PortList'} },
      'handler'  => \%{ $self->{'handler'} },
      #    $self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, $self->clear(),
      #'LocalPort'=>$self->{'myport'},
      #'debug'=>1,
      'auto_listen' => 1,
    );
    $self->{'myport'} = $self->{'myport_tcp'} = $self->{'clients'}{'listener_tcp'}{'myport'};
    $self->log( 'err', "cant listen tcp (file transfers)" )
      unless $self->{'myport_tcp'};
    $self->log( 'dev', "making listeners: udp" );
    $self->{'clients'}{'listener_udp'} = $self->{'incomingclass'}->new(
      %$self, $self->clear(),
      'Proto' => 'udp',
      #?    'want'     => \%{ $self->{'want'} },
      #?    'NickList' => \%{ $self->{'NickList'} },
      #?    'IpList'   => \%{ $self->{'IpList'} },
      #?    'PortList' => \%{ $self->{'PortList'} },
      'handler' => \%{ $self->{'handler'} },
      #    $self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, $self->clear(),
      #'LocalPort'=>$self->{'myport'},
      #'debug'=>1,
      #'nonblocking' => 0,
      'parse' => {
        'SR'   => $self->{'parse'}{'SR'},
        'UPSR' => sub {
          #    $self->log( 'dev', "UPSR", @_ );
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
    $self->log( 'err', "cant listen udp (search repiles)" )
      unless $self->{'myport_udp'};
  }

=z
  $self->log( 'dev', "making listeners: http" );
    $self->{'clients'}{'listener_http'} = Net::DirectConnect::http->new(
      %$self, $self->clear(),
#      'want'     => \%{ $self->{'want'} },
#      'NickList' => \%{ $self->{'NickList'} },
#      'IpList'   => \%{ $self->{'IpList'} },
##      'PortList' => \%{ $self->{'PortList'} },
      'handler'  => \%{ $self->{'handler'} },
      #    $self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, $self->clear(),
      #'LocalPort'=>$self->{'myport'},
      #'debug'=>1,
      'auto_listen' => 1,
    );
    $self->{'myport_http'}  = $self->{'clients'}{'listener_http'}{'myport'};
    $self->log( 'err', "cant listen http" )
      unless $self->{'myport_http'};
=cut


  #
#  $self->log('dev', "listeners created"),
  #  $self->{'clients'}{'listener'}->listen();
  #print "[$self->{'number'}]AFT";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";
}
1;
