
package dcppp::clihub;

#use dcppp;

our @ISA = ('dcppp');

  sub init {
    my $self = shift;
    %$self = (%$self,
	'host'	=> 'localhost', 
        'LocalPort' => '6779',
	'port'	=> 4111, 
	'Nick'	=> 'dcpppBot', 
	'pass'	=> '', 
	'Version'	=> '++ V:0.673,M:A,H:0/1/0,S:2', 
	'Key'	=> 'zzz', 
	'MyINFO'	=> 'interest$ $LAN(T3)1$e-mail@mail.ru$1$',
	'incomingclass' => 'dcppp::clicli',
      @_);


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
        $self->{'NickList'}{$nick}{'info'} = $info;
        $self->{'NickList'}{$nick}{'online'} = 1;
#        print  "info:$nick [$info]\n";
      }, 
      'UserIP' => sub { 
        /(\S+)\s+(\S+)/, $self->{'NickList'}{$1}{'ip'} = $2 for grep $_, split /\$\$/, @_[0];
      },
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
         $self->{'clients'}{$host .':'. $port} = dcppp::clicli->new( 'host'=>$host, 'port'=>$port, 
'want' => \%{$self->{'want'}},
'debug'=>1,
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
      'ConnectToMe' => sub { $self->sendcmd('ConnectToMe', $_[0], "$self->{'ip'}:$self->{'LocalPort'}"); },
    );

    $self->{'clients'}{''} = $self->{'incomingclass'}->new( 'socket' => $_, 'LocalPort'=>$self->{'LocalPort'}, 'want' => \%{$self->{'want'}}, 'debug'=>1,);
    $self->{'clients'}{''}->listen();

  }


1;