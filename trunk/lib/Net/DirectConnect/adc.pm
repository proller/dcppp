#$Id$ $URL$
package Net::DirectConnect::adc;
use strict;
use Time::HiRes qw(time sleep);
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
use Net::DirectConnect;
#use Net::DirectConnect::clicli;
use Net::DirectConnect::http;
#use Net::DirectConnect::httpcli;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
use base 'Net::DirectConnect';
our %codesSTA = (
  '00' => 'Generic, show description',
  'x0' => 'Same as 00, but categorized according to the rough structure set below',
  '10' => 'Generic hub error',
  '11' => 'Hub full',
  '12' => 'Hub disabled',
  '20' => 'Generic login/access error',
  '21' => 'Nick invalid',
  '22' => 'Nick taken',
  '23' => 'Invalid password',
  '24' => 'CID taken',
  '25' =>
'Access denied, flag "FC" is the FOURCC of the offending command. Sent when a user is not allowed to execute a particular command',
  '26' => 'Registered users only',
  '27' => 'Invalid PID supplied',
  '30' => 'Kicks/bans/disconnects generic',
  '31' => 'Permanently banned',
  '32' =>
'Temporarily banned, flag "TL" is an integer specifying the number of seconds left until it expires (This is used for kick as well…).',
  '40' => 'Protocol error',
  '41' =>
qq{Transfer protocol unsupported, flag "TO" the token, flag "PR" the protocol string. The client receiving a CTM or RCM should send this if it doesn't support the C-C protocol. },
  '42' =>
qq{Direct connection failed, flag "TO" the token, flag "PR" the protocol string. The client receiving a CTM or RCM should send this if it tried but couldn't connect. },
  '43' => 'Required INF field missing/bad, flag "FM" specifies missing field, "FB" specifies invalid field.',
  '44' => 'Invalid state, flag "FC" the FOURCC of the offending command.',
  '45' => 'Required feature missing, flag "FC" specifies the FOURCC of the missing feature.',
  '46' => 'Invalid IP supplied in INF, flag "I4" or "I6" specifies the correct IP.',
  '47' => 'No hash support overlap in SUP between client and hub.',
  '50' => 'Client-client / file transfer error',
  '51' => 'File not available',
  '52' => 'File part not available',
  '53' => 'Slots full',
  '54' => 'No hash support overlap in SUP between clients.',
);
eval "use MIME::Base32 qw( RFC ); 1;"        or print join ' ', ( 'err', 'cant use', $@ );
eval "use Net::DirectConnect::TigerHash; 1;" or print join ' ', ( 'err', 'cant use', $@ );
sub base32 ($) { MIME::Base32::encode( $_[0] ); }

sub tiger ($) {
  local ($_) = @_;
  #use Mhash qw( mhash mhash_hex MHASH_TIGER);
  #eval "use MIME::Base32 qw( RFC ); use Digest::Tiger;" or $self->log('err', 'cant use', $@);
  #$_.=("\x00"x(1024 - length $_));        print ( 'hlen', length $_);
  #Digest::Tiger::hash($_);
  eval { Net::DirectConnect::TigerHash::tthbin($_); }
    #mhash(Mhash::MHASH_TIGER, $_);
}
sub hash ($) { base32( tiger( $_[0] ) ); }

sub init {
  my $self = shift;
  #print "SELF=", $self, "REF=", ref $self, "P=", @_, "\n\n";
  %$self = (
    %$self,
    'Nick'     => 'NetDCBot',
    'port'     => 412,
    'host'     => 'localhost',
    'protocol' => 'adc',
    #'Pass' => '',
    #'key'  => 'zzz',
    #'auto_wait'        => 1,
    'search_every' => 10, 'search_every_min' => 10, 'auto_connect' => 1,
    #ADC
    'connect_protocol' => 'ADC/0.10', 'message_type' => 'H', @_, 'incomingclass' => __PACKAGE__,    #'Net::DirectConnect::adc',
    'periodic' => sub { $self->cmd( 'search_buffer', ) if $self->{'socket'}; },
    no_print => { 'INF' => 1, 'QUI' => 1, 'SCH' => 1, },
  );
  #$self->log( $self, 'inited', "MT:$self->{'message_type'}", ' with', Dumper \@_ );
  $self->baseinit();    #if ref $self eq __PACKAGE__;
  #$self->log( $self, 'inited3', "MT:$self->{'message_type'}", ' with' );
  if ( $self->{'hub'} ) {
    $self->{'auto_connect'} = 0;
    $self->{'auto_listen'}  = 1;
    $self->{'status'}       = 'working';
  }
  $self->{$_} ||= $self->{'parent'}{$_} || {} for qw(peers peers_sid peers_id want);
  $self->{'parse'} ||= {
#
#=================
#ADC dev
#
#'ISUP' => sub { }, 'ISID' => sub { $self->{'sid'} = $_[0] }, 'IINF' => sub { $self->cmd('BINF') },    'IQUI' => sub { },    'ISTA' => sub { $self->log( 'dcerr', @_ ) },
    'SUP' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #for my $feature (split /\s+/, $_[0])
      $self->log( 'adcdev', $dst, 'SUP:', @_ );
      #=z
      #if $self->{''}
      if ( $dst eq 'H' ) {
        $self->cmd( 'I', 'SUP' );
        #$peerid ||= join '', map {} 1..4
        $peerid ||= base32( $self->{'number'} + int rand 100 );
        $peerid = ( 'A' x ( 4 - length $peerid ) ) . $peerid;
        $self->{'peerid'} ||= $peerid;
        $self->cmd( 'I', 'SID', $peerid );
        $self->cmd( 'I', 'INF', );    #$self->{'peers'}{$_}{'INF'}
        #for keys %{$self->{'peers'}};
        $self->{'status'} = 'connected';
      }
      $peerid ||= '';
      for ( $self->adc_strings_decode(@_) ) {
        if   ( (s/^(AD|RM)//)[0] eq 'RM' ) { delete $self->{'peers'}{$peerid}{'SUP'}{$_}; }
        else                               { $self->{'peers'}{$peerid}{'SUP'}{$_} = 1; }
      }
      #=cut

=z
      my $params = $self->adc_parse_named(@_);
      for ( keys %$params ) {
        delete $self->{'peers'}{$peerid}{'SUP'}{ $params->{$_} } if $_ eq 'RM';
        $self->{'peers'}{$peerid}{'SUP'}{ $params->{$_} } = 1 if $_ eq 'AD';
      }
=cut      

      return $self->{'peers'}{$peerid}{'SUP'};
    },
    'SID' => sub {
      my $self = shift if ref $_[0];
      $self->{'sid'} = $_[1];
      $self->log( 'adcdev', 'SID:', $self->{'sid'} );
      return $self->{'sid'};
    },
    'INF' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #test $_[1] eq 'I'!
      #$self->log('adcdev', '0INF:', "[d=$dst,p=$peerid]", join ':', @_);
      my $params = $self->adc_parse_named(@_);
      #for (@_) {
      #s/^(\w\w)//;
      #my ($code)= $1;
      #$self->log('adcdev', 'INF:', $peerid,  Dumper $params);
      #$self->{'peers'}{$peerid}{'INF'}{$code} = $_;
      #}
      my $peersid = $peerid;
      if ( $dst ne 'B' and $peerid ||= $params->{ID} ) {
        $self->{'peerid'} ||= $peerid;
        $self->{'peers'}{$peerid}{$_} = $self->{'peers'}{''}{$_} for keys %{ $self->{'peers'}{''} || {} };
        delete $self->{'peers'}{''};
      }
      my $sendbinf;
      if ( $dst eq 'B' ) {
        if ( !keys %{ $self->{'peers'}{$peerid}{'INF'} } ) {    #join
          ++$sendbinf;
          #$self->log( 'adcdev', 'FIRSTINF:', $peerid, Dumper $params, $self->{'peers'} );
          #$self->cmd( 'B', 'INF', $_, $self->{'peers_sid'}{$_}{'INF'} ) for keys %{ $self->{'peers_sid'} };
        }
      }
      $self->{'peers'}{$peerid}{'INF'}{$_} = $params->{$_} for keys %$params;
      $self->{'peers'}{ $params->{ID} }                             ||= $self->{'peers'}{$peerid};
      $self->{'peers'}{$peerid}{'SID'}                              ||= $peersid;
      $self->{'peers_sid'}{$peersid}                                ||= $self->{'peers'}{$peerid};
      $self->{'peers_id'}{ $self->{'peers'}{$peerid}{'INF'}{'ID'} } ||= $self->{'peers'}{$peerid};
      #$self->log( 'adcdev', 'INF:', $peerid, Dumper $params, $self->{'peers'} ) unless $peerid;
      if ( $dst eq 'I' ) {
        $self->cmd( 'B', 'INF' );
        $self->{'status'} = 'connected';    #clihub
      } elsif ( $dst eq 'C' ) {
        $self->{'status'} = 'connected';    #clicli
        $self->cmd( $dst, 'INF' );
        if   ( $params->{TO} ) { }
        else                   { }
        $self->cmd('file_select');
        $self->cmd( $dst, 'GET' );
      }
      if ($sendbinf) { $self->cmd( 'B', 'INF', $_, $self->{'peers_sid'}{$_}{'INF'} ) for keys %{ $self->{'peers_sid'} }; }
      $self->cmd_all( $dst, 'INF', $peerid, @_ );
      return $self->{'peers'}{$peerid}{'INF'};
    },
    'QUI' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #$peerid
      #$self->log( 'adcdev', 'QUI', $dst, $_[0], Dumper $self->{'peers'}{ $_[0] } );
      delete $self->{'peers_id'}{ $self->{'peers'}{$peerid}{'INF'}{'ID'} };
      delete $self->{'peers_sid'}{$peerid};
      delete $self->{'peers'}{$peerid};    # or mark time
    },
    'STA' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #$self->log( 'dcerr', @_ );
      my $code = shift;
      $code =~ s/^(.)//;
      my $severity = $1;
#TODO: $severity :
#0 	Success (used for confirming commands), error code must be "00", and an additional flag "FC" contains the FOURCC of the command being confirmed if applicable.
#1 	Recoverable (error but no disconnect)
#2 	Fatal (disconnect)
#my $desc = $self->{'codesSTA'}{$code};
      @_ = $self->adc_strings_decode(@_);
      $self->log( 'adcdev', 'STA', $peerid, $severity, $code, @_, "=[$Net::DirectConnect::adc::codesSTA{$code}]" );
      return $severity, $code, $Net::DirectConnect::adc::codesSTA{$code}, @_;
    },
    'SCH' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid, @feature ) = @{ shift() };
      #$self->log( 'adcdev', 'SCH', ( $dst, $peerid, 'F=>', @feature ), 'S=>', @_ );
      $self->cmd_all( $dst, 'SCH', $peerid, @feature, @_ );
      my $params = $self->adc_parse_named(@_);
      #DRES J3F4 KULX SI0 SL57 FN/Joculete/logs/stderr.txt TRLWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ TOauto
      if (  $self->{'share_tth'}
        and $params->{TR}
        and exists $self->{'share_tth'}{ $params->{TR} }
        and -s $self->{'share_tth'}{ $params->{TR} } )
      {
        $self->log(
          'adcdev', 'SCH',
          ( $dst, $peerid, 'F=>', @feature ),
          $self->{'share_tth'}{ $params->{TR} },
          -s $self->{'share_tth'}{ $params->{TR} },
          -e $self->{'share_tth'}{ $params->{TR} }
        );
        local @_ = (
          $peerid, {
            SI => ( -s $self->{'share_tth'}{ $params->{TR} } ) || -1,
            SL => $self->{INF}{SL},
            FN => $self->adc_path_encode( $self->{'share_tth'}{ $params->{TR} } ),
            TO => $params->{TO}                                || $self->make_token($peerid),
            TR => $params->{TR}
          }
        );
        if ( $self->{'peers'}{$peerid}{INF}{I4} and $self->{'peers'}{$peerid}{INF}{U4} ) {
          $self->log(
            'dcdev', 'SCH', 'i=', $self->{'peers'}{$peerid}{INF}{I4},
            'u=', $self->{'peers'}{$peerid}{INF}{U4},
            'T==>', 'U' . 'RES' . $self->adc_make_string(@_)
          );
          $self->send_udp(
            $self->{'peers'}{$peerid}{INF}{I4},
            $self->{'peers'}{$peerid}{INF}{U4},
            'U' . 'RES ' . $self->adc_make_string(@_)
          );
        } else {
          $self->cmd( 'D', 'RES', @_ );
        }
      }
      #$self->adc_make_string(@_);
      #TODO active send udp
      return $params;
      #TRKU2OUBVHC3VXUNOHO2BS2G4ECHYB6ESJUQPYFSY TO626120869 ]
      #TRQYKHJIZEPSISFF3T25DIGKEYI645Y7PGMSI7QII TOauto ]
      #ANthe ANhossboss TO3951841973 ]
      #FSCH ABWN +TCP4 TRKX55JDOFEBX32GLBSITTSY6KUCK4NMPU2R4XUII TOauto
    },
    'RES' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #test $_[1] eq 'I'!
      #$self->log('adcdev', '0INF:', "[d=$dst,p=$peerid]", join ':', @_);
      my $params = $self->adc_parse_named(@_);
      #$self->log('adcdev', 'RES:',"[d=$dst,p=$peerid]",Dumper $params);
      $params;
    },
    'MSG' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid ) = @{ shift() };
      #@_ = map {adc_string_decode} @_;
      $self->cmd_all( $dst, 'MSG', $peerid, @_ );
      @_ = $self->adc_strings_decode(@_);
      $self->log( 'adcdev', $dst, 'MSG', $peerid, "<" . $self->{'peers'}{$peerid}{'INF'}{'NI'} . '>', @_ );
      @_;
    },
    'RCM' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid, $toid ) = @{ shift() };
      $self->log( 'dcdev', "( $dst, RCM, $peerid, $toid )", @_ );
      $self->cmd( $dst, 'CTM', $peerid, $_[0], $self->{'myport'}, $_[1], ) if $toid eq $self->{'sid'};

