
package dcppp::clicli;

#eval { use dcppp; };
#use lib '../..';
use dcppp;

our @ISA = ('dcppp');

  sub init {
    my $self = shift;
#print "1.0: $self->{'Nick'} : ",@_,"\n";
print "Sc0[$self->{'socket'}]\n";
    %$self = (
	'Nick'	=> 'dcpppBot', 
	'Key'	=> 'zzz', 
	'Lock'	=> 'EXTENDEDPROTOCOLABCABCABCABCABCABC Pk=DCPLUSPLUS0.668ABCABC',
	'Supports' => 'MiniSlots XmlBZList ADCGet TTHL TTHF GetZBlock ZLI',
         @_,
	'Direction' => 'Upload 1', #rand here
	'incomingclass' => 'dcppp::clicli',
    );
#print "1: $self->{'Nick'}\n";
print "Sc1[$self->{'socket'}]\n";

#    ($self->{'peerport'}, $self->{'peerip'}) = unpack_sockaddr_in( getpeername( $self->{'socket'} ) ) if $self->{'socket'};
#    $self->{'peerip'}  = inet_ntoa($self->{'peerip'}) if $self->{'peerip'};
    $self->get_peer_addr();
    print "Incoming client $self->{'peerip'}:$self->{'peerport'}\n" if $self->{'peerip'};

#print("{{  $self->{'NickList'} }}");
#print("[$_]")for sort keys %{$self->{'NickList'}};


    %{$self->{'parse'}} = (
      'Lock' => sub { 
        if ($self->{'incoming'}) {
          $self->{'sendbuf'} = 1;
          $self->cmd('MyNick');
	  $self->cmd('Lock');
  	  $self->cmd('Supports');
          $self->{'Direction'} = 'Download 1';
  	  $self->cmd('Direction');
	  $self->{'sendbuf'} = 0;
	  $self->cmd('Key');
        } else {
          $self->{'sendbuf'} = 1;
          $self->cmd('MyNick');
	  $self->{'sendbuf'} = 0;
	  $self->cmd('Lock');
        }
      },
      'Supports' => sub { },
      'Direction' => sub { },
      'Key' => sub { 
        if ($self->{'incoming'}) {
#print " CL $self->{'number'} [nick:$_] " for keys %{$self->{'want'}};
          for(keys %{$self->{'want'}->{$self->{'peernick'}}}) {
             ($self->{'filename'}, $self->{'fileas'}) =  
             ($_, $self->{'want'}->{$self->{'peernick'}}{$_});
             last;
          }
print "get:[filename:",$self->{'filename'},'; fileas:', $self->{'fileas'},"]\n";
	  $self->{'Get'} = $self->{'filename'} . '$' . ($self->{'filefrom'} or 1);
	  $self->cmd('Get');
        } else {
        $self->{'sendbuf'} = 1;
	$self->cmd('Supports');
	$self->cmd('Direction');
        $self->{'sendbuf'} = 0;
	$self->cmd('Key');
        }
      },
      'Get' => sub { $self->cmd('FileLength',0); },
      'MyNick' => sub { print 'peer is [', ($self->{'peernick'} = @_[0]), "]\n";},

      'FileLength' => sub { 
        $self->{'filetotal'} = $_[0];
        open($self->{'filehandle'}, '>', ($self->{'fileas'} or $self->{'filename'})) or return;
        binmode($self->{'filehandle'});
        $self->cmd('Send'); 
      },
    );
  
    %{$self->{'cmd'}} = (
      'MyNick'	=> sub { $self->sendcmd('MyNick', $self->{'Nick'}); },
      'Lock'	=> sub { $self->sendcmd('Lock', $self->{'Lock'}); },
      'Supports'	=> sub { $self->sendcmd('Supports', $self->{'Supports'}); },
      'Direction'	=> sub { $self->sendcmd('Direction', $self->{'Direction'}); },
      'Key'	=> sub { $self->sendcmd('Key', $self->{'Key'}); },
      'Get'	=> sub { $self->sendcmd('Get', $self->{'Get'}); },
      'Send'	=> sub { $self->sendcmd('Send'); },
      'FileLength' =>  sub { $self->sendcmd('FileLength', $_[0]); },
    );

  }

1;