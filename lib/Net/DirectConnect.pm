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
our $VERSION = '0.01';
our $AUTOLOAD;
our %global;

sub float {    #v1
  my $self = shift;
  return ( $_[0] < 8 and $_[0] - int( $_[0] ) )
    ? sprintf( '%.' . ( $_[0] < 1 ? 3 : ( $_[0] < 3 ? 2 : 1 ) ) . 'f', $_[0] )
    : int( $_[0] );
}

sub clear {
  return (
    'clients'    => undef,
    'socket'     => undef,
    'select'     => undef,
    'accept'     => undef,
    'filehandle' => undef,
    'parse'      => undef,
    'cmd'        => undef,
  );
}

sub new {
  my $class = shift;
  my @param = @_;
  #print "init1:", Dumper(\@_);
#print "NEW\n";
  my $self = {
    'Listen'        => 10,
    'Timeout'       => 5,
    'myport'        => 412,     #first try
    'myport_base'   => 40000,
    'myport_random' => 1000,
    'myport_tries'  => 5,
    # http://www.dcpp.net/wiki/index.php/%24MyINFO
    'description' => 'just perl Net::DirectConnect bot', 'connection' => 'LAN(T3)',
    #NMDC1: 28.8Kbps, 33.6Kbps, 56Kbps, Satellite, ISDN, DSL, Cable, LAN(T1), LAN(T3)
    #NMDC2: Modem, DSL, Cable, Satellite, LAN(T1), LAN(T3)
    'flag' => '1',              # User status as ascii char (byte)
                                # 1 normal
                                # 2, 3 away
                                # 4, 5 server               The server icon is used when the client has
                                # 6, 7 server away          uptime > 2 hours, > 2 GB shared, upload > 200 MB.
                                # 8, 9 fireball             The fireball icon is used when the client
                                # 10, 11 fireball away      has had an upload > 100 kB/s.
    'email' => 'billgates@microsoft.com', 'sharesize' => 10 * 1024 * 1024 * 1024,    #10GB
    'client'   => 'perl',    #'dcp++',                                                              #++: indicates the client
    'protocol' => 'nmdc',    # or 'adc'
    'cmd_sep'  => ' ',
    'V' => $VERSION . '_' . ( split( ' ', '$Revision$' ) )[1],
    ,                        #V: tells you the version number
    'M' => 'A',              #M: tells if the user is in active (A), passive (P), or SOCKS5 (5) mode
    'H' => '0/1/0'
    , #H: tells how many hubs the user is on and what is his status on the hubs. The first number means a normal user, second means VIP/registered hubs and the last one operator hubs (separated by the forward slash ['/']).
    'S' => '3',      #S: tells the number of slots user has opened
    'O' => undef,    #O: shows the value of the "Automatically open slot if speed is below xx KiB/s" setting, if non-zero
    'lock'              => 'EXTENDEDPROTOCOLABCABCABCABCABCABC Pk=DCPLUSPLUS0.668ABCABC',
    'log'               => sub { my $self = shift; print( join( ' ', "($self)[$self->{'number'}]", @_ ), "\n" ) },
    'auto_recv'         => 1,
    'max_reads'         => 20,
    'wait_once'         => 0.1,
    'waits'             => 100,
    'wait_finish'       => 600,
    'wait_finish_by'    => 1,
    'wait_connect'      => 600,
    'clients_max'       => 50,
    'wait_clients'      => 200,
    'wait_clients_by'   => 0.01,
    'work_sleep'        => 0.01,
    'cmd_recurse_sleep' => 0,
    ( $^O eq 'MSWin32' ? () : ( 'nonblocking' => 1 ) ),
    'informative'          => [qw(number peernick status host port filebytes filetotal proxy)],    # sharesize
    'informative_hash'     => [qw(clients)],                                                       #NickList IpList PortList
    'disconnect_recursive' => 1,
    'no_print'             => { map { $_ => 1 } qw(Search Quit MyINFO Hello SR UserCommand) },
    #todo
    'reconnects'      => 5,
    'reconnect_sleep' => 5,
  };
  #print "init2:", Dumper(\@_);
  eval { $self->{'recv_flags'} = MSG_DONTWAIT; } unless $^O =~ /win/i;
  #print "init3:", Dumper(\@_);
  $self->{'recv_flags'} ||= 0;
  bless( $self, $class );
  #print "init4:", Dumper(\@_);
  $self->func(@param);
  $self->init(@param);
  #  $self->init(@_);
  #  print "init6:", Dumper(\@_);
  if ( $self->{'auto_listen'} ) {
    $self->listen();
    #    $self->log('dev', 'listen work');
    #$self->work() ;
    #$self->log('dev', 'listen work ok ');
  } elsif ( $self->{'auto_connect'} ) {
    $self->connect();
    #    $self->log('dev', 'conn work');
    $self->work();
    #$self->log('dev', 'conn work ok ');
  }
  #$self->log('dev', 'new exit');
  return $self;
}
#sub log {  my $self = shift;  $self->{'log'}->(@_) if $self->{'log'};}
sub log(@) {
  my $self = shift;
  return $self->{'log'}->( $self, @_ ) if ref $self->{'log'} eq 'CODE';
  print( join( ' ', "[$self->{'number'}]", @_ ), "\n" );
}

