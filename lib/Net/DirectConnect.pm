#$Id$ $URL$
package Net::DirectConnect;
use strict;
no warnings qw(uninitialized);
use Socket;
use IO::Socket;
use IO::Select;
use POSIX;
use Time::HiRes qw(time);
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
our $VERSION = '0.03' . '_' . ( split( ' ', '$Revision$' ) )[1];
our $AUTOLOAD;
our %global;
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
'Temporarily banned, flag "TL" is an integer specifying the number of seconds left until it expires (This is used for kick as well�).',
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

sub float {    #v1
  my $self = shift;
  return ( $_[0] < 8 and $_[0] - int( $_[0] ) )
    ? sprintf( '%.' . ( $_[0] < 1 ? 3 : ( $_[0] < 3 ? 2 : 1 ) ) . 'f', $_[0] )
    : int( $_[0] );
}

sub clear {
  return map { $_ => undef } qw(
    clients
    socket
    select
    accept
    filehandle
    parse
    cmd
    number
    send_buffer
    databuf
    buf
    peers
  );
}

sub new {
  my $class = shift;
  my @param = @_;
  my $self  = {
    'Listen'      => 10,
    'Timeout'     => 5,
    'myport'      => 412,                                                   #first try
    'myport_base' => 40000, 'myport_random' => 1000, 'myport_tries' => 5,
    #http://www.dcpp.net/wiki/index.php/%24MyINFO
    'description' => 'just perl Net::DirectConnect bot', 'connection' => 'LAN(T3)',
    #NMDC1: 28.8Kbps, 33.6Kbps, 56Kbps, Satellite, ISDN, DSL, Cable, LAN(T1), LAN(T3)
    #NMDC2: Modem, DSL, Cable, Satellite, LAN(T1), LAN(T3)
    'flag' => '1',                                                          # User status as ascii char (byte)
    #1 normal
    #2, 3 away
    #4, 5 server               The server icon is used when the client has
    #6, 7 server away          uptime > 2 hours, > 2 GB shared, upload > 200 MB.
    #8, 9 fireball             The fireball icon is used when the client
    #10, 11 fireball away      has had an upload > 100 kB/s.
    'email' => 'billgates@microsoft.com', 'sharesize' => 10 * 1024 * 1024 * 1024,    #10GB
    'client'   => 'perl',    #'dcp++',                                                              #++: indicates the client
    'protocol' => 'nmdc',    # or 'adc'
    'cmd_sep' => ' ', 'V' => $VERSION , #. '_' . ( split( ' ', '$Revision$' ) )[1],    #V: tells you the version number
    #'M' => 'A',      #M: tells if the user is in active (A), passive (P), or SOCKS5 (5) mode
    'H' => '0/1/0'
    , #H: tells how many hubs the user is on and what is his status on the hubs. The first number means a normal user, second means VIP/registered hubs and the last one operator hubs (separated by the forward slash ['/']).
    'S' => '3',      #S: tells the number of slots user has opened
    'O' => undef,    #O: shows the value of the "Automatically open slot if speed is below xx KiB/s" setting, if non-zero
    'lock'               => 'EXTENDEDPROTOCOLABCABCABCABCABCABC Pk=DCPLUSPLUS0.668ABCABC',
    'log'                => sub { my $self = shift; print( join( ' ', "($self)[$self->{'number'}]", @_ ), "\n" ) },
    'auto_recv'          => 1,
    'max_reads'          => 20,
    'wait_once'          => 0.1,
    'waits'              => 100,
    'wait_finish_tries'  => 600,
    'wait_finish_by'     => 1,
    'wait_connect'       => 600,
    'clients_max'        => 50,
    'wait_clients_tries' => 200,
    'wait_clients_by'    => 0.01,
    'work_sleep'         => 0.01,
    'cmd_recurse_sleep'  => 0,
    ( $^O eq 'MSWin32' ? () : ( 'nonblocking' => 1 ) ),
    'informative'          => [qw(number peernick status host port filebytes filetotal proxy)],    # sharesize
    'informative_hash'     => [qw(clients)],                                                       #NickList IpList PortList
    'disconnect_recursive' => 1,
    'no_print'             => { map { $_ => 1 } qw(Search Quit MyINFO Hello SR UserCommand) },
    'reconnects'           => 5,
    'reconnect_sleep'      => 5,
    'partial_ext'          => '.partial',
    #'partial_prefix' => './partial/',
    #ADC
  };
  eval { $self->{'recv_flags'} = MSG_DONTWAIT; } unless $^O =~ /win/i;
  $self->{'recv_flags'} ||= 0;
  bless( $self, $class );
  $self->func(@param);
  $self->init(@param);
  if ( $self->{'auto_listen'} ) { $self->listen(); }
  elsif ( $self->{'auto_connect'} ) {
    $self->log( $self, 'new inited', "MT:$self->{'message_type'}", ' with' );
    $self->connect();
    $self->work();
  }
  return $self;
}

sub log(@) {
  my $self = shift;
  return $self->{'log'}->( $self, @_ ) if ref $self->{'log'} eq 'CODE';
  print( join( ' ', "[$self->{'number'}]", @_ ), "\n" );
}