=z      
       $self->{'clients'}{ $host . ':' . $port } = Net::DirectConnect::clicli->new(
        %$self, $self->clear(),
        'host'         => $host,
        'port'         => $port,
#'want'         => \%{ $self->{'want'} },
#'NickList'     => \%{ $self->{'NickList'} },
#'IpList'       => \%{ $self->{'IpList'} },
#'PortList'     => \%{ $self->{'PortList'} },
#'handler'      => \%{ $self->{'handler'} },
        'auto_connect' => 1,
      );
=cut

    },
    'CTM' => sub {
      my $self = shift if ref $_[0];
      my ( $dst,   $peerid, $toid )  = @{ shift() };
      my ( $proto, $port,   $token ) = @_;
      my $host = $self->{'peers'}{$peerid}{'INF'}{'I4'};
      $self->log( 'dcdev', "( $dst, CTM, $peerid, $toid ) - ($proto, $port, $token)", );
      $self->log( 'dcerr', 'CTM: unknown host', "( $dst, CTM, $peerid, $toid ) - ($proto, $port, $token)" ) unless $host;
      $self->{'clients'}{ $self->{'peers'}{$peerid}{'INF'}{ID} or $host . ':' . $port } = Net::DirectConnect::adc->new(
        %$self, $self->clear(),
        'host' => $host,
        'port' => $port,
        #'parse' => $self->{'parse'},
        #'cmd'   => $self->{'cmd'},
        #'want'  => $self->{'want'},
        #'want'         => \%{ $self->{'want'} },
        #'NickList'     => \%{ $self->{'NickList'} },
        #'IpList'       => \%{ $self->{'IpList'} },
        #'PortList'     => \%{ $self->{'PortList'} },
        #'handler'      => \%{ $self->{'handler'} },
        #'TO' => $token,
        'INF'          => { %{ $self->{'INF'} }, 'TO' => $token },
        'message_type' => 'C',
        'auto_connect' => 1,
      );
    },
    'SND' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid, $toid ) = @{ shift() };
      #CSND file files.xml.bz2 0 6117
      $self->{'filetotal'} = $_[3];
      return $self->file_open();
    },
    #CGET file TTH/YDIXOH7A3W233WTOQUET3JUGMHNBYNFZ4UBXGNY 637534208 6291456
    'GET' => sub {
      my $self = shift if ref $_[0];
      my ( $dst, $peerid, $toid ) = @{ shift() };
      $self->file_send_parse(@_);

=z
      if ( $_[0] eq 'file' ) {
        my $file = $_[1];
        if ( $file =~ s{^TTH/}{} ) { $self->file_send_tth( $file, $_[2], $_[3] ); }
        else {
          #$self->file_send($file, $_[2], $_[3]);
        }
      } else {
        $self->log( 'dcerr', 'SND', "unknown type", @_ );
      }
=cut

    },
  };