sub cmd {
  #print "CMD PRE param[",@_,"]\n" ;
  my $self = shift;
  my $cmd  = shift;
  my ( @ret, $ret );
  #  return $self->{'cmd'}{$cmd}->(@_) if $cmd eq 'log' and ref $self->{'cmd'}{$cmd} eq 'CODE';
  #  $self->{'log'}->($self,'dev', 'cmd', $cmd, @_) if $cmd ne 'log';
  #  $self->{'log'}->($self,'dev', 'cmd', $cmd, @_) if $cmd eq 'lock2key';
  my ( $func, $handler );
  if ( ref $self->{'cmd'}{$cmd} eq 'CODE' ) {
    $func    = $self->{'cmd'}{$cmd};
    $handler = '_cmd';
    #    $self->log( 'dev',  "cmd 1" ) unless $cmd eq 'log';
  } elsif ( ref $self->{$cmd} eq 'CODE' ) {
    #    $self->log( 'dev',  "cmd 2" ) unless $cmd eq 'log';
    $func = $self->{$cmd};
  }
  $self->handler( $cmd . $handler . '_bef_bef', \@_ );
  if ( $self->{'min_cmd_delay'} and ( time - $self->{'last_cmd_time'} < $self->{'min_cmd_delay'} ) ) {
    $self->log( 'dbg', 'sleepcmd', $self->{'min_cmd_delay'} - time + $self->{'last_cmd_time'} );
    sleep( $self->{'min_cmd_delay'} - time + $self->{'last_cmd_time'} );
  }
  $self->{'last_cmd_time'} = time;
  #$self->{'log'}->($self,'dev', 'cmd', $cmd, @_) if $cmd ne 'log';
  # my $func = ref $self->{'cmd'}{$cmd} eq 'CODE' ? $self->{'cmd'}{$cmd} :ref $self->{$cmd} eq 'CODE' ? $self->{$cmd} : undef;
  #  if ( ref $self->{'cmd'}{$cmd} eq 'CODE') {
  if ($func) {
    $self->handler( $cmd . $handler . '_bef', \@_ );
#      $self->{'log'}->($self,'dev', 'cmdrun', $cmd, $self, @_) if !grep {$cmd eq $_} qw(log active recv connect_check work periodic search_buffer);
    #  $self->{'log'}->($self,'dev', 'cmdrun', $cmd, $self, @_) if $cmd eq 'lock2key';
    @ret = $func->( $self, @_ );    #$self->{'cmd'}{$cmd}->(@_);
    #  $self->{'log'}->($self,'dev', 'cmdret', $cmd, $self, @ret) if $cmd eq 'lock2key';
    $ret = scalar @ret > 1 ? \@ret : $ret[0];
    $self->handler( $cmd . $handler . '_aft', \@_, $ret );
    #  } elsif() {
  } elsif ( exists $self->{$cmd} ) {
    @ret = ( $self->{$cmd} );
  } else {
    $self->log( 'info', "UNKNOWN CMD:[$cmd]{@_} : please add \$dc->{'cmd'}{'$cmd'} = sub { ... };", Dumper $self->{'cmd'}, $self->{'parse'} );
    $self->{'cmd'}{$cmd} = sub { };
  }
  #  if    ( $self->{'auto_wait'} and $cmd ne 'wait') { $self->wait(); }
  #  elsif ( $self->{'auto_recv'} and !$self->{'recv_runned'}{ $self->{'number'} } ) { $self->recv(); }
  if ( $self->{'cmd'}{$cmd} ) {
    if    ( $self->{'auto_wait'} ) { $self->wait(); }
    elsif ( $self->{'auto_recv'} ) { $self->recv(); }
  }
  $self->handler( $cmd . $handler . '_aft_aft', \@_, $ret );
  #  $self->{'log'}->($self,'dev', 'cmdree', $cmd, $self, @ret) if $cmd eq 'lock2key';
  return wantarray ? @ret : $ret[0];
}

sub AUTOLOAD {
  #print "AL0[$AUTOLOAD]:",join ':', @_, "\n" if !grep {$AUTOLOAD =~ /$_$/} qw(recv connect_check);
  my $self = shift || return;
  #print "AL1[$AUTOLOAD]:",join ':', @_, "\n" if !grep {$AUTOLOAD =~ /$_$/} qw(recv connect_check);
    my $type = ref($self) || 
(print("AUTOLOAD: $self is not ref\n"),(map { print ('caller', $_, caller($_), "\n") } 0 .. 5),die);
  my @p    = @_;
  my $name = $AUTOLOAD;
  #print "AL2[$AUTOLOAD,$name]:",join ':', @_, "\n" if !grep {$AUTOLOAD =~ /$_$/} qw(recv connect_check);
  $name =~ s/.*\://;
  #print "CMD[", Dumper ($self), " : $type];\n";
  #print "ALR[$name]",join ':', @p, "\n" if !grep {$AUTOLOAD =~ /$_$/} qw(recv connect_check);
  #my @r = $self->cmd( $name, @p );
  #print "ALR[$name]",join ':', @p,'===', @r, "\n" if !grep {$AUTOLOAD =~ /$_$/} qw(recv connect_check);
  #  return @r;
  return $self->cmd( $name, @p );
}

sub DESTROY {
  my $self = shift;
  #  print "\n[$self->{'number'}]DESTROY AUTO TRY\n";
  #      $self->log( 'dcdbg', "[$self->{'number'}]($self)AUTO DESTROY from ", join( ':', caller ), " ($self)" );
  #    $self->disconnect();
  $self->destroy();
  #print "NOLOG DESTROY[$self->{'number'}]\n";
  --$global{'count'};
}

sub handler {
  my ( $self, $cmd ) = ( shift, shift );
  #return if $cmd eq 'log';
  #          $self->log('dev', "handlerdbg [$cmd]", @_, $self->{'handler'}{$cmd});
  $self->{'handler_int'}{$cmd}->( $self, @_ ) if ref $self->{'handler_int'}{$cmd} eq 'CODE';    #internal lib
  $self->{'handler'}{$cmd}->( $self,     @_ ) if ref $self->{'handler'}{$cmd}     eq 'CODE';
}