sub cmd {
  my $self = shift;
  my $dst;
  $dst =    #$_[0]
    shift if $self->{'adc'} and length $_[0] == 1;
  my $cmd = shift;
  my ( @ret, $ret );
  #$self->{'log'}->($self,'dev', 'cmd', $cmd, @_) if $cmd ne 'log';
  #$self->{'log'}->($self,'dev', $self->{number},'cmd', $cmd, @_) if $cmd ne 'log';
  my ( $func, $handler );
  if ( ref $self->{'cmd'}{$cmd} eq 'CODE' ) {
    $func    = $self->{'cmd'}{$cmd};
    $handler = '_cmd';
    unshift @_, $dst if $dst;
  } elsif ( ref $self->{$cmd} eq 'CODE' ) {
    $func = $self->{$cmd};
  } elsif ( ref $self->{'cmd'}{ $dst . $cmd } eq 'CODE' ) {
    $func    = $self->{'cmd'}{ $dst . $cmd };
    $handler = '_cmd';
    #unshift @_, $dst if $dst;
  }
  $self->handler( $cmd . $handler . '_bef_bef', \@_ );
  if ( $self->{'min_cmd_delay'} and ( time - $self->{'last_cmd_time'} < $self->{'min_cmd_delay'} ) ) {
    $self->log( 'dbg', 'sleepcmd', $self->{'min_cmd_delay'} - time + $self->{'last_cmd_time'} );
    sleep( $self->{'min_cmd_delay'} - time + $self->{'last_cmd_time'} );
  }
  $self->{'last_cmd_time'} = time;
  $self->handler( $cmd . $handler . '_bef', \@_ );
  #$self->{'log'}->($self,'dev', $self->{number},'cmdrun', $cmd, @_, $func) if $cmd ne 'log';
  if ($func) {
    @ret = $func->( $self, @_ );    #$self->{'cmd'}{$cmd}->(@_);
  } elsif ( exists $self->{$cmd} ) {
    $self->log( 'dev', "cmd call by var name $cmd=$self->{$cmd}" );
    @ret = ( $self->{$cmd} );
  } elsif ($self->{'adc'} and  length $dst == 1 and length $cmd == 3 ) {
    @ret = $self->cmd_adc( $dst, $cmd, @_ );
  } else {
    $self->log(
      'info',
      "UNKNOWN CMD:[$cmd]{@_} : please add \$dc->{'cmd'}{'$cmd'} = sub { ... };",
      Dumper $self->{'cmd'},
      $self->{'parse'}
    );
    $self->{'cmd'}{$cmd} = sub { };
  }
  $ret = scalar @ret > 1 ? \@ret : $ret[0];
  $self->handler( $cmd . $handler . '_aft', \@_, $ret );
  if ( $self->{'cmd'}{$cmd} ) {
    if    ( $self->{'auto_wait'} ) { $self->wait(); }
    elsif ( $self->{'auto_recv'} ) { $self->recv(); }
  }
  $self->handler( $cmd . $handler . '_aft_aft', \@_, $ret );
  return wantarray ? @ret : $ret[0];
}

sub AUTOLOAD {
  my $self = shift      || return;
  my $type = ref($self) || return;
  #my @p    = @_;
  my $name = $AUTOLOAD;
  $name =~ s/.*\://;
  #return $self->cmd( $name, @p );
  return $self->cmd( $name, @_ );
}

sub DESTROY {
  my $self = shift;
  $self->destroy();
  --$global{'count'};
}

sub handler {
  my ( $self, $cmd ) = ( shift, shift );
  $self->{'handler_int'}{$cmd}->( $self, @_ ) if ref $self->{'handler_int'}{$cmd} eq 'CODE';    #internal lib
  $self->{'handler'}{$cmd}->( $self, @_ ) if ref $self->{'handler'}{$cmd} eq 'CODE';
}

sub baseinit {
  my $self = shift;
  $self->{'number'} = ++$global{'total'};
  $self->myport_generate();
  $self->{'port'} = $1 if $self->{'host'} =~ s/:(\d+)//;
  $self->{'want'}     ||= {};
  $self->{'NickList'} ||= {};
  $self->{'IpList'}   ||= {};
  $self->{'PortList'} ||= {};
  ++$global{'count'};
  $self->{'status'} = 'disconnected';
  $self->protocol_init( $self->{'protocol'} );
}

