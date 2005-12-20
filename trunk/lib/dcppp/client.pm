
package dcppp::client;

#use dcppp;

our @ISA = ('dcppp');

  sub init {
    my $self = shift;
    %$self = (%$self,
	'host'	=> 'localhost', 
	'port'	=> 4111, 
	'Nick'	=> 'dcpppBot', 
	'pass'	=> '', 
	'Version'	=> '++ V:0.673,M:A,H:0/1/0,S:2', 
	'Key'	=> 'zzz', 
	'MyINFO'	=> 'interest$ $LAN(T3)1$e-mail@mail.ru$1$',
      @_);


    %{$self->{'parse'}} = (
       'chatline' => sub { print "CHAT:", @_, "\n"; },
      'Lock' => sub { $self->{'sendbuf'} = 1;
	$self->{'cmd'}{'Key'}->();
	$self->{'sendbuf'} = 0;
	$self->{'cmd'}{'ValidateNick'}->();
	$self->recv();
      },
      'Hello' => sub { $self->{'sendbuf'} = 1;
	$self->{'cmd'}{'Version'}->();
	$self->{'sendbuf'} = 0;
	$self->{'cmd'}{'MyINFO'}->();
	$self->recv();
      },
      'To' => sub { print "Private message to", @_, "\n";  },
      'MyINFO' => sub { 
        my ($nick, $info) = $_[0] =~ /\S+\s+(\S+)\s+(.*)/;
        $self->{'NickList'}{$nick}{'info'} = $info;
        $self->{'NickList'}{$nick}{'online'} = 1;
        print  "info:$nick [$info]\n";
      }, 
      'HubName' => sub { print 'HubName is [', ($self->{'HubName'} = @_[0]), "]\n";},
      'HubTopic' => sub { print 'HubTopic is [', ($self->{'HubTopic'} = @_[0]), "]\n";},
      'NickList' => sub { 
        $self->{'NickList'}{$_}{'online'} = 1 for grep $_, split /\$\$/, @_[0];
        print 'nicklist:', join(';', sort keys %{$self->{'NickList'}}), "\n"
      },
      'OpList' => sub { $self->{'NickList'}{$_}{'oper'} = 1 for grep $_, split /\$\$/, @_[0]; },
      'ForceMove' => sub { print "ForceMove to $_[0]  \n"},
      'Quit' => sub { $self->{'NickList'}{$_[0]}{'online'} = 0; },
      'ConnectToMe' => sub { 
         my ($nick, $host, $port) = $_[0] =~ /\s*(\S+)\s+(\S+)\:(\S+)/;
#print "ALREADY CONNECTED",         
         return if $self->{'clients'}{$host .':'. $port}->{'socket'};
         $self->{'clients'}{$host .':'. $port} = dcppp::clicli->new( 'host'=>$host, 'port'=>$port, 
'debug'=>1,
);
         $self->{'clients'}{$host .':'. $port}->connect();
      },

#      'Search' => sub { }, #todo
#      'UserIP' => sub { print"todo[UserIP]$_[0]\n"}, #todo
#      'ConnectToMe' => sub { print"todo[ConnectToMe]$_[0]\n"}, #todo
    );
  
    %{$self->{'cmd'}} = (
      'chatline'	=> sub { $self->{'socket'}->send("<$self->{'Nick'}> $_|") for(@_); },
      'Key'	=> sub { $self->sendcmd('Key', $self->{'Key'}); },
      'ValidateNick'	=> sub { $self->sendcmd('ValidateNick', $self->{'Nick'}); ++$self->{'mustrecv'};},
      'Version'	=> sub { $self->sendcmd('Version', $self->{'Version'}); },
      'MyINFO'	=> sub { $self->sendcmd('MyINFO', '$ALL', $self->{'Nick'}, $self->{'MyINFO'}); },
      'GetNickList'	=> sub { $self->sendcmd('GetNickList'); ++$self->{'mustrecv'};},
      'GetINFO'	=> sub { $self->sendcmd('GetINFO', $_[0], $self->{'Nick'}); ++$self->{'mustrecv'};},
    );
  }

  sub recv {
    my $self = shift;
print "CLIREAD";
    $self->{'clients'}{$_}->recv() for keys %{$self->{'clients'}};
    $self->SUPER::recv();
  }

1;