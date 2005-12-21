
package dcppp::clicli;

#eval { use dcppp; };

our @ISA = ('dcppp');

  sub init {
    my $self = shift;
    %$self = (%$self,
	'Nick'	=> 'dcpppBot', 
	'Key'	=> 'zzz', 
	'Lock'	=> 'EXTENDEDPROTOCOLABCABCABCABCABCABC Pk=DCPLUSPLUS0.668ABCABC',
	'Supports' => 'MiniSlots XmlBZList ADCGet TTHL TTHF GetZBlock ZLI',
	'Direction' => 'Upload 1',
      @_);

    %{$self->{'parse'}} = (
      'Lock' => sub { 
        $self->{'sendbuf'} = 1;
	$self->{'cmd'}{'MyNick'}->();
	$self->{'sendbuf'} = 0;
	$self->{'cmd'}{'Lock'}->();
	$self->recv();
      },
      'Supports' => sub { },
      'Direction' => sub { },
      'Key' => sub { 
        $self->{'sendbuf'} = 1;
	$self->{'cmd'}{'Supports'}->();
	$self->{'cmd'}{'Direction'}->();
        $self->{'sendbuf'} = 0;
	$self->{'cmd'}{'Key'}->();
      },
      'Get' => sub { 
	$self->{'cmd'}{'FileLength'}->(0);
      },
    );
  
    %{$self->{'cmd'}} = (
      'MyNick'	=> sub { $self->sendcmd('MyNick', $self->{'Nick'}); },
      'Lock'	=> sub { $self->sendcmd('Lock', $self->{'Lock'}); },
      'Supports'	=> sub { $self->sendcmd('Supports', $self->{'Supports'}); },
      'Direction'	=> sub { $self->sendcmd('Direction', $self->{'Direction'}); },
      'Key'	=> sub { $self->sendcmd('Key', $self->{'Key'}); },
      'FileLength' =>  sub { $self->sendcmd('FileLength', $_[0]); },
    );
  }

1;