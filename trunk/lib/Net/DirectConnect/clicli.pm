#$Id$ $URL$
package    #hide from cpan
  Net::DirectConnect::clicli;
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
  %$self = (         #too bad! rewrite
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
    'TTHF'      => 1,
    #MiniSlots XmlBZList ADCGet TTHL TTHF
    @_, 'direction' => 'Download',
    #'Direction' => 'Upload', #rand here
    'reconnects'     => 0,
    inactive_timeout => 60,
  );
  $self->{'auto_connect'} = 1 if !$self->{'incoming'} and !defined $self->{'auto_connect'};
  #$self->log($self, 'inited1',"MT:$self->{'message_type'}", ' with', Dumper  \@_);
  #$self->baseinit();
  #$self->log($self, 'inited2',"MT:$self->{'message_type'}", ' with', Dumper  \@_);
  $self->get_peer_addr();
  #$self->log('info', "[$self->{'number'}] Incoming client $self->{'peerip'}") if $self->{'peerip'};
  #$self->{'share_tth'} ||=$self->{'parent'}{'share_tth'};
  #$self->{'share_full'} ||=$self->{'parent'}{'share_tth'};
  $self->{$_} ||= $self->{'parent'}{$_} for qw(share_full share_tth want handler NickList IpList PortList
    Nick
  );
  $self->{'NickList'} ||= {};
  $self->{'IpList'}   ||= {};
  $self->{'PortList'} ||= {};
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
        #}
        #my ($lock) = $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
        #$_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
        #$self->cmd( 'Key', $self->lock2key($lock) );
      } else {
        #$_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
        #$self->{'key'} = $self->lock2key($1);
        #$self->log ( 'dev','lock2key', "[$1]=[$self->{'key'}]");
      }
      #my ($lock)
      ( $self->{'key'} ) = $_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
      #$_[0] =~ /^(.+?)(\s+Pk=.+)?\s*$/is;
      #$self->cmd( 'Key', $self->lock2key($lock) );
    },
    'Direction' => sub {
      my $d = ( split /\s/, $_[0] )[0];
      if ( $d eq 'Download' ) { $self->{'direction'} = 'Upload'; }
      else {
        $self->{'direction'} = 'Download';
        #$self->log ( 'dev', "direction UNKNOWN [$d]", $self->{'direction'}, 'from', @_, ';');
      }
      #$self->log ( 'dev', "direction RECIEVED", $self->{'direction'}, 'from', @_, ';');
      #2009/11/04-02:08:20 dev [2] direction RECIEVED Download from Download 28048 ;
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
      $self->cmd('file_select'), $self->log( "get:[filename:", $self->{'filename'}, '; fileas:', $self->{'fileas'}, "]" )
        if $self->{'direction'} eq 'Download';
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
      #$self->log ( 'dev', "direction", $self->{'direction'}, 'from', keys %{ $self->{'want'}->{ $self->{'peernick'} } }, ';');
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
    },
    'ADCGET' => sub {
      $self->file_send_parse( map { split /\s/, $_ } @_ );
    },
  };
  #$self->log ( 'dev', "del empty cmd", ),
  $self->{'cmd'} = undef if $self->{'cmd'} and !keys %{ $self->{'cmd'} };
  $self->{'cmd'} ||= {
    'connect_aft' => sub {
      #my $self = shift if ref $_[0];
      $self->{'sendbuf'} = 1;
      $self->cmd('MyNick');
      $self->{'sendbuf'} = 0;
      $self->cmd('Lock');
    },
    'MyNick' => sub {
      $self->sendcmd(
        'MyNick', $self->{'Nick'}    #|| $self->{'parent'}{'Nick'}
      );
    },
    'Lock' => sub {
      $self->sendcmd( 'Lock', $self->{'lock'} );
    },
    'Supports' => sub {
      $self->sendcmd( 'Supports', $self->supports() || 'MiniSlots XmlBZList ADCGet TTHF' );    #TTHL
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
      my $self = shift if ref $_[0];
      #$ADCGET file TTH/I2VAVWYGSVTBHSKN3BOA6EWTXSP4GAKJMRK2DJQ 730020132 2586332
      $self->sendcmd( 'ADCGET', $self->{'adcget'} );
    },
    'ADCSND' => sub {
      my $self = shift if ref $_[0];
      $self->sendcmd( 'ADCSND', @_ );
    },
  };
}
1;
