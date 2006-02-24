
package dcppp::clihub;

#use dcppp;



our @ISA = ('dcppp');

  my %clear = ('clients' => {},'socket' => '', 'select' => '','accept' => 0, 'filehandle'=>undef, 'parse'=>{},  'cmd'=>{}, );


  sub init {
    my $self = shift;
    %$self = (
	'Nick'	=> 'dcpppBot', 
	'port'	=> 4111, 
	'host'	=> 'localhost', 
        'myport' => '6779',
	'Version'	=> '++ V:0.673,M:A,H:0/1/0,S:2', 
	'MyINFO'	=> 'interest$ $LAN(T3)1$e-mail@mail.ru$1$',
	'pass'	=> '', 
	'Key'	=> 'zzz', 
#        %$self,
        @_,
	'incomingclass' => 'dcppp::clicli',
);

#print "2: $self->{'Nick'}\n";

    %{$self->{'parse'}} = (
      'chatline' => sub { #print "CHAT:", @_, "\n"; 
      },
      'Lock' => sub { $self->{'sendbuf'} = 1;
	$self->{'cmd'}{'Key'}->();
	$self->{'sendbuf'} = 0;
	$self->{'cmd'}{'ValidateNick'}->();
#	$self->recv();
      },
      'Hello' => sub { 
        return unless $_[0] eq $self->{'Nick'};
        $self->{'sendbuf'} = 1;
	$self->{'cmd'}{'Version'}->();
	$self->{'sendbuf'} = 0;
	$self->{'cmd'}{'MyINFO'}->();
#	$self->recv();
      },
      'To' => sub { print "Private message to", @_, "\n";  },
      'MyINFO' => sub { 
        my ($nick, $info) = $_[0] =~ /\S+\s+(\S+)\s+(.*)/;
#        print("Bad nick:[$_[0]]"), return unless length $nick;
        $self->{'NickList'}{$nick}{'info'} = $info;
        $self->{'NickList'}{$nick}{'online'} = 1;
#        print  "info:$nick [$info]\n";
      }, 
      'UserIP' => sub { /(\S+)\s+(\S+)/, $self->{'NickList'}{$1}{'ip'} = $2 for grep $_, split /\$\$/, @_[0]; },
      'HubName' => sub { $self->{'HubName'} = @_[0];},
      'HubTopic' => sub { $self->{'HubTopic'} = @_[0];},
      'NickList' => sub { 
        $self->{'NickList'}{$_}{'online'} = 1 for grep $_, split /\$\$/, @_[0];
#        print 'nicklist:', join(';', sort keys %{$self->{'NickList'}}), "\n"
      },
      'OpList' => sub { $self->{'NickList'}{$_}{'oper'} = 1 for grep $_, split /\$\$/, @_[0]; },
      'ForceMove' => sub { print "ForceMove to $_[0]  \n"},
      'Quit' => sub { $self->{'NickList'}{$_[0]}{'online'} = 0; },
      'ConnectToMe' => sub { 
         my ($nick, $host, $port) = $_[0] =~ /\s*(\S+)\s+(\S+)\:(\S+)/;
#print "ALREADY CONNECTED",         
         return if $self->{'clients'}{$host .':'. $port}->{'socket'};
         $self->{'clients'}{$host .':'. $port} = dcppp::clicli->new( 
%$self,
%clear,
'host'=>$host, 
'port'=>$port, 
'want' => \%{$self->{'want'}},
#'clients' => {},
#'debug'=>1,
);
         $self->{'clients'}{$host .':'. $port}->connect();
         $self->{'clients'}{$host .':'. $port}->cmd('MyNick');
      },

#      'Search' => sub { }, #todo
#      'UserIP' => sub { print"todo[UserIP]$_[0]\n"}, #todo
#      'ConnectToMe' => sub { print"todo[ConnectToMe]$_[0]\n"}, #todo
    );
  
    %{$self->{'cmd'}} = (
      'chatline'	=> sub { $self->{'socket'}->send("<$self->{'Nick'}> $_|") for(@_); },
      'Key'	=> sub { $self->sendcmd('Key', $self->{'Key'}); },
      'ValidateNick'	=> sub { $self->sendcmd('ValidateNick', $self->{'Nick'}); },
      'Version'	=> sub { $self->sendcmd('Version', $self->{'Version'}); },
      'MyINFO'	=> sub { $self->sendcmd('MyINFO', '$ALL', $self->{'Nick'}, $self->{'MyINFO'}); },
      'GetNickList'	=> sub { $self->sendcmd('GetNickList'); },
      'GetINFO'	=> sub { $self->sendcmd('GetINFO', $_[0], $self->{'Nick'}); },
      'ConnectToMe' => sub { $self->sendcmd('ConnectToMe', $_[0], "$self->{'myip'}:$self->{'myport'}"); },
    );

#print "[$self->{'number'}]BEF";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";
#print "[$self->{'number'}]CLR";print "[$_ = $clear{$_}]"for sort keys %clear;print "\n";

    $self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, %clear, 'socket' => $_, 'LocalPort'=>$self->{'myport'}, 'want' => \%{$self->{'want'}}, 
#'debug'=>1,
);
    $self->{'clients'}{''}->listen();
#print "[$self->{'number'}]AFT";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";

  }


1;