=COMMANDS








=cut  

  $self->{'cmd'} = {
    #move to main
    'search_buffer' => sub {
      my $self = shift if ref $_[0];
      push( @{ $self->{'search_todo'} }, [@_] ) if @_;
      return unless @{ $self->{'search_todo'} || return };
#$self->log($self, 'search', Dumper \@_);
#$self->log( 'dcdev', "search too fast [$self->{'search_every'}], len=", scalar @{ $self->{'search_todo'} } )        if @_ and scalar @{ $self->{'search_todo'} } > 1;
      return if time() - $self->{'search_last_time'} < $self->{'search_every'} + 2;
      $self->{'search_last'} = shift( @{ $self->{'search_todo'} } );
      $self->{'search_todo'} = undef unless @{ $self->{'search_todo'} };
      if ( $self->{'adc'} ) { $self->cmd_adc( 'B', 'SCH', @{ $self->{'search_last'} } ); }
      else {
#$self->sendcmd( 'Search', $self->{'M'} eq 'P' ? 'Hub:' . $self->{'Nick'} : "$self->{'myip'}:$self->{'myport_udp'}", join '?', @{ $self->{'search_last'} } );
        $self->sendcmd(
          'Search',
          ( ( $self->{'myip'} && $self->{'myport_udp'} ) ? "$self->{'myip'}:$self->{'myport_udp'}" : 'Hub:' . $self->{'Nick'} ),
          join '?',
          @{ $self->{'search_last'} }
        );
      }
      $self->{'search_last_time'} = time();
    },
    'search_tth' => sub {
      my $self = shift if ref $_[0];
      $self->{'search_last_string'} = undef;
      if ( $self->{'adc'} ) { $self->cmd( 'search_buffer', { TO => $self->make_token(), TR => $_[0], } ); }    #toauto
      else                  { $self->cmd( 'search_buffer', 'F', 'T', '0', '9', 'TTH:' . $_[0] ); }
    },
    'search_string' => sub {
      my $self = shift if ref $_[0];
      my $string = $_[0];
      if ( $self->{'adc'} ) {
        #$self->cmd( 'search_buffer', { TO => 'auto', map AN => $_, split /\s+/, $string } );
        $self->cmd( 'search_buffer', ( map { 'AN' . $_ } split /\s+/, $string ), { TO => $self->make_token(), } );    #TOauto
      } else {
        $self->{'search_last_string'} = $string;
        $string =~ tr/ /$/;
        $self->cmd( 'search_buffer', 'F', 'T', '0', '1', $string );
      }
    },
    'search' => sub {
      my $self = shift if ref $_[0];
      return $self->cmd( 'search_tth', @_ ) if length $_[0] == 39 and $_[0] =~ /^[0-9A-Z]+$/;
      return $self->cmd( 'search_string', @_ ) if length $_[0];
    },
    'search_retry' => sub {
      my $self = shift if ref $_[0];
      unshift( @{ $self->{'search_todo'} }, $self->{'search_last'} ) if ref $self->{'search_last'} eq 'ARRAY';
      $self->{'search_last'} = undef;
    },
    'make_hub' => sub {
      my $self = shift if ref $_[0];
      $self->{'hub'} ||= $self->{'host'} . ( ( $self->{'port'} and $self->{'port'} != 411 ) ? ':' . $self->{'port'} : '' );
    },
    'nick_generate' => sub {
      my $self = shift if ref $_[0];
      $self->{'nick_base'} ||= $self->{'Nick'};
      $self->{'Nick'} = $self->{'nick_base'} . int( rand( $self->{'nick_random'} || 100 ) );
    },
    #
    #=================
    #ADC dev
    #
    'connect_aft' => sub {
      #print "RUNADC![$self->{'protocol'}:$self->{'adc'}]";
      my $self = shift if ref $_[0];
      #$self->log($self, 'connect_aft inited',"MT:$self->{'message_type'}", ' ');
      $self->cmd( $self->{'message_type'}, 'SUP' ) if $self->{'adc'};
    },
    'cmd_all' => sub {
      my $self = shift if ref $_[0];
      return if ( $_[0] ne 'B' and $_[0] ne 'F' ) or !$self->{'parent'}{'hub'};
      $self->{'parent'}->sendcmd_all(@_);    #for keys %{ $self->{'peers_sid'} };
    },
    'SUP' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->log($self, 'SUP inited',"MT:$self->{'message_type'}", "=== $dst");
      $self->{'SUPADS'} ||= [qw(BASE TIGR PING)] if $dst eq 'I';
      $self->{'SUPADS'} ||= [qw(BAS0 BASE TIGR UCM0 BLO0 BZIP )];    #PING ZLIG
      $self->{'SUPRMS'} ||= [qw()];
      $self->{'SUP'} ||= { ( map { $_ => 1 } @{ $self->{'SUPADS'} } ), ( map { $_ => 0 } @{ $self->{'SUPRMS'} } ) };
      #$self->{'SUPAD'} ||= { map { $_ => 1 } @{ $self->{'SUPADS'} } };
      $self->cmd_adc                                                 #sendcmd
        ( $dst, 'SUP', ( map { 'AD' . $_ } @{ $self->{'SUPADS'} } ), ( map { 'RM' . $_ } keys %{ $self->{'SUPRM'} } ), );
      #ADBAS0 ADBASE ADTIGR ADUCM0 ADBLO0
    },
    'INF' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->{'BINFS'} ||= [qw(ID PD I4 I6 U4 U6 SS SF VE US DS SL AS AM EM NI DE HN HR HO TO CT AW SU RF)];
      if ( $dst eq 'I' ) {
        $self->{'INF'} = { CT => 32, VE => 'perl' . $VERSION, NI => 'devhub', DE => 'hubdev', };
#IINF CT32 VEuHub/0.3.0-rc4\s(git:\sd2da49d...) NI"??????????\s?3\\14?" DE?????,\s??????,\s?????????.\s???\s????????\s-\s???\s????????.
      } elsif ( $dst eq 'B' ) {
        $self->cmd_adc                                               #sendcmd
          (
          $dst, 'INF',                                               #$self->{'sid'},
          @_,
          #map { $_ . $self->{'INF'}{$_} } $dst eq 'C' ? qw(ID TO) : sort keys %{ $self->{'INF'} }
          );
        return;
      } else {
        $self->{'INF'}{'NI'} ||= $self->{'Nick'} || 'perlAdcDev';
        #eval "use MIME::Base32 qw( RFC );  use Digest::Tiger;" or $self->log( 'err', 'cant use', $@ );

=z
      eval "use MIME::Base32 qw( RFC ); 1;"        or $self->log( 'err', 'cant use', $@ );
      eval "use Net::DirectConnect::TigerHash; 1;" or $self->log( 'err', 'cant use', $@ );
      sub base32 ($) { MIME::Base32::encode( $_[0] ); }
      sub hash ($)   { base32( tiger( $_[0] ) ); }

      sub tiger ($) {
        local ($_) = @_;
        #use Mhash qw( mhash mhash_hex MHASH_TIGER);
        #eval "use MIME::Base32 qw( RFC ); use Digest::Tiger;" or $self->log('err', 'cant use', $@);
        #$_.=("\x00"x(1024 - length $_));        print ( 'hlen', length $_);
        #Digest::Tiger::hash($_);
      eval{  Net::DirectConnect::TigerHash::tthbin($_);}	
        #mhash(Mhash::MHASH_TIGER, $_);
      }
=cut

        #$self->log('tiger of NULL is', hash(''));#''=      LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ
        #
        $self->{'PID'} ||= MIME::Base32::decode $self->{'INF'}{'PD'} if $self->{'INF'}{'PD'};
        $self->{'CID'} ||= MIME::Base32::decode $self->{'INF'}{'ID'} if $self->{'INF'}{'ID'};
        $self->{'ID'}  ||= 'perl' . $self->{'myip'} . $self->{'INF'}{'NI'};
        $self->{'PID'} ||= tiger $self->{'ID'};
        $self->{'CID'} ||= tiger $self->{'PID'};
        $self->{'INF'}{'PD'} ||= base32 $self->{'PID'};
        $self->{'INF'}{'ID'} ||= base32 $self->{'CID'};
        $self->{'INF'}{'SL'} ||= $self->{'S'} || '2';
        $self->{'INF'}{'SS'} ||= $self->{'sharesize'} || 20025693588;
        $self->{'INF'}{'SF'} ||= 30999;
        $self->{'INF'}{'HN'} ||= $self->{'H'} || 1;
        $self->{'INF'}{'HR'} ||= $self->{'R'} || 0;
        $self->{'INF'}{'HO'} ||= $self->{'O'} || 0;
        $self->{'INF'}{'VE'} ||= $self->{'client'} . $self->{'V'}
          || 'perl' . $VERSION;    #. '_' . ( split( ' ', '$Revision$' ) )[1];    #'++\s0.706';
        $self->{'INF'}{'US'} ||= 10000;
        $self->{'INF'}{'U4'} ||= $self->{'myport_udp'};
        $self->{'INF'}{'I4'} ||= $self->{'myip'};
        $self->{'INF'}{'SU'} ||= 'ADC0,TCP4,UDP4';
     #$self->{''} ||= $self->{''} || '';
     #$self->sendcmd( $dst, 'INF', $self->{'sid'}, map { $_ . $self->{$_} } grep { length $self->{$_} } @{ $self->{'BINFS'} } );
      }
      $self->cmd_adc               #sendcmd
        (
        $dst, 'INF',               #$self->{'sid'},
        map { $_ . $self->{'INF'}{$_} } $dst eq 'C' ? qw(ID TO) : sort keys %{ $self->{'INF'} }
        );
      #grep { length $self->{$_} } @{ $self->{'BINFS'} } );
      #$self->cmd_adc( $dst, 'INF', $self->{'sid'}, map { $_ . $self->{$_} } grep { $self->{$_} } @{ $self->{'BINFS'} } );
      #BINF UUXX IDFXC3WTTDXHP7PLCCGZ6ZKBHRVAKBQ4KUINROXXI PDP26YAWX3HUNSTEXXYRGOIAAM2ZPMLD44HCWQEDY NIïûðûî SL2 SS20025693588
      #SF30999 HN2 HR0 HO0 VE++\s0.706 US5242 SUADC0
    },
    'GET' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->sendcmd( $dst, 'CTM', $self->{'connect_protocol'},@_);
      local @_ = @_;
      if ( !@_ ) {
        @_ = ( 'file', $self->{'filename'}, '0', '-1' ) if $self->{'filename'};
        $self->log( 'err', "Nothing to get" ), return unless @_;
      }
      $self->cmd_adc( $dst, 'GET', @_ );
    },
  };

