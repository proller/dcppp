#Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proler@gmail.com icq#89088275
my $Id = '$Id$';

package dcppp::clihub;
#use lib '../../..';
#use lib '../..';
#use lib '..';
#  use Time::HiRes;
eval { use Time::HiRes qw(time sleep); };
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
use dcppp;
use dcppp::clicli;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
#our @ISA = ('dcppp');
use base 'dcppp';
#todo! move to main module
#  my %clear = ('clients' => {},'socket' => '', 'select' => '','accept' => 0, 'filehandle'=>undef, 'parse'=>{},  'cmd'=>{}, );
sub init {
  my $self = shift;
  %$self = (
    %$self,
    'Nick' => 'dcpppBot',
    'port' => 411,
    'host' => 'localhost',
    #        'myport' => 6779 + int(rand(1000)),
    #	'Version'	=> '++ V:0.673,M:A,H:0/1/0,S:2',
    'Pass' => '', 'Key' => 'zzz',
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
    'search_every' => 10,
    'auto_connect'      => 1,


    'NoGetINFO'         => 1, #test
    'NoHello'           => 1,
    'UserIP2'           => 1,
    'Version'              => '1,0091',

    'auto_GetNickList'  => 1,
    'follow_forcemove' => 1,



    @_,
    'incomingclass' => 'dcppp::clicli',
    'periodic'      => sub {
      $self->cmd( 'search_buffer', )if $self->{'socket'};
    },
  );
  #print "2: $self->{'Nick'}\n";
  $self->baseinit();
  #print('dcdbg', "myip : $self->{'myip'}", "\n");
  #  %{
$self->{'make_hub'} ||= sub {
    $self->{'hub'} ||= $self->{'host'} . ( $self->{'port'} and $self->{'port'} != 411 ? $self->{'port'} : '' );
};

  $self->{'parse'}
    #}
    ||= {
    'chatline' => sub {
      #$self->log('dcdev', 'chatline parse', Dumper(@_));
      my ( $nick, $text ) = $_[0] =~ /^<([^>]+)> (.+)$/;
      $self->log( 'warn', "[$nick] oper, set interval = $1" ), $self->{'search_every'} = $1,
        if ( $self->{'NickList'}->{$nick}{'oper'} and $text =~ /^Minimum search interval is:(\d+)s/ )
        or $nick eq 'Hub-Security'
        and $text =~ /Search ignored\.  Please leave at least (\d+) seconds between search attempts\./;
      $self->search_retry();
    },    #print("welcome:", @_) unless $self->{'no_print_welcome'}; },
    'welcome' => sub { },    #print("welcome:", @_)
    'Lock' => sub {
      #print "lockparse[$_[0]]\n";
      $self->{'sendbuf'} = 1;
      $self->cmd('Supports');
      #        $_[0] =~ /EXTENDEDPROTOCOL::\S+::(CTRL\[[^\]]+)\]/ or $_[0] =~ /(\S+)/;
      $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
      #print "lock[$1]\n";
      $self->cmd( 'Key', dcppp::lock2key($1) );
      #	$self->cmd('Key', dcppp::lock2key($_[0]));
      #!!!!!ALL $self->cmd
      $self->{'sendbuf'} = 0;
      $self->cmd('ValidateNick');
      #	$self->recv();
    },
    'Hello' => sub {
      return unless $_[0] eq $self->{'Nick'};
      #$self->{'log'}->('info', "HELLO recieved, connected.");
      $self->{'sendbuf'} = 1;
      $self->cmd('Version');
      $self->{'sendbuf'} = 0 unless $self->{'auto_GetNickList'};
      $self->cmd('MyINFO');
      $self->{'sendbuf'} = 0, $self->cmd('GetNickList') if $self->{'auto_GetNickList'};
      $self->{'status'} = 'connected';
      #        $self->{'no_print_welcome'} = 1;
      #      	$self->wait();
      #$self->{'log'}->('info', "HELLO end rec st:[$self->{'status'}]");
    },
    'Supports' => sub {
      $self->supports_parse( $_[0], $self );
    },
    'ValidateDenide' => sub {
      $self->{'nick_base'} ||= $self->{'Nick'};
      $self->{'Nick'} = $self->{'nick_base'} . int( rand( $self->{'nick_random'} || 100 ) );
      $self->cmd('ValidateNick');
    },
    'To' => sub {
      $self->{'log'}->( 'msg', "Private message to", @_ );
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
      $self->{'log'}->( 'info', "ForceMove to $_[0]" );
      $self->disconnect();
      $self->connect(@_) if $self->{'follow_forcemove'};
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
      #$self->{'log'}->('dev', "portlist: $host = $self->{'PortList'}->{$host} :=$port");
      return if $self->{'clients'}{ $host . ':' . $port }->{'socket'};
      $self->{'clients'}{ $host . ':' . $port } = dcppp::clicli->new(
        %$self, $self->clear(),
        'host'     => $host,
        'port'     => $port,
        'want'     => \%{ $self->{'want'} },
        'NickList' => \%{ $self->{'NickList'} },
        'IpList'   => \%{ $self->{'IpList'} },
        'PortList' => \%{ $self->{'PortList'} },
        'handler'  => \%{ $self->{'handler'} },
 #         $self->{'clients'}{$host .':'. $port} = dcppp::clicli->new(%$self, $self->clear(), 'host' => $host,  'port' => $port,
 #'clients' => {},
 #'debug'=>1,
 #    'auto_listen' => 0,
      );
#$self->log( 'cldmp',Dumper $self->{'clients'}{ $host . ':' . $port });
      $self->{'clients'}{ $host . ':' . $port }->cmd('connect');
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

$self->{'make_hub'}->();

      my %s      = (
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
      if ( $s{'cmd'}[4] =~ /^TTH:(.*)$/ ) {
        $s{'tth'} = $1;
      } else {
        $s{'string'} = $s{'cmd'}[4];
        $s{'string'} =~ tr/$/ /;
      }
      return \%s;
    },    #todo
    'SR' => sub {
      #=z
$self->{'make_hub'}->();

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
    'UserCommand' => sub { },    # useless
    };
  #  %{
  $self->{'cmd'}
    #}
    = {
    'chatline' => sub {
      for (@_) {
        #  	  sleep($self->{'min_chat_delay'}) if $self->{'min_chat_delay'};
        #          if ($self->{'min_chat_delay'}) {
        return unless $self->{'socket'};
        if ( $self->{'min_chat_delay'} and ( time - $self->{'last_chat_time'} < $self->{'min_chat_delay'} ) ) {
          $self->{'log'}->( 'dbg', 'sleep', $self->{'min_chat_delay'} - time + $self->{'last_chat_time'} );
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
        #$self->{'log'}->('dbg', 'sleep', $self->{'min_chat_delay'}),
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
    'GetINFO'     => sub { $self->sendcmd( 'GetINFO', $_[0], $self->{'Nick'} ); },
    'ConnectToMe' => sub {
      #print "ctm [$self->{'M'}][$self->{'allow_passive_ConnectToMe'}]\n";
      return if $self->{'M'} eq 'P' and !$self->{'allow_passive_ConnectToMe'};
      $self->{'log'}->( 'err', "please define myip" ), return unless $self->{'myip'};
      $self->sendcmd( 'ConnectToMe', $_[0], "$self->{'myip'}:$self->{'myport'}" );
    },
    'RevConnectToMe' => sub {
      $self->sendcmd( 'RevConnectToMe', $self->{'Nick'}, $_[0] );
    },
    'MyPass' => sub {
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
      #$self->log('dcdev', 'Search', @_);
      $self->sendcmd( 'Search', ($self->{'M'} eq 'P' ? "Hub:$self->{'Nick'}" : "$self->{'myip'}:$self->{'myport_udp'}"),
        join '?', @_ );
    },
    'search_buffer' => sub {
      #      $self->log('dcdev', 'Search_buffer', @_);
      #return;
      push( @{ $self->{'search_todo'} }, [@_] ) if @_;
      return unless @{ $self->{'search_todo'} || return };
#      $self->log( 'dcdev', "search too fast [$self->{'search_every'}], len=", scalar @{ $self->{'search_todo'} } )        if @_ and scalar @{ $self->{'search_todo'} } > 1;
      return if time() - $self->{'search_last_time'} < $self->{'search_every'} + 1;
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
      #      $self->Search(  'F', 'T', '0', '9', 'TTH:'.$_[0]);
      $self->{'search_last_string'} = undef;
      $self->cmd( 'search_buffer', 'F', 'T', '0', '9', 'TTH:' . $_[0] );
    },
    'search_string' => sub {
      my $string = $_[0];
      $self->{'search_last_string'} = $string;
      $string =~ tr/ /$/;
      #      $self->Search(  'F', 'T', '0', '1', @_);
      $self->cmd( 'search_buffer', 'F', 'T', '0', '1', $string );
    },
    'search' => sub {
      return $self->cmd( 'search_tth', @_ ) if length $_[0] == 39 and $_[0] =~ /^[0-9A-Z]+$/;
      return $self->cmd( 'search_string', @_ ) if length $_[0];
    },
    'search_retry' => sub {
      #      $self->cmd( 'search_buffer', @{$self->{'search_last'}})
      #unshift( @{ $self->{'search_todo'} }, [@{$self->{'search_last'}}] )
      unshift( @{ $self->{'search_todo'} }, $self->{'search_last'} )
        if ref $self->{'search_last'} eq 'ARRAY';
      $self->{'search_last'} = undef;
    },
    };
#print "[$self->{'number'}]BEF";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";
#print "[$self->{'number'}]CLR";print "[$_ = $clear{$_}]"for sort keys %clear;print "\n";
#    $self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, %clear, 'socket' => $_, 'LocalPort'=>$self->{'myport'}, 'want' => \%{$self->{'want'}},
#print "Listen on port $self->{'myport'} \n";
$self->log('dev', "making listeners: tcp");
  if ( $self->{'M'} eq 'A' ) {
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
    $self->log('dev', "making listeners: udp");
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
      'parse'       => { 'SR' => $self->{'parse'}{'SR'} },
      'auto_listen' => 1,
    );
    $self->{'myport_udp'} = $self->{'clients'}{'listener_udp'}{'myport'};
    $self->log( 'err', "cant listen udp (search repiles)" )
      unless $self->{'myport_udp'};
  }
  #
  #$self->log('dev', "listeners created"),
  #  $self->{'clients'}{'listener'}->listen();
  #print "[$self->{'number'}]AFT";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";
}
1;
