my $Id = '$Id$';

package dcppp::clicli;

#eval { use dcppp; };
#use lib '../..';
use dcppp;
use strict;
  no warnings qw(uninitialized);

our @ISA = ('dcppp');

  sub init {
    my $self = shift;
#print( "$self::init from ", join(':', caller), "\n");
#print "1.0: $self->{'Nick'} : ",@_,"\n";
#print "Sc0[$self->{'socket'}]\n";
    %$self = (%$self,
	'Nick'	=> 'dcpppBot', 
#	'Key'	=> 'zzz', 
	'Lock'	=> 'EXTENDEDPROTOCOLABCABCABCABCABCABC Pk=DCPLUSPLUS0.668ABCABC',
#	'Supports' => 'MiniSlots XmlBZList ADCGet TTHL TTHF GetZBlock ZLI',
#	'Supports' => 'XmlBZList',
#http://www.dcpp.net/wiki/index.php/%24Supports
        'supports_avail' => [qw(
BZList 
MiniSlots 
GetZBlock 
XmlBZList 
ADCGet 
TTHL 
TTHF 
ZLIG 
ClientID 
CHUNK 
GetTestZBlock 
GetCID
)],
         'XmlBZList' => 1,
         'ADCGet' => 1,
         'MiniSlots' => 1,

         @_,
#	'Direction' => 'Upload', #rand here
#	'incomingclass' => 'dcppp::clicli',
    );
    $self->baseinit();

#print "1: $self->{'Nick'}\n";
#print "Sc1[$self->{'socket'}]\n";
#print "CLICLI init [$self->{'number'}]\n";

#    ($self->{'peerport'}, $self->{'peerip'}) = unpack_sockaddr_in( getpeername( $self->{'socket'} ) ) if $self->{'socket'};
#    $self->{'peerip'}  = inet_ntoa($self->{'peerip'}) if $self->{'peerip'};
    $self->get_peer_addr();
    print "[$self->{'number'}] Incoming client $self->{'peerip'}\n" if $self->{'peerip'};

#print("{{  $self->{'NickList'} }}");
#print("[$_]")for sort keys %{$self->{'NickList'}};

#print " clicli init clients:{", keys %{$self->{'clients'}}, "}\n";


#print "parse init\n";
#    %{$self->{'parse'}} = (
    $self->{'parse'} = {
      'Lock' => sub { 
#print "CLICLI lock parse\n";
        if ($self->{'incoming'}) {
          $self->{'sendbuf'} = 1;
          $self->cmd('MyNick');
	  $self->cmd('Lock');
  	  $self->cmd('Supports');
          $self->{'Direction'} = 'Download';
  	  $self->cmd('Direction');
	  $self->{'sendbuf'} = 0;
#          $_[0] =~ /(\S+)/;
#          $_[0] =~ /^(.+) Pk=/i;
#          $_[0] =~ /^(.+?)( Pk=.+)?$/i;
          $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
	  $self->cmd('Key', dcppp::lock2key($1));
#	  $self->cmd('Key', dcppp::lock2key($_[0]));
        } else {
          $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
#	  $self->cmd('Key', dcppp::lock2key($1));
          $self->{'Key'} = dcppp::lock2key($1);
#         $self->{'sendbuf'} = 1;
#         $self->cmd('MyNick');
#	  $self->{'sendbuf'} = 0;
#	  $self->cmd('Lock');
        }
      },
      'Supports' => sub { },
      'Direction' => sub { 
      },
      'Key' => sub { 
        if ($self->{'incoming'}) {
#print " CL $self->{'number'} [nick:$_] " for keys %{$self->{'want'}};
=c
          for(keys %{$self->{'want'}->{$self->{'peernick'}}}) {
             ($self->{'filename'}, $self->{'fileas'}) =  
             ($_, $self->{'want'}->{$self->{'peernick'}}{$_});
             last;
          }
=cut
        } else {
          $self->{'sendbuf'} = 1;
	  $self->cmd('Supports');
	  $self->cmd('Direction');
          $self->{'sendbuf'} = 0;
  	  $self->cmd('Key', $self->{'Key'});
        }
	$self->cmd('selectfile') if $self->{'Direction'} eq 'Download';
 #print "get:[filename:",$self->{'filename'},'; fileas:', $self->{'fileas'},"]\n";
	$self->{'Get'} = $self->{'filename'} . '$' . ($self->{'filefrom'} or 1),
         $self->{'ADCGet'} = 'file ' . $self->{'filename'} . ' 0 -1',
  	 $self->cmd(($self->{'NickList'}->{$self->{'peernick'}}{'ADCGet'} ? 'ADC' : '') . 'Get')
          if $self->{'filename'};
      },
      'Get' => sub { $self->cmd('FileLength',0); },
      'MyNick' => sub { 
         print "[$self->{'number'}] peer is [", ($self->{'peernick'} = $_[0]), "]\n";
         $self->{'NickList'}->{$self->{'peernick'}}{'ip'} = $self->{'peerip'};
         $self->{'IpList'}->{$self->{'peerip'}} = \%{ $self->{'NickList'}->{$self->{'peernick'} } };
        if (keys %{$self->{'want'}->{$self->{'peernick'}}}) {
#print ("we want to download ",keys %{$self->{'want'}->{$self->{'peernick'}}}, " files\n");
          $self->{'Direction'} = 'Download';
        } else {
          $self->{'Direction'} = 'Upload';
#print ("we dont want to download \n");

        }

      },

      'FileLength' => sub { 
        $self->{'filetotal'} = $_[0];
        return if $self->openfile();
#        open($self->{'filehandle'}, '>', ($self->{'fileas'} or $self->{'filename'})) or return;
#        binmode($self->{'filehandle'});
        $self->cmd('Send'); 
      },
      'ADCSND' => sub {
        $_[0] =~ /(\d+?)$/is;
        $self->{'filetotal'} = $1;
        return if $self->openfile();
#        open($self->{'filehandle'}, '>', ($self->{'fileas'} or $self->{'filename'})) or return;
#        binmode($self->{'filehandle'});
      },
      'Supports' => sub {
        $self->supports_parse($_[0], $self->{'NickList'}->{$self->{'peernick'}});
      },
    };
  
#print "cmd init ($self->{'cmd'})\n";
#    %{$self->{'cmd'}} = {
    $self->{'cmd'} = {
      'connect'	=> sub { 
         $self->connect();
         $self->{'sendbuf'} = 1;
         $self->cmd('MyNick');
         $self->{'sendbuf'} = 0;
         $self->cmd('Lock');
      },
      'selectfile'	=> sub { 
          for(keys %{$self->{'want'}->{$self->{'peernick'}}}) {
             ($self->{'filename'}, $self->{'fileas'}) =  
             ($_, $self->{'want'}->{$self->{'peernick'}}{$_});
             last;
          }
      },

      'MyNick'	=> sub { $self->sendcmd('MyNick', $self->{'Nick'}); },
      'Lock'	=> sub { $self->sendcmd('Lock', $self->{'Lock'}); },
#      'Supports'	=> sub { $self->sendcmd('Supports', $self->{'Supports'}); },
      'Supports'	=> sub { $self->sendcmd('Supports', ($self->supports() or return)); },
      'Direction'	=> sub { 
        $self->sendcmd('Direction', $self->{'Direction'}, int(rand(0x7FFF))); 
#$self->{'want'}->{$self->{'peernick'}}
},
      'Key'	=> sub { $self->sendcmd('Key', $_[0]); },
      'Get'	=> sub { $self->sendcmd('Get', $self->{'Get'}); },
      'Send'	=> sub { $self->sendcmd('Send'); },
      'FileLength' =>  sub { $self->sendcmd('FileLength', $_[0]); },
      'ADCGet'  => sub{ $self->sendcmd('ADCGET', $self->{'ADCGet'}); },
    };

#print " clicli aftinit clients:{", keys %{$self->{'clients'}}, "}\n";

  }

1;