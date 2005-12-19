
package client;
use dcppp;
our @ISA = ('dcppp');

  sub init {
    my $self = shift;
    %{$self->{'parse'}} = (
      'Lock' => sub { $self->{'sendbuf'} = 1;
	$self->{'cmd'}{'Key'}->();
	$self->{'sendbuf'} = 0;
	$self->{'cmd'}{'ValidateNick'}->();
	$self->checkrecv();
      },
      'Hello' => sub { $self->{'sendbuf'} = 1;
	$self->{'cmd'}{'Version'}->();
	$self->{'sendbuf'} = 0;
	$self->{'cmd'}{'MyINFO'}->();
	$self->checkrecv();
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

      'Search' => sub { }, #todo
      'Quit' => sub { $self->{'NickList'}{$_[0]}{'online'} = 0; }, #todo
      'UserIP' => sub { print"todo[UserIP]$_[0]\n"}, #todo
      'ConnectToMe' => sub { print"todo[ConnectToMe]$_[0]\n"}, #todo

    );
  
    %{$self->{'cmd'}} = (
      'Key' => sub { $self->sendcmd('Key', $self->{'Key'}); },
      'ValidateNick' => sub { $self->sendcmd('ValidateNick', $self->{'Nick'}); ++$self->{'mustrecv'};},
      'Version' => sub { $self->sendcmd('Version', $self->{'Version'}); },
      'MyINFO' => sub { $self->sendcmd('MyINFO', '$ALL', $self->{'Nick'}, $self->{'MyINFO'}); },
      'GetNickList' => sub { $self->sendcmd('GetNickList'); ++$self->{'mustrecv'};},
      'GetINFO' => sub { $self->sendcmd('GetINFO', $_[0], $self->{'Nick'}); ++$self->{'mustrecv'};},
    );
  }

1;