sub func {
  my $self = shift;
  $self->{'myport_generate'} ||= sub {
    my $self = shift;
    return $self->{'myport'} unless $self->{'myport_base'} or $self->{'myport_random'};
    $self->{'myport'} = undef if $_[0];
    return $self->{'myport'} ||= $self->{'myport_base'} + int( rand( $self->{'myport_random'} ) );
  };
  $self->{'protocol_init'} ||= sub {
    my $self = shift;
    my ($p) = @_;
    if ( $p =~ /^adc/i ) {
      $self->{'cmd_bef'} = undef;
      $self->{'cmd_aft'} = "\x0A";
      $self->{'adc'}     = 1;
    } elsif ( $p =~ /http/i ) {
      $self->{'cmd_bef'} = undef;
      $self->{'cmd_aft'} = "\n";
    } elsif ($p) {    #$p =~ /nmdc/i
      $self->{'cmd_bef'} = '$';
      $self->{'cmd_aft'} = '|';
    }
    $self->{'protocol'} = $p, $self->{$p} = 1, if $p;
    return $self->{'protocol'};
  };
  $self->{'connect'} ||= sub {
    my $self = shift;
    #$self->log($self, 'connect0 inited',"MT:$self->{'message_type'}", ' with');
    if ( $_[0] or $self->{'host'} =~ /:/ ) {
      $self->{'host'} = $_[0] if $_[0];
      $self->{'host'} =~ s{^(.*?)://}{};
      my $p = lc $1;
      $self->protocol_init($p) if $p =~ /^adc/;
      $self->{'host'} =~ s{/.*}{}g;
      $self->{'port'} = $1 if $self->{'host'} =~ s{:(\d+)}{};
    }
    $self->{'port'} = $_[1] if $_[1];
    #print "Hhohohhhh" ,$self->{'protocol'},$self->{'host'};
    return 0
      if ( $self->{'socket'} and $self->{'socket'}->connected() )
      or grep { $self->{'status'} eq $_ } qw(destroy);    #connected
    $self->log( 'info', "connecting to $self->{'protocol'}://$self->{'host'}:$self->{'port'}", %{ $self->{'sockopts'} || {} } );
    $self->{'status'}   = 'connecting';
    $self->{'outgoing'} = 1;
    $self->{'port'}     = $1 if $self->{'host'} =~ s/:(\d+)//;
    $self->{'socket'} ||= new IO::Socket::INET(
      'PeerAddr' => $self->{'host'},
      'PeerPort' => $self->{'port'},
      'Proto'    => $self->{'Proto'} || 'tcp',
      'Timeout'  => $self->{'Timeout'}, (
        $self->{'nonblocking'}
        ? (
          'Blocking'   => 0,
          'MultiHomed' => 1,    #del
          )
        : ()
      ),
      %{ $self->{'sockopts'} || {} },
    );
    $self->log( 'err', "connect socket  error: $@, $! [$self->{'socket'}]" ), return 1 if !$self->{'socket'};
    $self->get_my_addr();
    $self->get_peer_addr();
    $self->{'hostip'} ||= $self->{'host'};
    sub is_local_ip ($) { return $_[0] =~ /^(?:10|172.[123]\d|192\.168)\./; }
    $self->log( 'info', "my internal ip detected, using passive mode", $self->{'myip'}, $self->{'hostip'} ), $self->{'M'} = 'P'
      if !$self->{'M'}
        and is_local_ip $self->{'myip'}
        and !is_local_ip $self->{'hostip'};
    $self->{'M'} ||= 'A';
    $self->log( 'info', "connect to $self->{'host'}($self->{'hostip'}) [me=$self->{'myip'}] ok ", );
    #$self->log($self, 'connected1 inited',"MT:$self->{'message_type'}", ' with');
    $self->cmd('connect_aft');
    #$self->log($self, 'connected2 inited',"MT:$self->{'message_type'}", ' with');
    $self->log( 'dev', "connect_aft after", );
    $self->recv();
    #$self->log( 'dev', "connect recv after", );
    return 0;
  };
  $self->{'connect_check'} ||= sub {
    my $self = shift;
    return 0
      if $self->{'Proto'} eq 'udp'
        or $self->{'status'} eq 'listening'
        or ( $self->{'socket'} and $self->{'socket'}->connected() )
        or !$self->active();
    $self->{'status'} = 'reconnecting';
    #$self->log(          'warn', 'connect_check: must reconnect');
    $self->every(
      $self->{'reconnect_sleep'},
      $self->{'reconnect_func'} ||= sub {
        if ( $self->{'reconnect_tries'}++ < $self->{'reconnects'} ) {
          $self->log(
            'warn',
            "reconnecting [$self->{'reconnect_tries'}/$self->{'reconnects'}] every",
            $self->{'reconnect_sleep'}
          );
          $self->connect();
        }
      }
    );
  };
  $self->{'reconnect'} ||= sub {
    my $self = shift;
    $self->disconnect();
    $self->{'status'} = 'reconnecting';
    sleep $self->{'reconnect_sleep'};
    $self->connect();
  };
  $self->{'listen'} ||= sub {
    my $self = shift;
    return if !$self->{'Listen'} or ( $self->{'M'} eq 'P' and !$self->{'allow_passive_ConnectToMe'} );
    for ( 1 .. $self->{'myport_tries'} ) {
      $self->{'socket'} ||= new IO::Socket::INET(
        'LocalPort' => $self->{'myport'},
        'Proto'     => $self->{'Proto'} || 'tcp',
        ( $self->{'Proto'} ne 'udp' ? ( 'Listen' => $self->{'Listen'} ) : () ),
        ( $self->{'nonblocking'} ? ( 'Blocking' => 0 ) : () ), %{ $self->{'sockopts'} or {} },
      );
      last if $self->{'socket'};
      $self->log( 'err', "listen $self->{'myport'} socket error: $@" ), $self->myport_generate(1), unless $self->{'socket'};
    }
    return unless $self->{'socket'};
    $self->log( 'dcdbg', "listening $self->{'myport'} $self->{'Proto'}" );
    $self->{'accept'} = 1 if $self->{'Proto'} ne 'udp';
    $self->{'status'} = 'listening';
    $self->recv();
  };
  $self->{'disconnect'} ||= sub {
    my $self = shift;
    $self->{'status'} = 'disconnected';
    #$self->log( 'dev', "[$self->{'number'}] disconnected status=",$self->{'status'});
    if ( $self->{'socket'} ) {
      #$self->log( 'dev', "[$self->{'number'}] Closing socket",
      $self->{'socket'}->close();
      delete $self->{'socket'};
    }
    delete $self->{'select'};
#$self->log('dev',"delclient($self->{'clients'}{$_}->{'number'})[$_][$self->{'clients'}{$_}]\n") for grep {$_} keys %{ $self->{'clients'} };
    if ( $self->{'disconnect_recursive'} ) {
      for ( grep { $self->{'clients'}{$_} } keys %{ $self->{'clients'} } ) {
        #$self->log( 'dev', "destroy cli", $self->{'clients'}{$_}, ref $self->{'clients'}{$_}),
        $self->{'clients'}{$_}->destroy() if ref $self->{'clients'}{$_};
        delete( $self->{'clients'}{$_} );
      }
    }
    $self->file_close();
    delete $self->{$_} for qw(NickList IpList PortList);
    $self->log( 'info', "disconnected" );
    #$self->log('dev', caller($_)) for 0..5;
  };
  $self->{'destroy'} ||= sub {
    my $self = shift;
    $self->disconnect() if ref $self;
    #!?  delete $self->{$_} for keys %$self;
    $self->{'status'} = 'destroy';
    %$self = ();
  };
  $self->{'recv'} ||= sub {
    my $self = shift;
    $self->{'recv_runned'}{ $self->{'number'} } = 1;
    my $sleep = shift || 0;
    my $ret = 0;
    $self->connect_check();
    #$self->log( 'dev', 'cant recv, ret' ),
    return unless $self->{'socket'} and ( $self->{'status'} eq 'listening' or $self->{'socket'}->connected );
    $self->{'select'} = IO::Select->new( $self->{'socket'} ) if !$self->{'select'} and $self->{'socket'};
    my ( $readed, $reads );
    $self->{'databuf'} = '';
    #$self->log( 'trace', 'DC::recv', 'bef loop' );
    {
      do {
        #$self->log( 'trace', 'DC::recv', 'in loop', $reads );
        $readed = 0;
        $ret = '0E0', last unless $self->{'select'} and $self->{'socket'};
        $self->log( 'err', "SOCKET UNEXISTS must delete select" ) unless $self->{'select'}->exists( $self->{'socket'} );
        $self->log( 'err', "SOCKET IS NOT CONNECTED must delete select" )
          if !$self->{'accept'}
            and !$self->{'socket'}->connected()
            and $self->{'Proto'} ne 'udp';
        for my $client ( $self->{'select'}->can_read($sleep) ) {
          if ( $self->{'accept'} and $client eq $self->{'socket'} ) {
            if ( $_ = $self->{'socket'}->accept() ) {
              $self->log( 'trace', 'DC::recv', 'accept', $self->{'incomingclass'} );
              $self->{'clients'}{$_} ||= $self->{'incomingclass'}->new(
                %$self, clear(),
                'socket'       => $_,
                'LocalPort'    => $self->{'myport'},
                'incoming'     => 1,
                'want'         => \%{ $self->{'want'} },
                'NickList'     => \%{ $self->{'NickList'} },
                'IpList'       => \%{ $self->{'IpList'} },
                'PortList'     => \%{ $self->{'PortList'} },
                'auto_listen'  => 0,
                'auto_connect' => 0,
                'parent'       => $self,
              );
              ++$ret;
            } else {
              $self->log( 'err', "Accepting fail! [$self->{'Proto'}]" );
            }
            next;
          }
          $self->log( 'dev', "SOCKERR", $client, $self->{'socket'}, $self->{'select'} ) if $client ne $self->{'socket'};
          $self->{'databuf'} = '';
          if ( !defined( $client->recv( $self->{'databuf'}, POSIX::BUFSIZ, $self->{'recv_flags'} ) )
            or !length( $self->{'databuf'} ) )
          {
            if ( $self->active() and $self->{'reconnect_tries'}++ < $self->{'reconnects'} ) {
              #$self->log( 'dcdbg',  "recv err, reconnect," );
              $self->reconnect();
            } else {
              #$self->log( 'dcdbg',  "recv err, disconnect," );
              $self->destroy();
            }
          } else {
            ++$readed;
            ++$ret;
            #$self->log( 'dcdmp', "[$self->{'number'}]", "raw recv ", length( $self->{'databuf'} ), $self->{'databuf'} );
          }
          if ( $self->{'filehandle'} ) { $self->file_write( \$self->{'databuf'} ); }
          else {
            $self->{'buf'} .= $self->{'databuf'};
            local $self->{'cmd_aft'} = "\x0A" if !$self->{'adc'} and $self->{'buf'} =~ /^[BCDEFHITU][A-Z]{,5} /;
#$self->log( 'dcdbg', "[$self->{'number'}]", "raw to parse [$self->{'buf'}] sep[$self->{'cmd_aft'}]" ) unless $self->{'filehandle'};
            while ( $self->{'buf'} =~ s/^(.*?)\Q$self->{'cmd_aft'}//s ) {
              local $_ = $1;
              #$self->log('dcdmp', 'DC::recv', "parse [$_]($self->{'cmd_aft'})");
              last if $self->{'status'} eq 'destroy';
              #$self->log( 'dcdbg',"[$self->{'number'}] dev cycle ",length $_," [$_]", );
              last unless length $_ and length $self->{'cmd_aft'};
              next unless length;
              $self->parser($_);
              last if ( $self->{'filehandle'} );
            }
            $self->file_write( \$self->{'buf'} ), $self->{'buf'} = '' if length( $self->{'buf'} ) and $self->{'filehandle'};
          }
        }
      } while ( $readed and $reads++ < $self->{'max_reads'} );
      #TODO !!! timed
    }
    for ( keys %{ $self->{'clients'} } ) {
      $self->log( 'dev', "del client[$self->{'clients'}{$_}{'number'}][$_]", ), delete( $self->{'clients'}{$_} ),
        $self->log( 'dev', "now clients", map { "[$self->{'clients'}{$_}{'number'}]$_" } keys %{ $self->{'clients'} } ), next
        if !$self->{'clients'}{$_}{'socket'}
          or !$self->{'clients'}{$_}{'status'}
          or $self->{'clients'}{$_}{'status'} eq 'destroy';
      $ret += $self->{'clients'}{$_}->recv();
    }
    $self->{'recv_runned'}{ $self->{'number'} } = undef;
    return $ret;
  };
  $self->{'wait'} ||= sub {
    my $self = shift;
    my ( $waits, $wait_once ) = @_;
    $waits     ||= $self->{'waits'};
    $wait_once ||= $self->{'wait_once'};
    local $_;
    my $ret;
    $ret += $self->recv($wait_once) while --$waits > 0 and !$ret;
    return $ret;
  };
  $self->{'finished'} ||= sub {
    my $self = shift;
    $self->log( 'dcdev', 'not finished file:', "$self->{'filebytes'} / $self->{'filetotal'}", $self->{'peernick'} ), return 0
      if ( $self->{'filebytes'} and $self->{'filetotal'} and $self->{'filebytes'} < $self->{'filetotal'} - 1 );
    local @_;
    $self->log( 'dcdev', 'not finished clients:', @_ ), return 0
      if @_ = grep { !$self->{'clients'}{$_}->finished() } keys %{ $self->{'clients'} };
    return 1;
  };
  $self->{'wait_connect'} ||= sub {
    my $self = shift;
    for ( 0 .. ( $_[0] || $self->{'wait_connect'} ) ) {
      last if $self->{'status'} eq 'connected';
      $self->wait(1);
    }
    return $self->{'status'};
  };
  $self->{'wait_finish'} ||= sub {
    my $self = shift;
    for ( 0 .. $self->{'wait_finish_tries'} ) {
      last if $self->finished();
      $self->wait( undef, $self->{'wait_finish_by'} );
    }
    local @_;
    $self->info(),
      $self->log(
      'info',
      'finished, but clients still active:',
      map { "[$self->{'clients'}{$_}{'number'}]$_;st=$self->{'clients'}{$_}{'status'}" } @_
      ) if @_ = keys %{ $self->{'clients'} };
  };
  $self->{'wait_clients'} ||= sub {
    my $self = shift;
    for ( 0 .. $self->{'wait_clients_tries'} ) {
      last if $self->{'clients_max'} > scalar keys %{ $self->{'clients'} };
      $self->info() unless $_;
      $self->log( 'info',
            "wait clients "
          . scalar( keys %{ $self->{'clients'} } )
          . "/$self->{'clients_max'}  $_/$self->{'wait_clients_tries'}" );
      $self->wait( undef, $self->{'wait_clients_by'} );
    }
  };
  $self->{'wait_sleep'} ||= sub {
    my $self      = shift;
    my $how       = shift || 1;
    my $starttime = time();
    $self->wait(@_) while $starttime + $how > time();
  };
  $self->{'work'} ||= sub {
    my $self   = shift;
    my @params = @_;
    $self->periodic();
    return $self->wait_sleep(@params) if @params;
    return $self->recv( $self->{'work_sleep'} );
  };
  $self->{'parser'} ||= sub {
    my $self = shift;
    for ( local @_ = @_ ) {
      $self->log( 'dcdmp', "rawrcv:", $_ );
      my ( $dst, $cmd, @param );
      $cmd = ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' ) if /^[<*]/;    #farcolorer
      s/^\$?([\w\-]+)\s*//, $cmd = $1 unless $cmd;
      if ( $self->{'adc'} ) {
        $cmd =~ s/^([BCDEFHIU])//, $dst = $1;
        @param = ( [$dst], split / / );
        if ( $dst eq 'B' or $dst eq 'F' or $dst eq 'U' ) {
          #$self->log( 'dcdmp', "P0 $dst$cmd p=",(Dumper \@param));
          #push @{ $param[0] }, shift@param;
          push @{ $param[0] }, splice @param, 1, 1;
          if ( $dst eq 'F' ) {
            #$self->log( 'dcdmp', 'feature'
            push @{ $param[0] }, splice @param, 1, 1 while $param[1] =~ /^[+\-]/;
          }
          #$self->log( 'dcdmp', "P1 $dst$cmd p=",(Dumper \@param));
        } elsif ( $dst eq 'D' or $dst eq 'E' ) {
          #push @{ $param[0] }, shift@param, shift@param;
          push @{ $param[0] }, splice @param, 1, 2;
        }
        #elsif ( $dst eq 'I'  ) { push @{ $param[0] }, undef }
      } else {
        @param = ($_);
      }
      #$self->log( 'dcdmp', "P3 $dst$cmd p=",(Dumper \@param));
      $cmd = $dst . $cmd if !exists $self->{'parse'}{$cmd} and exists $self->{'parse'}{ $dst . $cmd };
      #$self->log( 'dcinf', "UNKNOWN PEERCMD:[$cmd]->($_) : please add \$dc->{'parse'}{'$cmd'} = sub { ... };" ),
      $self->{'parse'}{$cmd} = sub { }, $cmd = ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' )
        unless exists $self->{'parse'}{$cmd};
      my ( @ret, $ret );
      #$self->log( 'dcinf', "parsing", $cmd, @_ ,'with',$self->{'parse'}{$cmd}, ref $self->{'parse'}{$cmd});
      my @self;
      @self = $self if $self->{'adc'};
      $self->handler( @self, $cmd . '_parse_bef_bef', @param );
      if ( ref $self->{'parse'}{$cmd} eq 'CODE' ) {
        if ( !exists $self->{'no_print'}{$cmd} ) {
          local $_ = $_;
          local @_ =
            map { "$_:$self->{'skip_print_'.$_}" } grep { $self->{ 'skip_print_' . $_ } } keys %{ $self->{'no_print'} || {} };
    #$self->log( 'dcdmp', "rcv: $dst$cmd p=[",(Dumper \@param),"] ", ( @_ ? ( '  [', @_, ']' ) : () ) );
    #$self->log( 'dcdmp', "rcv: $dst$cmd p=[", (map {ref $_ eq 'ARRAY'?@$_:$_}@param), "] ", ( @_ ? ( '  [', @_, ']' ) : () ) );
          $self->{ 'skip_print_' . $_ } = 0 for keys %{ $self->{'no_print'} || {} };
        } else {
          ++$self->{ 'skip_print_' . $cmd }, if exists $self->{'no_print'}{$cmd};
        }
        $self->handler( @self, $cmd . '_parse_bef', @param );
        @ret = $self->{'parse'}{$cmd}->( @self, @param );
        $ret = scalar @ret > 1 ? \@ret : $ret[0];
        $self->handler( @self, $cmd . '_parse_aft', @param, $ret );
      }
      $self->handler( @self, $cmd, @param, $ret );
      $self->handler( @self, $cmd . '_parse_aft_aft', @param, $ret );
    }
  };
  $self->{'sendcmd'} ||= sub {
    my $self = shift;
    $self->connect_check();
    #$self->{'log'}->( $self,'sendcmd0', @_);
    $_[0] .= splice @_, 1, 1 if $self->{'adc'} and length $_[0] == 1;
    $self->{'log'}->( $self, 'sendcmd1', @_ );
    push @{ $self->{'send_buffer'} }, $self->{'cmd_bef'} . join( $self->{'cmd_sep'}, @_ ) . $self->{'cmd_aft'} if @_;
    $self->log( 'err', "ERROR! no socket to send" ), return unless $self->{'socket'};
    if ( ( $self->{'sendbuf'} and @_ ) or !@{ $self->{'send_buffer'} || [] } ) { }
    else {
      local $_;
      eval { $_ = $self->{'socket'}->send( join( '', @{ $self->{'send_buffer'} }, ) ); };
      $self->log( 'err', 'send error', $@ ) if $@;
      $self->{'log'}->( $self, 'dcdmp', "we send [" . join( '', @{ $self->{'send_buffer'} } ) . "]:", $_, $! );
      $self->{'send_buffer'} = [];
      $self->{'sendbuf'}     = 0;
    }
  };
  $self->{'rcmd'} ||= sub {
    my $self = shift;
    eval {
      eval { $_->cmd(@_) }, $self->wait_sleep( $self->{'cmd_recurse_sleep'} )
        for grep { $_ } values( %{ $self->{'clients'} } ), $self;
    };
  };
  $self->{'get'} ||= sub {
    my ( $self, $nick, $file, $as ) = @_;
    $self->wait_clients();
    $self->{'want'}{$self->{peers}{$nick}{'INF'}{'ID'} || $nick}{$file} = $as || $file || '';
    $self->log( 'dbg', "getting [$nick] $file as $as" );
    if ( $self->{'adc'} ) {
      #my $token = $self->make_token($nick);
      local @_;
      if ( $self->{'M'} eq 'A' and $self->{'myip'} and !$self->{'passive_get'} ) {
        @_ = ( 'CTM', $nick, $self->{'connect_protocol'}, $self->{'myport'}, $self->make_token($nick) );
      } else {
        @_ = ( 'RCM', $nick, $self->{'connect_protocol'}, $self->make_token($nick) );
      }
      $self->cmd( 'D', @_ );
      #$self->cmd( $dst, 'CTM', $peerid, $_[0], $self->{'myport'}, $_[1], )
    } else {
      $self->cmd( ( ( $self->{'M'} eq 'A' and $self->{'myip'} and !$self->{'passive_get'} ) ? '' : 'Rev' ) . 'ConnectToMe',
        $nick );
    }
  };
  $self->{'file_select'} ||= sub {
    my $self = shift;
    return if length $self->{'filename'};
    
   
    
    my $peerid = $self->{'peerid'} || $self->{'peernick'};
    
#$self->log( 'dcdev','file_select000',$peerid,  $self->{'filename'}, $self->{'fileas'}, Dumper $self->{'want'});
    for ( keys %{ $self->{'want'}{$peerid} } ) {
      ( $self->{'filename'}, $self->{'fileas'} ) = ( $_, $self->{'want'}{$peerid}{$_} );
#$self->log( 'dcdev', 'file_select1', $self->{'filename'}, $self->{'fileas'} );
      $self->{'filecurrent'} = $self->{'filename'};
      next unless defined $self->{'filename'};
      #delete  $self->{'want'}{ $peerid }{$_} ;   $self->{'filecurrent'}
      last;
    }
#$self->log( 'dcdev', 'file_select2', $self->{'filename'}, $self->{'fileas'} );
    return unless defined $self->{'filename'};
    unless ( $self->{'filename'} ) {
      if ( $self->{'peers'}{$peerid}{'SUP'}{'BZIP'} or $self->{'NickList'}->{$peerid}{'XmlBZList'} ) {
        $self->{'fileext'}  = '.xml.bz2';
        $self->{'filename'} = 'files' . $self->{'fileext'};
      } elsif ( $self->{'adc'} ) {
        $self->{'fileext'}  = '.xml';
        $self->{'filename'} = 'files' . $self->{'fileext'};
      } elsif ( $self->{'NickList'}->{$peerid}{'BZList'} ) {
        $self->{'fileext'}  = '.bz2';
        $self->{'filename'} = 'MyList' . $self->{'fileext'};
      } else {
        $self->{'fileext'}  = '.DcLst';
        $self->{'filename'} = 'MyList' . $self->{'fileext'};
      }
      $self->{'fileas'} .= $self->{'fileext'} if $self->{'fileas'};
    }
    $self->log( 'dcdev', 'file_select3', $self->{'filename'}, $self->{'fileas'} );
  };
  $self->{'file_open'} ||= sub {
    my $self = shift;
    #$self->{'fileas'}=$_[0] if !length $self->{'fileas'} or length $_[0];
    #$self->{'filetotal'} = $_[1]if ! $self->{'filetotal'} or $_[1];
    my $oparam =
      $self->{'fileas'} eq '-'
      ? '>-'
      : '>' . $self->{'partial_prefix'} . ( $self->{'fileas'} || $self->{'filename'} ) . $self->{'partial_ext'};
    $self->handler( 'file_open_bef', $oparam );
    $self->log(
      'dbg',             "file_open pre", $oparam, 'want bytes', $self->{'filetotal'}, 'as=',
      $self->{'fileas'}, 'f=',            $self->{'filename'}
    );
    open( $self->{'filehandle'}, $oparam )
      or $self->log( 'dcerr', "file_open error", $!, $oparam ), $self->handler( 'file_open_error', $!, $oparam ), return 1;
    binmode( $self->{'filehandle'} );
    $self->{'status'} = 'transfer';
    return 0;
  };
  $self->{'file_write'} ||= sub {
    my $self = shift;
    $self->{'file_start_time'} ||= time;
    my $fh = $self->{'filehandle'} or $self->log( 'err', 'cant write, no filehandle' ), return;
    for my $databuf (@_) {
      $self->{'filebytes'} += length $$databuf;
#$self->log( 'dcdbg', "($self->{'number'}) recv ".length($$databuf)." [$self->{'filebytes'}] of $self->{'filetotal'} file $self->{'filename'}" );
      $self->log( 'dcdbg', "recv " . length($$databuf) . " [$$databuf]" ) if length $$databuf < 10;
      print $fh $$databuf;
      $self->log( 'err', "file download error! extra bytes ($self->{'filebytes'}/$self->{'filetotal'}) " )
        if $self->{'filebytes'} > $self->{'filetotal'};
      $self->log(
        'info',
        "file complete ($self->{'filebytes'}) per",
        $self->float( time - $self->{'file_start_time'} ),
        's at', $self->float( $self->{'filebytes'} / ( ( time - $self->{'file_start_time'} ) or 1 ) ), 'b/s'
        ),
        $self->disconnect(), $self->{'status'} = 'destroy', $self->{'file_start_time'} = 0, $self->{'filename'} = '',
        $self->{'fileas'} = '', delete $self->{'want'}{ $self->{'peerid'} }{ $self->{'filecurrent'} },
        $self->{'filecurrent'} = '',
        if $self->{'filebytes'} >= $self->{'filetotal'};
    }
  };
  $self->{'openfile'} ||= sub {
    my $self = shift;
    $self->log( 'dcwarn', 'openfile is deprecated, use file_open' );
    $self->file_open(@_);
  };
  $self->{'writefile'} ||= sub {
    my $self = shift;
    $self->log( 'dcwarn', 'openfile is deprecated, use file_write' );
    $self->file_write(@_);
  };
  $self->{'file_close'} ||= sub {
    my $self = shift;
    if ( $self->{'filehandle'} ) {
      close( $self->{'filehandle'} ), delete $self->{'filehandle'};
      if ( length $self->{'partial_ext'} ) {
        $self->log( 'dcerr', 'cant move finished file' )
          if !rename $self->{'partial_prefix'} . ( $self->{'fileas'} || $self->{'filename'} ) . $self->{'partial_ext'},
            ( $self->{'fileas'} || $self->{'filename'} );
      }
    }
  };
  $self->{'get_peer_addr'} ||= sub {
    my ($self) = @_;
    return unless $self->{'socket'};
    eval { @_ = unpack_sockaddr_in( getpeername( $self->{'socket'} ) ) };
    return unless $_[1];
    return unless $_[1] = inet_ntoa( $_[1] );
    $self->{'port'} = $_[0] if $_[0] and !$self->{'incoming'};
    $self->{'hostip'} = $_[1], $self->{'host'} ||= $self->{'hostip'} if $_[1];
    return $self->{'hostip'};
  };
  $self->{'get_my_addr'} ||= sub {
    my ($self) = @_;
    return unless $self->{'socket'};
    eval { @_ = unpack_sockaddr_in( getsockname( $self->{'socket'} ) ) };
    return unless $_[1];
    return unless $_[1] = inet_ntoa( $_[1] );
    #$self->{'log'}->('dev', "MYIP($self->{'myip'}) [$self->{'number'}] SOCKNAME $_[0],$_[1];");
    return $self->{'myip'} ||= $_[1];
  };
  #http://www.dcpp.net/wiki/index.php/LockToKey :
  $self->{'lock2key'} ||= sub {
    my $self = shift;
    my @lock = split( //, shift );
    my $i;
    my @key = ();
    foreach (@lock) { $_ = ord; }
    push( @key, $lock[0] ^ 5 );
    for ( $i = 1 ; $i < @lock ; $i++ ) { push( @key, ( $lock[$i] ^ $lock[ $i - 1 ] ) ); }
    for ( $i = 0 ; $i < @key ; $i++ ) { $key[$i] = ( ( ( $key[$i] << 4 ) & 240 ) | ( ( $key[$i] >> 4 ) & 15 ) ) & 0xff; }
    $key[0] = $key[0] ^ $key[ @key - 1 ];

    foreach (@key) {
      if ( $_ == 0 || $_ == 5 || $_ == 36 || $_ == 96 || $_ == 124 || $_ == 126 ) { $_ = sprintf( '/%%DCN%03i%%/', $_ ); }
      else                                                                        { $_ = chr; }
    }
    return join( '', @key );
  };
  $self->{'tag'} ||= sub {
    my $self = shift;
    $self->{'client'} . ' ' . join( ',', map $_ . ':' . $self->{$_}, grep defined( $self->{$_} ), qw(V M H S O) );
  };
  $self->{'myinfo'} ||= sub {
    my $self = shift;
    return
        $self->{'Nick'} . ' '
      . $self->{'description'} . '<'
      . $self->tag() . '>' . '$' . ' ' . '$'
      . $self->{'connection'}
      . ( length( $self->{'flag'} ) ? chr( $self->{'flag'} ) : '' ) . '$'
      . $self->{'email'} . '$'
      . $self->{'sharesize'} . '$';
  };
  $self->{'supports'} ||= sub {
    my $self = shift;
    return join ' ', grep $self->{$_}, @{ $self->{'supports_avail'} };
  };
  $self->{'supports_parse'} ||= sub {
    my $self = shift;
    my ( $str, $save ) = @_;
    $save->{$_} = 1 for split /\s+/, $str;
    delete $save->{$_} for grep !length $save->{$_}, keys %$save;
    return wantarray ? %$save : $save;
  };
  $self->{'info_parse'} ||= sub {
    my $self = shift;
    my ( $info, $save ) = @_;
    $save->{'info'} = $info;
    $save->{'description'} = $1 if $info =~ s/^([^<\$]+)(<|\$)/$2/;
    ( $save->{'tag'}, $save->{'M'}, $save->{'connection'}, $save->{'email'}, $save->{'sharesize'} ) = split /\s*\$\s*/, $info;
    $save->{'flag'} = ord($1) if $save->{'connection'} =~ s/([\x00-\x1F])$//e;
    $self->tag_parse( $save->{'tag'}, $save );
    delete $save->{$_} for grep !length $save->{$_}, keys %$save;
    return wantarray ? %$save : $save;
  };
  $self->{'tag_parse'} ||= sub {
    my $self = shift;
    my ( $tag, $save ) = @_;
    $save->{'tag'} = $tag;
    $tag =~ s/(^\s*<\s*)|(\s*>\s*$)//g;
    $save->{'client'} = $1 if $tag =~ s/^(\S+)\s*//;
    /(.+):(.+)/, $save->{$1} = $2 for split /,/, $tag;
    return wantarray ? %$save : $save;
  };
  $self->{'info'} ||= sub {
    my $self = shift;
    $self->log(
      'info',
      map( {"$_=$self->{$_}"} grep { $self->{$_} } @{ $self->{'informative'} } ),
      map( { $_ . '(' . scalar( keys %{ $self->{$_} } ) . ')=' . join( ',', keys %{ $self->{$_} } ) }
        grep { keys %{ $self->{$_} } } @{ $self->{'informative_hash'} } )
    );
    $self->{'clients'}{$_}->info() for keys %{ $self->{'clients'} };
  };
  $self->{'active'} ||= sub {
    my $self = shift;
    return $self->{'status'} if grep { $self->{'status'} eq $_ } qw(connecting connected reconnecting listening transfer);
    return 0;
  };
  #sub status {
  #now states:
  #listening  connecting   connected   reconnecting transfer  disconnecting disconnected destroy
  #need checks:
  #\ connected?/             \-----/
  #\-----------------------active?-------------------------/
  #}
  $self->{'every'} ||= sub {
    my ( $self, $sec, $func ) = ( shift, shift, shift );
    if ( ( $self->{'every_list'}{$func} + $sec < time ) and ( ref $func eq 'CODE' ) ) {
      $self->{'every_list'}{$func} = time;
      $func->(@_);
    }
  };
  $self->{'cmd_adc'} ||= sub {
    my ( $self, $dst, $cmd ) = ( shift, shift, shift );
    #$self->sendcmd( $dst, $cmd,map {ref $_ eq 'HASH'}@_);
    #$self->log(    'cmd_adc', Dumper \@_);
    $self->sendcmd(
      $dst, $cmd,
      #map {ref $_ eq 'ARRAY' ? @$_:ref $_ eq 'HASH' ? each : $_)    }@_
      ( $dst eq 'C' || !length $self->{'sid'} ? () : $self->{'sid'} ),
      map {
        ref $_ eq 'ARRAY' ? @$_ : ref $_ eq 'HASH' ? do {
          my $h = $_;
          map { "$_$h->{$_}" } keys %$h;
          }
          : $_
        } @_
    );
  };
  #sub adc_string_decode ($) {
  $self->{'adc_string_decode'} = sub ($) {
    my $self = shift;
    local ($_) = @_;
    s{\\s}{ }g;
    s{\\n}{\x0A}g;
    s{\\\\}{\\}g;
    $_;
  };
  #sub adc_string_encode ($) {
  $self->{'adc_string_encode'} = sub ($) {
    my $self = shift;
    local ($_) = @_;
    s{\\}{\\\\}g;
    s{ }{\\s}g;
    s{\x0A}{\\n}g;
    $_;
  };
  #sub adc_strings_decode (\@) {
  $self->{'adc_strings_decode'} = sub (\@) {
    my $self = shift;
    map { $self->adc_string_decode($_) } @_;
  };
  #sub adc_strings_encode (\@) {
  $self->{'adc_strings_encode'} = sub (\@) {
    my $self = shift;
    map { $self->adc_string_encode($_) } @_;
  };
  $self->{'adc_parse_named'} = sub (@) {
    my $self = shift;
    #sub adc_parse_named (@) {
    #my ($dst,$peerid) = @{ shift() };
    local %_;
    for (@_) {
      s/^([A-Z][A-Z0-9])//;
      #my $name=
      #print "PARSE[$1=$_]\n",
      $_{$1} = $self->adc_string_decode($_);
    }
    return \%_;
    #return ($dst,$peerid)
  };
  $self->{'make_token'} = sub (;$) {
    my $self   = shift;
    my $peerid = shift;
    my $token;
    local $_;
    $_ = $self->{'peers'}{$peerid}{'INF'}{I4} if $peerid and exists $self->{'peers'}{$peerid};
    s/\D//g;
    $token += $_;
    $_ = $self->{myip};
    s/\D//g;
    return $token + $_ + int time;
  };
}
1;
__END__

=head1 NAME

Net::DirectConnect - Perl Direct Connect protocol implementation

=head1 SYNOPSIS

  use Net::DirectConnect::clihub;
  my $dc = Net::DirectConnect::clihub->new(
    'host' => 'dc.mynet.com',
    'port' => '4111', #if not 411
    'Nick' => 'Bender', 
    'description' => 'kill all humans',
    'M'           => 'P', #passive mode, active by default
  );
  $dc->wait_connect();
  $dc->chatline( 'hi all' );

  while ( $dc->active() ) {
    $dc->work();    
  }
  $dc->destroy();

look at examples for handlers


=head1 DESCRIPTION

 Currently NOT supported:
 sharing;
 segmented, multisource download;
 async connect;
 full ADC;


=head1 INSTALLATION

 To install this module type the following:

   perl Makefile.PL && make install clean
   

=head1 SEE ALSO

#pro http://pro.setun.net/dcppp/
      http://sourceforge.net/projects/dcppp

 http://svn.setun.net/dcppp/timeline/browser/trunk

 latest snapshot
 svn co svn://svn.setun.net/dcppp/trunk/ dcppp

 usage example:
 used in [and created for] http://sourceforge.net/projects/pro-search http://pro.setun.net/search/
 ( http://svn.setun.net/search/trac.cgi/browser/trunk/crawler.pl )


 protocol info:
 http://en.wikipedia.org/wiki/Direct_Connect_network
 http://www.teamfair.info/DC-Protocol.htm
 http://adc.sourceforge.net/ADC.html

 also useful for creating links from web:
 http://magnet-uri.sourceforge.net/
 http://en.wikipedia.org/wiki/Magnet:_URI_scheme


=head1 Last changes

 writefile -> file_write
 openfile -> file_open


=head1 TODO
 
 CGET file files.xml.bz2 0 -1 ZL1<<<

 Rewrite better


=head1 AUTHOR

Oleg Alexeenkov, E<lt>pro@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2009 Oleg Alexeenkov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