sub baseinit {
  my $self = shift;
  $self->{'number'} = ++$global{'total'};
  $self->myport_generate();
  #    if $self->{'myport_random'} and $self->{'myport_base'};
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
    #sub myport_generate {
    my $self = shift;
    #  $self->log( 'dev', $self->{'myport'}, $self->{'myport_base'}, $self->{'myport_random'});
    return $self->{'myport'} unless $self->{'myport_base'} or $self->{'myport_random'};
    $self->{'myport'} = undef if $_[0];
    return $self->{'myport'} ||= $self->{'myport_base'} + int( rand( $self->{'myport_random'} ) );
  };
  $self->{'protocol_init'} ||= sub {
    #sub protocol {
    my $self = shift;
    my ($p) = @_;
    if ( $p =~ /adc/i ) {
      $self->{'cmd_bef'} = undef;
      $self->{'cmd_aft'} = "\x0A";
    } elsif ( $p =~ /http/i ) {
      $self->{'cmd_bef'} = undef;
#      $self->{'cmd_aft'} = "\x0D\x0D";
      $self->{'cmd_aft'} = "\n";
#      $self->{'cmd_aft'} = "\n\n";
    } elsif ($p) {    #$p =~ /nmdc/i
      $self->{'cmd_bef'} = '$';
      $self->{'cmd_aft'} = '|';
    }
    $self->{'protocol'} = $p if $p;
    return $self->{'protocol'};
  };
  $self->{'connect'} ||= sub {
    #sub connect {
    my $self = shift;
    #psmisc::caller_trace(10);
    if ( $_[0] ) {
      $self->{'host'} = $_[0];
      $self->{'host'} =~ s{^(.*?)://}{};
      $self->{'protocol'} = 'adc', $self->protocol( $self->{'protocol'} )
        if lc $1 eq 'adc';
      $self->{'host'} =~ s{/.*}{}g;
      $self->{'port'} = $1 if $self->{'host'} =~ s{:(\d+)}{};
    }
    $self->{'port'} = $_[1] if $_[1];
    return 0
      if ( $self->{'socket'} and $self->{'socket'}->connected() )
      or grep { $self->{'status'} eq $_ } qw(destroy);    #connected
    $self->log( 'info', "connecting to $self->{'protocol'} $self->{'host'}, $self->{'port'}", %{ $self->{'sockopts'} || {} } );
    $self->{'status'}   = 'connecting';
    $self->{'outgoing'} = 1;
    $self->{'port'}     = $1 if $self->{'host'} =~ s/:(\d+)//;
    $self->{'socket'} ||= new IO::Socket::INET(
      'PeerAddr' => $self->{'host'},
      'PeerPort' => $self->{'port'},
      'Proto'    => $self->{'Proto'} || 'tcp',
      #    'Type'     => SOCK_STREAM,
      'Timeout' => $self->{'Timeout'}, (
        $self->{'nonblocking'}
        ? (
          'Blocking'   => 0,
          'MultiHomed' => 1,    #del
          )
        : ()
      ),
      #    'Blocking' => 0,
      %{ $self->{'sockopts'} || {} },
    );
    $self->log( 'err', "connect socket  error: $@, $! [$self->{'socket'}]" ), return 1
      if !$self->{'socket'};
    $self->get_my_addr();
    $self->log(
      'info', "connect to $self->{'host'} [me=$self->{'myip'}] ok ",    #socket=[$self->{'socket'}]
    );                                                                  # Dumper($self->{'sockopts'})
    $self->cmd('connect_aft');
    $self->recv();
    return 0;
  };
  $self->{'connect_check'} ||= sub {
    #sub connect_check {
    my $self = shift;
#  $self->{'log'}->($self, 'trace', 'DC::connect_check' , $self->{'Proto'} eq 'udp'      or $self->{'status'} eq 'listening'      or ( $self->{'socket'} and $self->{'socket'}->connected() )      or !$self->active());
    return 0
      if $self->{'Proto'} eq 'udp'
        or $self->{'status'} eq 'listening'
        or ( $self->{'socket'} and $self->{'socket'}->connected() )
        or !$self->active();
    $self->{'status'} = 'reconnecting';
    #$self->{'reconnects'}
    #$self->{'reconnect_sleep'},
    #        $self->log(          'warn', 'connect_check: must reconnect');
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
          #return if $self->{'socket'};
          #sleep $self->{'reconnect_sleep'};
        }
      }
    );
  };
  $self->{'reconnect'} ||= sub {
    #sub reconnect {
    my $self = shift;
    $self->disconnect();
    $self->{'status'} = 'reconnecting';
    $self->connect();
  };
  $self->{'listen'} ||= sub {
    #sub listen {
    my $self = shift;
    return if !$self->{'Listen'} or ( $self->{'M'} eq 'P' and !$self->{'allow_passive_ConnectToMe'} );
    for ( 1 .. $self->{'myport_tries'} ) {
      $self->{'socket'} ||= new IO::Socket::INET(
        'LocalPort' => $self->{'myport'},
        'Proto'     => $self->{'Proto'} || 'tcp',
        #      'Type'      => SOCK_STREAM,
        ( $self->{'Proto'} ne 'udp' ? ( 'Listen' => $self->{'Listen'} ) : () ),
        ( $self->{'nonblocking'} ? ( 'Blocking' => 0 ) : () ),
        #    ($^O eq 'MSWin32' ? () : ('Blocking'  => 0)),
        %{ $self->{'sockopts'} or {} },
      );
      last if $self->{'socket'};
      $self->log( 'err', "listen $self->{'myport'} socket error: $@" ), $self->myport_generate(1),
        unless $self->{'socket'};
    }
    return unless $self->{'socket'};
    $self->log( 'dcdbg', "listening $self->{'myport'} $self->{'Proto'}" );    # , Dumper($self->{'sockopts'}));
         #    $self->log( 'dcdbg', "[$self->{'number'}] listening $self->{'myport'} ok" );
    $self->{'accept'} = 1 if $self->{'Proto'} ne 'udp';
    $self->{'status'} = 'listening';
    $self->recv();
    #    $self->log( 'dcdbg', "[$self->{'number'}] listen exit" );
  };
  $self->{'disconnect'} ||= sub {
    #sub disconnect {
    my $self = shift;
    #  $self->handler('disconnect_bef');
    $self->{'status'} = 'disconnected';
    #        $self->log( 'dev', "[$self->{'number'}] disconnected status=",$self->{'status'});
    if ( $self->{'socket'} ) {
      #    $self->log( 'dev', "[$self->{'number'}] Closing socket",
      #    $self->{'socket'}->shutdown(2);
      $self->{'socket'}->close();
#        $self->log( 'dev', "[$self->{'number'}] aftershutdown=", $self->{'socket'}->connected, 'opened=', $self->{'socket'}->opened);
#    );
      delete $self->{'socket'};
    }
    delete $self->{'select'};
#  $self->log('dev',"delclient($self->{'clients'}{$_}->{'number'})[$_][$self->{'clients'}{$_}]\n") for grep {$_} keys %{ $self->{'clients'} };
    if ( $self->{'disconnect_recursive'} ) {
      for ( grep { $self->{'clients'}{$_} } keys %{ $self->{'clients'} } ) {
        $self->{'clients'}{$_}->destroy() if ref $self->{'clients'}{$_};
        delete( $self->{'clients'}{$_} );
      }
    }
    close( $self->{'filehandle'} ), delete $self->{'filehandle'} if $self->{'filehandle'};
    delete $self->{$_} for qw(NickList IpList PortList);
    $self->log( 'info', "disconnected" );
    #          $self->log('dev', caller($_)) for 0..5;
    #  $self->handler('disconnect_aft');
  };
  $self->{'destroy'} ||= sub {
    #sub destroy {
    my $self = shift;
    $self->disconnect() if ref $self;
    #      $self->log( 'dcdbg', "[$self->{'number'}]($self)TOTAL MANUAL DESTROY from ", join( ':', caller ), " ($self)" );
    #!?  delete $self->{$_} for keys %$self;
    $self->{'status'} = 'destroy';
    #  $self = undef;
    %$self = ();
  };
  #sub END {
  #  my $self = shift;
  #print "\ndcppp END\n" ;
  #}
  $self->{'recv'} ||= sub {
    #sub recv {
    my $self = shift;
  #$self->log( 'trace', 'DC::recv', $self->{'number'} );
  #$self->log( 'trace', 'DC::recv ret runned', $self->{'number'} ), return '0E0' if $self->{'recv_runned'}{ $self->{'number'} };
    $self->{'recv_runned'}{ $self->{'number'} } = 1;
    my $sleep = shift || 0;
    my $ret = 0;
    $self->connect_check();
#    $self->log( 'dev', 'cant recv, ret' ), 
return unless $self->{'socket'} and ($self->{'status'} eq 'listening' or $self->{'socket'}->connected);
  #                $self->log( 'dcdbg',"[$self->{'number'}] recv $self->{'select'};$self->{'socket'}") if $self->{'number'} > 3;
    $self->{'select'} = IO::Select->new( $self->{'socket'} ) if !$self->{'select'} and $self->{'socket'};
    my ( $readed, $reads );
    $self->{'databuf'} = '';
    #  my $reads = 5;
    #LOOP:
    #$self->log( 'trace', 'DC::recv', 'bef loop' );
    {
      do {
        #$self->log( 'trace', 'DC::recv', 'in loop', $reads );
        $readed = 0;
        $ret = '0E0', last unless $self->{'select'} and $self->{'socket'};
#      $self->info();
#                $self->log( 'dcdbg',"[$self->{'number'}] canread r=$readed w=$sleep $self->{'select'};$self->{'socket'}") if $self->{'number'} > 3;
        $self->log( 'err', "SOCKET UNEXISTS must delete select" )
          unless $self->{'select'}->exists( $self->{'socket'} );
        $self->log( 'err', "SOCKET IS NOT CONNECTED must delete select" )
          if !$self->{'accept'}
            and !$self->{'socket'}->connected()
            and $self->{'Proto'} ne 'udp';
        for my $client ( $self->{'select'}->can_read($sleep) ) {
          #        #$self->log( 'trace', 'DC::recv', 'can_read' );
          if ( $self->{'accept'} and $client eq $self->{'socket'} ) {
            if ( $_ = $self->{'socket'}->accept() ) {
                      $self->log( 'trace', 'DC::recv', 'accept' , $self->{'incomingclass'});
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
              );    #unless $self->{'clients'}{$_};
              ++$ret;
              #          } elsif ($self->{'Proto'} eq 'udp') {
              #        if ( !defined(
              #$client->recv( $self->{'databuf'}, POSIX::BUFSIZ, $self->{'recv_flags'} );
              #) )
              #$self->log( 'dev', "rcv udp [$self->{'databuf'}]");
            } else {
              $self->log( 'err', "Accepting fail! [$self->{'Proto'}]" );
            }
            next;
          }
          $self->log( 'dev', "SOCKERR", $client, $self->{'socket'}, $self->{'select'} )
            if $client ne $self->{'socket'};
          $self->{'databuf'} = '';
          #       local $_;
          #$self->log( 'trace', 'DC::recv', 'recv bef' );
          if ( !defined( $client->recv( $self->{'databuf'}, POSIX::BUFSIZ, $self->{'recv_flags'} ) )
            or !length( $self->{'databuf'} ) )
          {
            #          $self->log( 'dcdbg',  "recv err, " );
            #          $self->log( 'dcdbg',  "recv err, 2" );
            #          $self->log( 'dcdbg',  "recv err, rem" , $self->{'select'}->remove($client) );
            #          $self->log( 'dcdbg',  "recv err, chk ", $self->active() );
            #not now
            if (  $self->active()
              and $self->{'reconnect_tries'}++ < $self->{'reconnects'} )
            {
              #          $self->log( 'dcdbg',  "recv err, reconnect," );
              $self->reconnect();
            } else {
              #          $self->log( 'dcdbg',  "recv err, disconnect," );
              $self->destroy();
            }
            #!          $self->{'status'} = 'destroy';
            #}        elsif (!length( $self->{'databuf'} ) ) {
            #    $self->log( 'dcdbg', "[$self->{'number'}]","recv warn, len=", length( $self->{'databuf'} )  );
          } else {
            ++$readed;
            ++$ret;
#                   $self->log( 'dcdmp', "[$self->{'number'}]", "raw recv ", length( $self->{'databuf'} ), $self->{'databuf'} );
          }
          if ( $self->{'filehandle'} ) { $self->writefile( \$self->{'databuf'} ); }
          else {
            $self->{'buf'} .= $self->{'databuf'};
#        $self->{'buf'} =~ s/(.*\|)//s;
#        for ( split /\|/, $1 ) {
#        while ($self->{'buf'} =~ s/^([^|]+)\|//) {
#TODO HERE !!!
#          my $endmsg = '[' . ( $self->{'buf'} =~ /^CSND\s/ ? "\n" : '' ) . '|]';
#          my $endmsg = '[' . ( $self->{'buf'} =~ /^[BCDEFHITU][A-Z]{,3}\s/ ? "\n" : $self->{'buf'} =~ /^[$<]/ ? '|':"\n" ) . ']';
#          my $endmsg =  ( $self->{'buf'} =~ /^[BCDEFHITU][A-Z]{,3}\s/ ? "\n" : $self->{'buf'} =~ /^[$<]/ ? '|':"\n" ) ;
#my $separator = "\n"; $separator = "\\|" if $self->{'buf'} =~ /^[\$<*]/; #stupid hubs
#          my $separator = "\\|";
#          $separator
            local $self->{'cmd_aft'} = "\x0A" if $self->{'protocol'} ne 'adc' and $self->{'buf'} =~ /^[BCDEFHITU][A-Z]{,5} /;
#                    $self->log( 'dcdbg', "[$self->{'number'}]", "raw to parse [$self->{'buf'}] sep[$self->{'cmd_aft'}]" ) unless $self->{'filehandle'};
            while ( $self->{'buf'} =~ s/^(.*?)\Q$self->{'cmd_aft'}//s ) {
              local $_ = $1;
#              $self->log('dcdmp', 'DC::recv', "parse [$_]($self->{'cmd_aft'})");
              last if $self->{'status'} eq 'destroy';
              #                 $self->log( 'dcdbg',"[$self->{'number'}] dev cycle ",length $_," [$_]", );
              last unless length $_ and length $self->{'cmd_aft'};
#              next unless /\w/;
              next unless length;
              $self->parser($_);
              #(
              #                /^\$/ ? '' :                      '$'                  .

=z
  (
                  defined( $self->{'parse'}{ (/^\$?(\S+)/)[0] } )
                  ? ''
                  : ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' ) . ' '
#                  )
              )
              . 
=cut
      #          $self->parse( /^\$/ ? $_ : ( #$_ =
      #                    '$' . ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' ) . ' ' . $_) );
      #                 $self->log( 'dcdbg',"[$self->{'number'}] dev lastexit ",length($self->{'buf'} )," [$self->{'buf'} ]", ),
              last if ( $self->{'filehandle'} );
            }
            $self->writefile( \$self->{'buf'} ), $self->{'buf'} = '' if length( $self->{'buf'} ) and $self->{'filehandle'};
          }
        }
        #     $self->log( 'dcdbg',"[$self->{'number'}] canread fin r=$readed");
        #$self->log( 'trace', 'DC::recv', $self->{'number'}, 'loop fin' );
      } while ( $readed and $reads++ < $self->{'max_reads'} );
      # TODO !!! timed
    }
    #$self->log( 'trace', 'DC::recv', $self->{'number'}, 'looking at clients' );
    for ( keys %{ $self->{'clients'} } ) {
      #    $self->{'clients'}{$_} = undef,
      $self->log( 'dev', "del client[$self->{'clients'}{$_}{'number'}][$_]", ),
        #    $self->{'clients'}{$_}->destroy(),
        delete( $self->{'clients'}{$_} ),
        $self->log( 'dev', "now clients", map { "[$self->{'clients'}{$_}{'number'}]$_" } keys %{ $self->{'clients'} } ), next
        if !$self->{'clients'}{$_}{'socket'}
          or !$self->{'clients'}{$_}{'status'}
          or $self->{'clients'}{$_}{'status'} eq 'destroy';
      $ret += $self->{'clients'}{$_}->recv();
    }
    #!  ++$ret, $self->destroy() if $self->{'status'} eq 'destroy';
    $self->{'recv_runned'}{ $self->{'number'} } = undef;
    #$self->log( 'trace', 'DC::recv', $self->{'number'}, 'return' );
    return $ret;
  };
  $self->{'wait'} ||= sub {
    #sub wait {
    my $self = shift;
    #        $self->log('waitR:', join(',',@_));
    my ( $waits, $wait_once ) = @_;
    #        $self->log('dctim', "[$self->{'number'}] waitR[$waits, , $wait_once]");
    $waits     ||= $self->{'waits'};
    $wait_once ||= $self->{'wait_once'};
    local $_;
    my $ret;
    #          $self->log('dctim', "[$self->{'number'}] wait [$waits, $ret, $wait_once]"),
    $ret += $self->recv($wait_once) while --$waits > 0 and !$ret;
    #        $self->log('dctim', "[$self->{'number'}] waitret");
    return $ret;
  };
  $self->{'finished'} ||= sub {
    #sub finished {
    my $self = shift;
    $self->log( 'dcdev', 'not finished file:', "$self->{'filebytes'} / $self->{'filetotal'}", $self->{'peernick'} ), return 0
      if ( $self->{'filebytes'} and $self->{'filetotal'} and $self->{'filebytes'} < $self->{'filetotal'} - 1 );
    local @_;
    $self->log( 'dcdev', 'not finished clients:', @_ ), return 0
      if @_ = grep { !$self->{'clients'}{$_}->finished() } keys %{ $self->{'clients'} };
    return 1;
  };
  $self->{'wait_connect'} ||= sub {
    #sub wait_connect {
    my $self = shift;
    for ( 0 .. ( $_[0] || $self->{'wait_connect'} ) ) {
      last if $self->{'status'} eq 'connected';
      $self->wait(1);
    }
    return $self->{'status'};
  };
  $self->{'wait_finish'} ||= sub {
    #sub wait_finish {
    my $self = shift;
    for ( 0 .. $self->{'wait_finish'} ) {
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
    #sub wait_clients {
    my $self = shift;
    for ( 0 .. $self->{'wait_clients'} ) {
      last if $self->{'clients_max'} > scalar keys %{ $self->{'clients'} };
      $self->info() unless $_;
      $self->log( 'info',
        "wait clients " . scalar( keys %{ $self->{'clients'} } ) . "/$self->{'clients_max'}  $_/$self->{'wait_clients'}" );
      #    $self->log( 'info',      "wait RUN", undef, $self->{'wait_clients_by'} );
      $self->wait( undef, $self->{'wait_clients_by'} );
    }
  };
  $self->{'wait_sleep'} ||= sub {
    #sub wait_sleep {
    my $self      = shift;
    my $how       = shift || 1;
    my $starttime = time();
    $self->wait(@_) while $starttime + $how > time();
  };
  $self->{'work'} ||= sub {
    #sub work {
    my $self = shift;
    #  $self->log( 'trace', 'DC::work' );
    my @params = @_;
    #  $self->{'periodic'}->() if ref $self->{'periodic'} eq 'CODE';
    $self->periodic();
    return $self->wait_sleep(@params) if @params;
    return $self->recv( $self->{'work_sleep'} );
  };
  $self->{'parser'} ||= sub {
    #sub parse {
    my $self = shift;
    for ( local @_ = @_ ) {
      #    s/^\$(\w+)\s*//;
      #                  defined( $self->{'parse'}{ (/^\$?(\S+)/)[0] } )
      #                  ? ''
      #                  : ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' ) . ' '
      my $cmd;
      $cmd = ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' ) if /^[<*]/;
      s/^\$?([\w\-]+)\s*//, $cmd = $1 unless $cmd;
      #return if $cmd eq 'log' and ;
      $self->log( 'dcinf', "UNKNOWN PEERCMD:[$cmd]{$_} : please add \$dc->{'parse'}{'$cmd'} = sub { ... };" ),
        $self->{'parse'}{$cmd} = sub { }, $cmd = ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' )
        unless exists $self->{'parse'}{$cmd};
      my ( @ret, $ret );
      #    $self->log( 'dcinf', "parsing", $cmd, @_ ,'with',$self->{'parse'}{$cmd}, ref $self->{'parse'}{$cmd});
      #print "[$self->{'number'}] CMD:[$cmd]{$_}\n" unless $cmd eq 'Search';
      $self->handler( $cmd . '_parse_bef_bef', $_ );
      #    $self->log( 'dcinf', "parsing1", $cmd, @_ ,'with',$self->{'parse'}{$cmd}, ref $self->{'parse'}{$cmd});
      if ( ref $self->{'parse'}{$cmd} eq 'CODE' ) {
        #    $self->log( 'dcinf', "parsing2", $cmd, @_ ,'with',$self->{'parse'}{$cmd});
        if (
          !exists $self->{'no_print'}{$cmd}
          #( $self->{'print_search'} or $cmd ne 'Search' ) and ( $self->{'print_myinfo'} or $cmd ne 'MyINFO' )
          )
        {
          local $_ = $_;
          local @_ =
            map { "$_:$self->{'skip_print_'.$_}" } grep { $self->{ 'skip_print_' . $_ } } keys %{ $self->{'no_print'} || {} };
          $self->log(
            'dcdmp',
            "rcv: $cmd $_",
            ( @_ ? ( '  [', @_, ']' ) : () )
              #          ( $self->{'skip_print_search'} ? ", skipped searches: $self->{'skip_print_search'}" : () ),
              #          ( $self->{'skip_print_myinfo'} ? ", skipped myinfos: $self->{'skip_print_myinfo'}"  : () ),
          );
          $self->{ 'skip_print_' . $_ } = 0 for keys %{ $self->{'no_print'} || {} };
          #        $self->{'skip_print_search'} = $self->{'skip_print_myinfo'} = 0;
        } else {
          #        ++$self->{'skip_print_search'} if !$self->{'print_search'} and $cmd eq 'Search';
          #       ++$self->{'skip_print_myinfo'} if !$self->{'print_myinfo'} and $cmd eq 'MyINFO';
          ++$self->{ 'skip_print_' . $cmd },
            #printlog('dcdev', 'savenoprint', $cmd,  $self->{'skip_print_'.$cmd}),
            if exists $self->{'no_print'}{$cmd};
        }
        #print "[$self->{'number'}] rcv: $cmd $_\n" if $cmd ne 'Search' and $self->{'debug'};
        #    $self->log( 'dcinf', "parsing3", $cmd, @_ ,'with',$self->{'parse'}{$cmd});
        $self->handler( $cmd . '_parse_bef', $_ );
        #    $self->log( 'dcinf', "parsing5", $cmd, @_ ,'with',$self->{'parse'}{$cmd});
        #      $self->log( 'dev',"parse: $cmd $_\n") if $cmd ne 'Search';
        #    $self->log( 'dcinf', "parsing5", $cmd, @_ ,'with',$self->{'parse'}{$cmd});
        @ret = $self->{'parse'}{$cmd}->($_);
        $ret = scalar @ret > 1 ? \@ret : $ret[0];
        $self->handler( $cmd . '_parse_aft', $_, $ret );
      }
      #    } else {
      #    }
      $self->handler( $cmd, $_, $ret );
      $self->handler( $cmd . '_parse_aft_aft', $_, $ret );
    }
  };
  #{
  #  my @sendbuf;
  $self->{'sendcmd'} ||= sub {
    #  sub sendcmd {
    my $self = shift;
    #      $self->{'log'}->($self, 'dcdmp', "sendcmd1" , $self->{'sendbuf'});
    $self->connect_check();
    push @{ $self->{'send_buffer'} }, $self->{'cmd_bef'} . join( $self->{'cmd_sep'}, @_ ) . $self->{'cmd_aft'} if @_;
    $self->log( 'err', "ERROR! no socket to send" ), return unless $self->{'socket'};
    #    if ( $self->{'sendbuf'} ) { push @sendbuf, '$' . join( ' ', @_ ) . '|'; }
    if ( ( $self->{'sendbuf'} and @_ ) or !@{ $self->{'send_buffer'} || [] } ) { }
    else {
      local $_;
#$self->log( "atmark:", $self->{'socket'}->atmark, " timeout=",$self->{'socket'}->timeout,  'conn=',$self->{'socket'}->connected,'so=', $self->{'socket'});
#      $self->{'log'}->($self, 'dcdmp', "sendcmd2" );
      eval { $_ = $self->{'socket'}->send( join( '', @{ $self->{'send_buffer'} }, ) ); };    #'$' . join( ' ', @_ ) . '|'
      $self->log( 'err', 'send error', $@ ) if $@;
      $self->{'log'}->( $self, 'dcdmp', "we send [" . join( '', @{ $self->{'send_buffer'} } ) . "]:", $_, $! )
        ;                                                                                    #'$' . join( ' ', @_ ) . '|' )
      $self->{'send_buffer'} = [];
      #      $self->{'log'}->($self, 'dcdmp', "sendbuf now", @sendbuf  ); #'$' . join( ' ', @_ ) . '|' )
    }
    #      $self->{'log'}->($self, 'dcdmp', "sendcmd3" );
  };
  #}
  $self->{'rcmd'} ||= sub {
    #sub rcmd {
    my $self = shift;
    eval {
      eval { $_->cmd(@_) }, $self->wait_sleep( $self->{'cmd_recurse_sleep'} )
        for grep { $_ } values( %{ $self->{'clients'} } ), $self;
    };
    #  $self->cmd(@_);
  };
  $self->{'get'} ||= sub {
    #sub get {
    my ( $self, $nick, $file, $as ) = @_;
    $self->wait_clients();
    $self->{'want'}->{$nick}{$file} = $as || $file;
    $self->log( 'dbg', "getting [$nick]" );
    $self->cmd( ( ( $self->{'M'} eq 'A' and $self->{'myip'} and !$self->{'passive_get'} ) ? '' : 'Rev' ) . 'ConnectToMe',
      $nick );
  };
  $self->{'openfile'} ||= sub {
    #sub openfile {
    my $self = shift;
    my $oparam = ( ( $self->{'fileas'} eq '-' ) ? '>-' : '>' . ( $self->{'fileas'} || $self->{'filename'} ) );
    $self->handler( 'openfile_bef', $oparam );
    $self->log( 'dbg', "openfile pre", $oparam );
    open( $self->{'filehandle'}, $oparam )
      or $self->log( 'dcerr', "openfile error", $!, $oparam ), $self->handler( 'openfile_error', $!, $oparam ), return 1;
    binmode( $self->{'filehandle'} );
    #  $self->handler('openfile_aft');
    $self->{'status'} = 'transfer';
    return 0;
  };
  $self->{'writefile'} ||= sub {
    #sub writefile {
    my $self = shift;
    $self->{'file_start_time'} ||= time;
    #  $self->handler('writefile_bef');
    my $fh = $self->{'filehandle'} || return;
    #print "FH:",$fh, Dumper($fh);
    for my $databuf (@_) {
      $self->{'filebytes'} += length $$databuf;
#       $self->log( 'dcdbg', "($self->{'number'}) recv ".length($$databuf)." [$self->{'filebytes'}] of $self->{'filetotal'} file $self->{'filename'}" );
      $self->log( 'dcdbg', "recv " . length($$databuf) . " [$$databuf]" ) if length $$databuf < 10;
      print $fh $$databuf;
      $self->log( 'err', "file download error! extra bytes ($self->{'filebytes'}/$self->{'filetotal'}) " )
        if $self->{'filebytes'} > $self->{'filetotal'};
      #    close($fh),
      $self->log(
        'info',
        "file complete ($self->{'filebytes'}) per",
        $self->float( time - $self->{'file_start_time'} ),
        's at', $self->float( $self->{'filebytes'} / ( ( time - $self->{'file_start_time'} ) or 1 ) ), 'b/s'
        ),
        $self->disconnect(), $self->{'status'} = 'destroy', $self->{'file_start_time'} = 0
        if $self->{'filebytes'} >= $self->{'filetotal'};
    }
  };
  $self->{'get_peer_addr'} ||= sub {
    #sub get_peer_addr {
    my ($self) = @_;
    return unless $self->{'socket'};
    eval { @_ = unpack_sockaddr_in( getpeername( $self->{'socket'} ) ) };
    return unless $_[1];
    return unless $_[1] = inet_ntoa( $_[1] );
    $self->{'port'} = $_[0] if $_[0] and !$self->{'incoming'};
    return $self->{'host'} = $_[1] if $_[1];
  };
  $self->{'get_my_addr'} ||= sub {
    #sub get_my_addr {
    my ($self) = @_;
    return unless $self->{'socket'};
    eval { @_ = unpack_sockaddr_in( getsockname( $self->{'socket'} ) ) };
    return unless $_[1];
    return unless $_[1] = inet_ntoa( $_[1] );
    #  $self->{'log'}->('dev', "MYIP($self->{'myip'}) [$self->{'number'}] SOCKNAME $_[0],$_[1];");
    return $self->{'myip'} ||= $_[1];
  };
  # http://www.dcpp.net/wiki/index.php/LockToKey :
  $self->{'lock2key'} ||= sub {
    #sub lock2key {
    my $self = shift;
    #    $self->log('info', 'lock2key from', @_) ;
    my @lock = split( //, shift );
    my $i;
    my @key = ();
    # convert to ordinal
    foreach (@lock) { $_ = ord; }
    # calc key[0] with some xor-ing magic
    push( @key, $lock[0] ^ 5 );
    # calc rest of key with some other xor-ing magic
    for ( $i = 1 ; $i < @lock ; $i++ ) { push( @key, ( $lock[$i] ^ $lock[ $i - 1 ] ) ); }
    # nibble swapping
    for ( $i = 0 ; $i < @key ; $i++ ) { $key[$i] = ( ( ( $key[$i] << 4 ) & 240 ) | ( ( $key[$i] >> 4 ) & 15 ) ) & 0xff; }
    #temp[0] = (u_int8_t)(temp[0] ^ temp[aLock.length()-1]);
    $key[0] = $key[0] ^ $key[ @key - 1 ];
    # escape some
    foreach (@key) {
      if ( $_ == 0 || $_ == 5 || $_ == 36 || $_ == 96 || $_ == 124 || $_ == 126 ) { $_ = sprintf( '/%%DCN%03i%%/', $_ ); }
      else                                                                        { $_ = chr; }
    }
    # done
    #    $self->log('info', 'lock2key', @key) ;
    return join( '', @key );
  };
  $self->{'tag'} ||= sub {
    #sub tag {
    my $self = shift;
    $self->{'client'} . ' ' . join( ',', map $_ . ':' . $self->{$_}, grep defined( $self->{$_} ), qw(V M H S O) );
  };
  $self->{'myinfo'} ||= sub {
    #sub myinfo {
    my $self = shift;
    return $self->{'Nick'} . ' '
      . $self->{'description'} . '<'
      . $self->tag() . '>' . '$' . ' ' . '$'
      . $self->{'connection'}
      . ( length( $self->{'flag'} ) ? chr( $self->{'flag'} ) : '' ) . '$'
      . $self->{'email'} . '$'
      . $self->{'sharesize'} . '$';
  };
  $self->{'supports'} ||= sub {
    #sub supports {
    my $self = shift;
    return join ' ', grep $self->{$_}, @{ $self->{'supports_avail'} };
  };
  $self->{'supports_parse'} ||= sub {
    #sub supports_parse {
    my $self = shift;
    my ( $str, $save ) = @_;
    $save->{$_} = 1 for split /\s+/, $str;
    delete $save->{$_} for grep !length $save->{$_}, keys %$save;
    return wantarray ? %$save : $save;
  };
  $self->{'info_parse'} ||= sub {
    #sub info_parse {
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
    #sub tag_parse {
    my $self = shift;
    my ( $tag, $save ) = @_;
    $save->{'tag'} = $tag;
    $tag =~ s/(^\s*<\s*)|(\s*>\s*$)//g;
    $save->{'client'} = $1 if $tag =~ s/^(\S+)\s*//;
    /(.+):(.+)/, $save->{$1} = $2 for split /,/, $tag;
    return wantarray ? %$save : $save;
  };
  $self->{'info'} ||= sub {
    #sub info {
    my $self = shift;
    #local @_ = $self->active();
    #  $self->log('info', 'active', @_) if @_;
    $self->log(
      'info',
      map( {"$_=$self->{$_}"} grep { $self->{$_} } @{ $self->{'informative'} } ),
      map( { $_ . '(' . scalar( keys %{ $self->{$_} } ) . ')=' . join( ',', keys %{ $self->{$_} } ) }
        grep { keys %{ $self->{$_} } } @{ $self->{'informative_hash'} } )
    );
    $self->{'clients'}{$_}->info() for keys %{ $self->{'clients'} };
  };
 #sub active {  my $self = shift;  return map { $_->{'number'} } grep { $_->{'socket'} } $self, values %{ $self->{'clients'} };}
  $self->{'active'} ||= sub {
    #sub active {
    my $self = shift;
    #  $self->log( 'trace', 'DC::active' );
    return $self->{'status'} if grep { $self->{'status'} eq $_ } qw(connecting connected reconnecting listening transfer);
    return 0;
  };
  #sub status {
  #now states:
  #listening  connecting   connected   reconnecting transfer  disconnecting disconnected destroy
  #need checks:
  #                        \ connected?/             \-----/
  #\-----------------------active?-------------------------/
  #}
  #my %every;
  $self->{'every'} ||= sub {
    #sub every {
    my ( $self, $sec, $func ) = ( shift, shift, shift );
# $self-> log('dev','every1', $sec, $self->{'every_list'}{$func}, time, $func );
# $self->log('dev','every1', $sec, $self->{'every_list'}{$func}, time, $func ,$self->{'every_list'}{$func} + $sec, $self->{'every_list'}{$func} + $sec < time, ref $func, ($self->{'every_list'}{$func} + $sec < time and ref $func eq 'CODE'));
    if ( ( $self->{'every_list'}{$func} + $sec < time ) and ( ref $func eq 'CODE' ) ) {
      $self->{'every_list'}{$func} = time;
# $self->log('dev','every1', $sec, $self->{'every_list'}{$func}, time, $func ,$self->{'every_list'}{$func} + $sec, $self->{'every_list'}{$func} + $sec < time, ref $func, ($self->{'every_list'}{$func} + $sec < time and ref $func eq 'CODE'));
# print('dev','every2', $sec, $self->{'every_list'}{$func}, time, $func ,$self->{'every_list'}{$func} + $sec, $self->{'every_list'}{$func} + $sec < time, ref $func, ($self->{'every_list'}{$func} + $sec < time and ref $func eq 'CODE')),
      $func->(@_);
    }
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
sharing
segmented, multisource download
async connect
full ADC

=head1 INSTALLATION

To install this module type the following:

   perl Makefile.PL && make install clean
   

=head1 SEE ALSO

# pro http://pro.setun.net/dcppp/
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



=head1 AUTHOR

Oleg Alexeenkov, E<lt>pro@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005-2009 Oleg Alexeenkov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
