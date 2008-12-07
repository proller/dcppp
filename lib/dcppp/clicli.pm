#Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proler@gmail.com icq#89088275
my $Id = '$Id$';

package dcppp::clicli;
#eval { use dcppp; };
#use lib '../..';
use dcppp;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
#our @ISA = ('dcppp');
use base 'dcppp';

sub init {
  my $self = shift;
  #print( "$self::init from ", join(':', caller), "\n");
  #print "1.0: $self->{'Nick'} : ",@_,"\n";
  #print "Sc0[$self->{'socket'}]\n";
  %$self = (
    %$self,
#    'Nick' => 'dcpppBot',
    #	'Key'	=> 'zzz',
    #	'Supports' => 'MiniSlots XmlBZList ADCGet TTHL TTHF GetZBlock ZLI',
    #	'Supports' => 'XmlBZList',
    #http://www.dcpp.net/wiki/index.php/%24Supports
    'supports_avail' => [ qw(
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
        )
    ],
    'XmlBZList' => 1,
    'ADCGet'    => 1,
    'MiniSlots' => 1,
    @_,
    'Direction' => 'Download',
    #	'Direction' => 'Upload', #rand here
    #	'incomingclass' => 'dcppp::clicli',
  );

    $self->{'auto_connect'}      =  1 if  !$self->{'incoming'} and !defined $self->{'auto_connect'};


  $self->baseinit();
  #print "1: $self->{'Nick'}\n";
  #print "Sc1[$self->{'socket'}]\n";
  #print "CLICLI init [$self->{'number'}]\n";
  #    ($self->{'peerport'}, $self->{'peerip'}) = unpack_sockaddr_in( getpeername( $self->{'socket'} ) ) if $self->{'socket'};
  #    $self->{'peerip'}  = inet_ntoa($self->{'peerip'}) if $self->{'peerip'};
  $self->get_peer_addr();
  #     $self->{'log'}->('info', "[$self->{'number'}] Incoming client $self->{'peerip'}") if $self->{'peerip'};
  $self->{'log'}->( 'info', "[$self->{'number'}] Incoming client $self->{'host'}:$self->{'port'}" ) if $self->{'incoming'};
  #print("{{  $self->{'NickList'} }}");
  #print("[$_]")for sort keys %{$self->{'NickList'}};
  #print " clicli init clients:{", keys %{$self->{'clients'}}, "}\n";
  #print "parse init\n";
  #    %{$self->{'parse'}} = (
  $self->{'parse'} ||= {
    'Lock' => sub {
      #print "CLICLI lock parse\n";
      if ( $self->{'incoming'} ) {
        $self->{'sendbuf'} = 1;
        $self->cmd('MyNick');
        #          $self->{'sendbuf'} = 0;
        $self->cmd('Lock');
        #	  $self->recv();
        #          $self->{'sendbuf'} = 1;
        $self->cmd('Supports');
        #          $self->{'Direction'} = 'Download';
        $self->cmd('Direction');
        $self->{'sendbuf'} = 0;
        #          $_[0] =~ /(\S+)/;
        #          $_[0] =~ /^(.+) Pk=/i;
        #          $_[0] =~ /^(.+?)( Pk=.+)?$/i;
        $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
        $self->cmd( 'Key', dcppp::lock2key($1) );
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
    #      'Supports' => sub { },
    'Direction' => sub {
      #$self->cmd('selectfile') if $self->{'Direction'} eq 'Download';
      if   ( $_[0] eq 'Download' ) { $self->{'Direction'} = 'Upload'; }
      else                         { $self->{'Direction'} = 'Download'; }
    },
    'Key' => sub {
      if ( $self->{'incoming'} ) {
        #  	  $self->cmd('Supports');
        #          $self->{'Direction'} = 'Download';
        #  	  $self->cmd('Direction');
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
        $self->cmd( 'Key', $self->{'Key'} );
      }
      $self->cmd('selectfile') if $self->{'Direction'} eq 'Download';
      #print "get:[filename:",$self->{'filename'},'; fileas:', $self->{'fileas'},"]\n";
      $self->{'Get'} = $self->{'filename'} . '$' . ( $self->{'filefrom'} or 1 ),
        $self->{'ADCGet'} = 'file ' . $self->{'filename'} . ' 0 -1',
        $self->cmd( ( $self->{'NickList'}->{ $self->{'peernick'} }{'ADCGet'} ? 'ADC' : '' ) . 'Get' )
        if $self->{'filename'};
    },
    'Get' => sub {
      #TODO
      $self->cmd( 'FileLength', 0 );
    },
    'MyNick' => sub {
      $self->{'log'}->( 'info', "[$self->{'number'}] peer is [", ( $self->{'peernick'} = $_[0] ), "]" );
      #         $self->{'NickList'}->{$self->{'peernick'}}{'ip'} = $self->{'peerip'};
      $self->{'NickList'}->{ $self->{'peernick'} }{'ip'} = $self->{'host'};
      #         $self->{'NickList'}->{$self->{'peernick'}}{'port'} = ($self->{'peerport'} or $self->{'port'});
      $self->{'NickList'}->{ $self->{'peernick'} }{'port'} = $self->{'port'};
      #         $self->{'IpList'}->{$self->{'peerip'}} = \%{ $self->{'NickList'}->{$self->{'peernick'} } };
      #         $self->{'IpList'}->{$self->{'peerip'}}->{'port'} = $self->{'PortList'}->{$self->{'peerip'}};
      $self->{'IpList'}->{ $self->{'host'} } = \%{ $self->{'NickList'}->{ $self->{'peernick'} } };
      $self->{'IpList'}->{ $self->{'host'} }->{'port'} = $self->{'PortList'}->{ $self->{'host'} };
      $self->handler( 'user_ip', $self->{'peernick'}, $self->{'host'}, $self->{'port'} );
      #$self->{'log'}->('dev', "[$self->{'number'}] peer port is [ip:$self->{'host'} pl",
      # $self->{'PortList'}->{$self->{'host'}},
      # 'nl',$self->{'NickList'}->{$self->{'peernick'}}{'port'},
      # 'port',$self->{'port'},"]");
      if ( keys %{ $self->{'want'}->{ $self->{'peernick'} } } ) {
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
    'CSND' => sub {
      $_[0] =~ /^file\s+\S+\s+(\d+)\s(\d+)$/is;
      $self->{'filetotal'} = $2;
      return if $self->openfile();
      #        open($self->{'filehandle'}, '>', ($self->{'fileas'} or $self->{'filename'})) or return;
      #        binmode($self->{'filehandle'});
    },
    'Supports' => sub {
      $self->supports_parse( $_[0], $self->{'NickList'}->{ $self->{'peernick'} } );
    },
    'MaxedOut' => sub {
      $self->disconnect();
      }
  };
  #print "cmd init ($self->{'cmd'})\n";
  #    %{$self->{'cmd'}} = {
  $self->{'cmd'} ||= {
    'connect' => sub {
      $self->connect() && return;
      $self->{'sendbuf'} = 1;
      $self->cmd('MyNick');
      $self->{'sendbuf'} = 0;
      $self->cmd('Lock');
    },
    'selectfile' => sub {
      for ( keys %{ $self->{'want'}->{ $self->{'peernick'} } } ) {
        ( $self->{'filename'}, $self->{'fileas'} ) = ( $_, $self->{'want'}->{ $self->{'peernick'} }{$_} );
        last;
      }
      return unless defined $self->{'filename'};
      unless ( $self->{'filename'} ) {
        if ( $self->{'NickList'}->{ $self->{'peernick'} }{'XmlBZList'} ) {
          $self->{'fileext'}  = '.xml.bz2';
          $self->{'filename'} = 'files' . $self->{'fileext'};
        } elsif ( $self->{'NickList'}->{ $self->{'peernick'} }{'BZList'} ) {
          $self->{'fileext'}  = '.bz2';
          $self->{'filename'} = 'MyList' . $self->{'fileext'};
        } else {
          $self->{'fileext'}  = '.DcLst';
          $self->{'filename'} = 'MyList' . $self->{'fileext'};
        }
        #$self->{'log'}->('dev', "fas was", $self->{'fileas'});
        $self->{'fileas'} .= $self->{'fileext'} if $self->{'fileas'};
        #$self->{'log'}->('dev', "fas now", $self->{'fileas'});
      }
    },
    'MyNick' => sub {
      $self->sendcmd( 'MyNick', $self->{'Nick'} );
    },
    'Lock' => sub {
      $self->sendcmd( 'Lock', $self->{'Lock'} );
    },
    #      'Supports'	=> sub { $self->sendcmd('Supports', $self->{'Supports'}); },
    'Supports' => sub { $self->sendcmd( 'Supports', ( $self->supports() or return ) ); },
    'Direction' => sub {
      $self->sendcmd( 'Direction', $self->{'Direction'}, int( rand(0x7FFF) ) );
      #$self->{'want'}->{$self->{'peernick'}}
    },
    'Key' => sub {
      $self->sendcmd( 'Key', $_[0] );
    },
    'Get' => sub {
      $self->sendcmd( 'Get', $self->{'Get'} );
    },
    'Send' => sub {
      $self->sendcmd('Send');
    },
    'FileLength' => sub {
      $self->sendcmd( 'FileLength', $_[0] );
    },
    'ADCGet' => sub {
      $self->sendcmd( 'ADCGET', $self->{'ADCGet'} );
    },
  };
  #print " clicli aftinit clients:{", keys %{$self->{'clients'}}, "}\n";
}
1;
