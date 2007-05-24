#Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proler@gmail.com icq#89088275

my $Id = '$Id$';

package dcppp::clihub;

#use lib '../../..';
#use lib '../..';
#use lib '..';
#  use Time::HiRes;
eval { use Time::HiRes qw(time sleep); };
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
    'Pass' => '',
    'Key'  => 'zzz',

    #        %$self,
    'supports_avail' => [
      qw(
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
    @_,
    'incomingclass' => 'dcppp::clicli',
  );

  #print "2: $self->{'Nick'}\n";
  $self->baseinit();

  #print('dcdbg', "myip : $self->{'myip'}", "\n");

  %{ $self->{'parse'} } = (
    'chatline' => sub { },    #print("welcome:", @_) unless $self->{'no_print_welcome'}; },
    'welcome'  => sub { },    #print("welcome:", @_)
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
      #	$self->recv();
      #$self->{'log'}->('info', "HELLO end rec st:[$self->{'status'}]");
    },
    'Supports' => sub {
      $self->supports_parse( $_[0], $self );
    },

    'To'     => sub { $self->{'log'}->( 'msg', "Private message to", @_ ); },
    'MyINFO' => sub {
      my ( $nick, $info ) = $_[0] =~ /\S+\s+(\S+)\s+(.*)/;

      #        print("Bad nick:[$_[0]]"), return unless length $nick;
      $self->{'NickList'}->{$nick}{'Nick'} = $nick;

      #        $self->{'NickList'}->{$nick}{'info'} = $info;
      #print "preinfo[$info] to $self->{'NickList'}->{$nick}\n";
      $self->info_parse( $info, $self->{'NickList'}->{$nick} );
      $self->{'NickList'}->{$nick}{'online'} = 1;

      #        print  "info:$nick [$info]\n";
    },
    'UserIP' => sub {
      /(\S+)\s+(\S+)/, $self->{'NickList'}->{$1}{'ip'} = $2, $self->{'IpList'}->{$2} = \%{ $self->{'NickList'}->{$1} },
        $self->{'IpList'}->{$2}->{'port'} = $self->{'PortList'}->{$2}
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

      #        print 'nicklist:', join(';', sort keys %{$self->{'NickList'}}), "\n"
    },
    'OpList' => sub {
      $self->{'NickList'}->{$_}{'oper'} = 1 for grep $_, split /\$\$/, $_[0];
    },
    'ForceMove' => sub {
      $self->{'log'}->( 'info', "ForceMove to $_[0]" );
      $self->disconnect();
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
        'PortList' => \%{ $self->{'PortList'}, 'handler' => \%{ $self->{'handler'} }, },

 #         $self->{'clients'}{$host .':'. $port} = dcppp::clicli->new(%$self, $self->clear(), 'host' => $host,  'port' => $port,
 #'clients' => {},
 #'debug'=>1,
      );
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

    'Search' => sub { },     #todo

    #         $self->{'IpList'}->{$self->{'peerip'}} = \%{ $self->{'NickList'}->{$self->{'peernick'} } };
    #
    #      'UserIP' => sub { print"todo[UserIP]$_[0]\n"}, #todo
    #      'ConnectToMe' => sub { print"todo[ConnectToMe]$_[0]\n"}, #todo
  );

  %{ $self->{'cmd'} } = (
    'chatline' => sub {
      for (@_) {

        #  	  sleep($self->{'min_chat_delay'}) if $self->{'min_chat_delay'};
        #          if ($self->{'min_chat_delay'}) {
        if ( $self->{'min_chat_delay'} and ( time - $self->{'last_chat_time'} < $self->{'min_chat_delay'} ) ) {
          $self->{'log'}->( 'dbg', 'sleep', $self->{'min_chat_delay'} - time + $self->{'last_chat_time'} );
          sleep( $self->{'min_chat_delay'} - time + $self->{'last_chat_time'} );
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
      $self->sendcmd( 'Supports', ( $self->supports() or return ) );
    },
  );

  #print "[$self->{'number'}]BEF";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";
  #print "[$self->{'number'}]CLR";print "[$_ = $clear{$_}]"for sort keys %clear;print "\n";

#    $self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, %clear, 'socket' => $_, 'LocalPort'=>$self->{'myport'}, 'want' => \%{$self->{'want'}},
#print "Listen on port $self->{'myport'} \n";
  $self->{'clients'}{''} = $self->{'incomingclass'}->new(
    %$self, $self->clear(),
    'want'     => \%{ $self->{'want'} },
    'NickList' => \%{ $self->{'NickList'} },
    'IpList'   => \%{ $self->{'IpList'} },
    'PortList' => \%{ $self->{'PortList'} },
    'handler'  => \%{ $self->{'handler'} },

    #    $self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, $self->clear(),
    #'LocalPort'=>$self->{'myport'},
    #'debug'=>1,
  );
  $self->{'clients'}{''}->listen();
  $self->connect() if $self->{'auto_connect'};

  #print "[$self->{'number'}]AFT";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";

}

1;
