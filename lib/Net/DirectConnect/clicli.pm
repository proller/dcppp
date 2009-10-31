#$Id$ $URL$
package Net::DirectConnect::clicli;
use strict;
use Net::DirectConnect;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
use base 'Net::DirectConnect';

sub init {
  my $self = shift;
  #$self->log($self, 'inited0',"MT:$self->{'message_type'}", ' with', Dumper  \@_);
  %$self = (
    %$self,
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
    'direction' => 'Download',
    #'Direction' => 'Upload', #rand here
    'reconnects' => 0,
  );
  $self->{'auto_connect'} = 1 if !$self->{'incoming'} and !defined $self->{'auto_connect'};
  #$self->log($self, 'inited1',"MT:$self->{'message_type'}", ' with', Dumper  \@_);
  $self->baseinit();
  #$self->log($self, 'inited2',"MT:$self->{'message_type'}", ' with', Dumper  \@_);
  $self->get_peer_addr();
  #$self->log('info', "[$self->{'number'}] Incoming client $self->{'peerip'}") if $self->{'peerip'};
  $self->log( 'info', "Incoming client $self->{'host'}:$self->{'port'} via ", ref $self ) if $self->{'incoming'};
  $self->{'parse'} = undef if $self->{'parse'} and !keys %{ $self->{'parse'} };
  $self->{'parse'} ||= {
    'Lock' => sub {
      if ( $self->{'incoming'} ) {
        $self->{'sendbuf'} = 1;
        $self->cmd('MyNick');
        #$self->{'sendbuf'} = 0;
        $self->cmd('Lock');
        #$self->{'sendbuf'} = 1;
        $self->cmd('Supports');
        $self->cmd('Direction');
        $self->{'sendbuf'} = 0;
        $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
        $self->cmd( 'Key', Net::DirectConnect::lock2key($1) );
      } else {
        $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
        $self->{'key'} = Net::DirectConnect::lock2key($1);
      }
    },
    'Direction' => sub {
      if   ( $_[0] eq 'Download' ) { $self->{'direction'} = 'Upload'; }
      else                         { $self->{'direction'} = 'Download'; }
    },
    'Key' => sub {
      if ( $self->{'incoming'} ) { }
      else {
        $self->{'sendbuf'} = 1;
        $self->cmd('Supports');
        $self->cmd('Direction');
        $self->{'sendbuf'} = 0;
        $self->cmd( 'Key', $self->{'key'} );
      }
      $self->cmd('file_select') if $self->{'direction'} eq 'Download';
      $self->log( "get:[filename:", $self->{'filename'}, '; fileas:', $self->{'fileas'}, "]" );
      $self->{'get'} = $self->{'filename'} . '$' . ( $self->{'filefrom'} || 1 ),
        $self->{'adcget'} = 'file ' . $self->{'filename'} . ' ' . ( $self->{'filefrom'} || 0 ) . ' -1',
        $self->cmd( ( $self->{'NickList'}->{ $self->{'peernick'} }{'ADCGet'} ? 'ADCGET' : 'Get' ) )
        if $self->{'filename'};
    },
    'Get' => sub {
      #TODO
      $self->cmd( 'FileLength', 0 );
    },
    'MyNick' => sub {
      $self->log( 'info', "peer is [", ( $self->{'peernick'} = $_[0] ), "]" );
      $self->{'NickList'}->{ $self->{'peernick'} }{'ip'}   = $self->{'host'};
      $self->{'NickList'}->{ $self->{'peernick'} }{'port'} = $self->{'port'};
      $self->{'IpList'}->{ $self->{'host'} }               = \%{ $self->{'NickList'}->{ $self->{'peernick'} } };
      $self->{'IpList'}->{ $self->{'host'} }->{'port'}     = $self->{'PortList'}->{ $self->{'host'} };
      $self->handler( 'user_ip', $self->{'peernick'}, $self->{'host'}, $self->{'port'} );
      if   ( keys %{ $self->{'want'}->{ $self->{'peernick'} } } ) { $self->{'direction'} = 'Download'; }
      else                                                        { $self->{'direction'} = 'Upload'; }
    },
    'FileLength' => sub {
      $self->{'filetotal'} = $_[0];
      return if $self->file_open();
      $self->cmd('Send');
    },
    'ADCSND' => sub {
      $self->log( 'dev', "ADCSND::", @_ );
      $_[0] =~ /(\d+?)$/is;
      $self->{'filetotal'} = $1;
      return $self->file_open();
    },
    'CSND' => sub {
      $_[0] =~ /^file\s+\S+\s+(\d+)\s(\d+)$/is;
      $self->{'filetotal'} = $2;
      return $self->file_open();
    },
    'Supports' => sub {
      $self->supports_parse( $_[0], $self->{'NickList'}->{ $self->{'peernick'} } );
    },
    'MaxedOut' => sub {
      $self->disconnect();
      }
  };
  #$self->log ( 'dev', "del empty cmd", ),
  $self->{'cmd'} = undef if $self->{'cmd'} and !keys %{ $self->{'cmd'} };
  $self->{'cmd'} ||= {
    'connect_aft' => sub {
      $self->{'sendbuf'} = 1;
      $self->cmd('MyNick');
      $self->{'sendbuf'} = 0;
      $self->cmd('Lock');
    },
    'MyNick' => sub {
      $self->sendcmd( 'MyNick', $self->{'Nick'} );
    },
    'Lock' => sub {
      $self->sendcmd( 'Lock', $self->{'lock'} );
    },
    'Supports' => sub {
      $self->sendcmd( 'Supports', ( $self->supports() or return ) );
    },
    'Direction' => sub {
      $self->sendcmd( 'Direction', $self->{'direction'}, int( rand(0x7FFF) ) );
    },
    'Key' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'Key', $_[0] );
    },
    'Get' => sub {
      $self->sendcmd( 'Get', $self->{'get'} );
    },
    'Send' => sub {
      $self->sendcmd('Send');
    },
    'FileLength' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'FileLength', $_[0] );
    },
    'ADCGET' => sub {
      #$ADCGET file TTH/I2VAVWYGSVTBHSKN3BOA6EWTXSP4GAKJMRK2DJQ 730020132 2586332
      $self->sendcmd( 'ADCGET', $self->{'adcget'} );
    },
  };
}
1;