=auto    
      'CTM' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->sendcmd( $dst, 'CTM', $self->{'connect_protocol'},@_);
      $self->cmd_adc( $dst, 'CTM', @_ );
    },
     'RCM' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->sendcmd( $dst, 'CTM', $self->{'connect_protocol'},@_);
      $self->cmd_adc( $dst, 'RCM', @_ );
    },
    'SND' => sub {
      my $self = shift if ref $_[0];
      my $dst = shift;
      #$self->sendcmd( $dst, 'CTM', $self->{'connect_protocol'},@_);
      $self->cmd_adc( $dst, 'SND', @_ );
    },
=cut    

  #$self->log( 'dev', "0making listeners [$self->{'M'}]" );
  if ( ( $self->{'M'} eq 'A' or !$self->{'M'} ) and !$self->{'auto_listen'} and !$self->{'incoming'} ) {
    $self->log( 'dev', "making listeners: tcp" );
    $self->{'clients'}{'listener_tcp'} = $self->{'incomingclass'}->new(
      #%$self, $self->clear(),
      #'want' => $self->{'want'},
      #'NickList'    => \%{ $self->{'NickList'} },
      #'IpList'      => \%{ $self->{'IpList'} },
      #'PortList'    => \%{ $self->{'PortList'} },
      #'handler'     => \%{ $self->{'handler'} },
      'parent' => $self, 'auto_listen' => 1,
      #'myport'        => $self->{'myport'},
      ( map { $_ => $self->{$_} } qw(myport want peers ) ),
    );
    $self->{'myport'} = $self->{'myport_tcp'} = $self->{'clients'}{'listener_tcp'}{'myport'};
    $self->log( 'err', "cant listen tcp (file transfers)" ) unless $self->{'myport_tcp'};
    $self->log( 'dev', "making listeners: udp" );
    $self->{'clients'}{'listener_udp'} = $self->{'incomingclass'}->new(
      #%$self, $self->clear(),
      'parent' => $self, 'Proto' => 'udp',
      #?    'want'     => \%{ $self->{'want'} },
      #?    'NickList' => \%{ $self->{'NickList'} },
      #?    'IpList'   => \%{ $self->{'IpList'} },
      #?    'PortList' => \%{ $self->{'PortList'} },
      #'handler' => \%{ $self->{'handler'} },
      #$self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, $self->clear(),
      #'LocalPort'=>$self->{'myport'},
      #'debug'=>1,
      #'nonblocking' => 0,
      'NONONOparse' => {
        'SR'  => $self->{'parse'}{'SR'},
        'PSR' => sub {                     #U
          #$self->log( 'dev', "UPSR", @_ );
        },
#2008/12/14-13:30:50 [3] rcv: welcome UPSR FQ2DNFEXG72IK6IXALNSMBAGJ5JAYOQXJGCUZ4A NIsss2911 HI81.9.63.68:4111 U40 TRZ34KN23JX2BQC2USOTJLGZNEWGDFB327RRU3VUQ PC4 PI0,64,92,94,100,128,132,135 RI64,65,66,67,68,68,69,70,71,72
#UPSR CDARCZ6URO4RAZKK6NDFTVYUQNLMFHS6YAR3RKQ NIAspid HI81.9.63.68:411 U40 TRQ6SHQECTUXWJG5ZHG3L322N5B2IV7YN2FG4YXFI PC2 PI15,17,20,128 RI128,129,130,131
#$SR [Predator]Wolf DC++\Btyan Adams - Please Forgive Me.mp314217310 18/20TTH:G7DXSTGPHTXSD2ZZFQEUBWI7PORILSKD4EENOII (81.9.63.68:4111)
#2008/12/14-13:30:50 welcome UPSR FQ2DNFEXG72IK6IXALNSMBAGJ5JAYOQXJGCUZ4A NIsss2911 HI81.9.63.68:4111 U40 TRZ34KN23JX2BQC2USOTJLGZNEWGDFB327RRU3VUQ PC4 PI0,64,92,94,100,128,132,135 RI64,65,66,67,68,68,69,70,71,72
#UPSR CDARCZ6URO4RAZKK6NDFTVYUQNLMFHS6YAR3RKQ NIAspid HI81.9.63.68:411 U40 TRQ6SHQECTUXWJG5ZHG3L322N5B2IV7YN2FG4YXFI PC2 PI15,17,20,128 RI128,129,130,131
#$SR [Predator]Wolf DC++\Btyan Adams - Please Forgive Me.mp314217310 18/20TTH:G7DXSTGPHTXSD2ZZFQEUBWI7PORILSKD4EENOII (81.9.63.68:4111)
      },
      'auto_listen' => 1,
    );
    $self->{'myport_udp'} = $self->{'clients'}{'listener_udp'}{'myport'};
    $self->log( 'err', "cant listen udp (search repiles)" ) unless $self->{'myport_udp'};
  }
  #DEV=z
  if ( $self->{'dev_http'} ) {
    $self->log( 'dev', "making listeners: http" );
    #$self->{'clients'}{'listener_http'} = Net::DirectConnect::http->new(
    $self->{'clients'}{'listener_http'} = Net::DirectConnect->new(
      #%$self, $self->clear(),
      #'want'     => \%{ $self->{'want'} },
      #'NickList' => \%{ $self->{'NickList'} },
      #'IpList'   => \%{ $self->{'IpList'} },
##      'PortList' => \%{ $self->{'PortList'} },
      #'handler'  => \%{ $self->{'handler'} },
      #$self->{'clients'}{''} = $self->{'incomingclass'}->new( %$self, $self->clear(),
      #'LocalPort'=>$self->{'myport'},
      #'debug'=>1,
      #@_,
      'incomingclass' => 'Net::DirectConnect::http', 'auto_connect' => 0, 'auto_listen' => 1,
      #'auto_listen' => 1,
      #'HubName'       => 'Net::DirectConnect test hub',
      #'myport'        => 80,
      'myport' => 8000, 'myport_base' => 8000, 'myport_random' => 99, 'myport_tries' => 5, 'parent' => $self,
      #'auto_listen' => 0,
    );
    $self->{'myport_http'} = $self->{'clients'}{'listener_http'}{'myport'};
    $self->log( 'err', "cant listen http" ) unless $self->{'myport_http'};
  }
  #=cut
  $self->{'handler_int'}{'disconnect_bef'} = sub {
    delete $self->{'sid'};
    #$self->log( 'dev', 'disconnect int', psmisc::caller_trace(30) );
  };
}
1;
