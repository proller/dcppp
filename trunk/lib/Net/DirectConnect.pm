#$Id$ $URL$
package Net::DirectConnect;
use strict;
our $VERSION = '0.04' . '_' . ( split( ' ', '$Revision$' ) )[1];
no warnings qw(uninitialized);
use Socket;
use IO::Socket;
use IO::Select;
use POSIX;
use Time::HiRes qw(time);
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
our $AUTOLOAD;
our %global;

sub float {    #v1
  my $self = shift if ref $_[0];
  return ( $_[0] < 8 and $_[0] - int( $_[0] ) )
    ? sprintf( '%.' . ( $_[0] < 1 ? 3 : ( $_[0] < 3 ? 2 : 1 ) ) . 'f', $_[0] )
    : int( $_[0] );
}

sub send_udp ($$;@) {
  my $self = shift if ref $_[0];
  #$self->log('dcdev', "sending UDP0:", Dumper \@_);
  my $host = shift;
  $host =~ s/:(\d+)$//;
  my $port = shift;
  #$port = $1 || shift ;
  #$port = shift ;
  $port ||= $1;
  $self->log( 'dcdev', "sending UDP to [$host]:[$port] = [$_[0]]" );
  my $opt = $_[1] || {};
  if (
    my $s = new IO::Socket::INET(
      'PeerAddr' => $host,
      'PeerPort' => $port,
      'Proto'    => 'udp',
      'Timeout'  => $opt->{'Timeout'}, (
        $opt->{'nonblocking'}
        ? (
          'Blocking'   => 0,
          'MultiHomed' => 1,    #del
          )
        : ()
      ),
      %{ $opt->{'sockopts'} || {} },
    )
    )
  {
    #$self->log('dcdev', "sending UDP to [$host]:[$port] RES=" ,$s->send($_[0]));
    $s->send( $_[0] );
    $self->{bytes_send} += length $_[0];
    $s->close();
  } else {
    $self->log( 'dcerr', "FAILED sending UDP to $host :$port = [$_[0]]" );
  }
}

sub schedule($$;@)
{    #$Id$ $URL$
  our %schedule;
  #for (1..100000000) { psmisc::schedule(10, our $my_every_10sec_sub__ ||= sub { print "every 10 sec"})};
  my ( $every, $func ) = ( shift, shift );
  my $p;
  ( $p->{'wait'}, $p->{'every'}, $p->{'runs'}, $p->{'cond'}, $p->{'id'} ) = @$every if ref $every eq 'ARRAY';
  $p = $every if ref $every eq 'HASH';
  $p->{'every'} ||= $every if !ref $every;
  $p->{'id'} ||= join ';', caller;
  #$p->{'id'} ||= $func;
  $schedule{ $p->{'id'} }{'func'} = $func if !$schedule{ $p->{'id'} }{'func'} or $p->{'update'};
  $schedule{ $p->{'id'} }{'last'} = time - $p->{'every'} + $p->{'wait'} if $p->{'wait'} and !$schedule{ $p->{'id'} }{'last'};
  #printlog 'everyS1', $schedule{ $p->{'id'} }{'func'}, $func,Dumper([ $every,  $schedule{ $p->{'id'} } ], $p), caller;
  #printlog 'everyS4', Dumper([ $every, $func, $p, $schedule{$func} ]), $func;
  #printlog('dev','everyR', Dumper($p, $schedule{$p->{'id'}} ), time, $func ),
  $schedule{ $p->{'id'} }{'func'}->(@_), $schedule{ $p->{'id'} }{'last'} = time
    if ( $schedule{ $p->{'id'} }{'last'} + $p->{'every'} < time )
    and ( !$p->{'runs'} or $schedule{ $p->{'id'} }{'runs'}++ < $p->{'runs'} )
    and ( !( ref $p->{'cond'} eq 'CODE' ) or $p->{'cond'}->( $p, $schedule{ $p->{'id'} }, @_ ) )
    and ref $schedule{ $p->{'id'} }{'func'} eq 'CODE';
}

=del
sub clear {
  return map { $_ => undef } qw(
    clients
    socket
    select
    accept
    filehandle
    parse
    cmd
    send_buffer
    databuf
    buf
    peers
    supports_avail
    auto_connect
    auto_work
    number
  );
  #
}
=cut

sub module_load {
  my $self = shift if ref $_[0];
  local $_ = shift;
  #for (@_) {
  return unless length $_;
  #%self
  #my $module = __PACKAGE__ . '::' . $self->{'module'};
  my $module = __PACKAGE__ . '::' . $_;
#  $self->log( 'dev', 'try load module', $_, $module, );
  #eval "use $module; $module\->init(\$self);";
  eval "use $module;";
  $self->log( 'err', 'cant load', $module, $@ ) if $@;
#  $self->log( 'dev', 'try new', $module );
  eval "$module\::new(\$self, \@_);";    #, \@param
  $self->log( 'err', 'cant new', $module, $@ ) if $@;
#  $self->log( 'dev', 'try init', $module );
  eval "$module\::init(\$self, \@_);";    #, \@param
  $self->log( 'err', 'cant init', $module, $@ ) if $@;
  $self->log( 'dev', 'loaded  module', $_, $module, );
  #}
}

sub new {
  my $class = shift;
  #psmisc::printlog( 'dev', __PACKAGE__, 'new', $class, 'refc=',ref $class, 'next=', $_[0], 'refnext=', ref$_[0], scalar @_ );
#  print 'NEW', __PACKAGE__, "\n";
  #my @param = @_;
  my $self = {};
  if ( ref $class eq __PACKAGE__ ) { $self = $class; }
  else {
    #$self  =   {
    bless( $self, $class ) unless ref $class;
    #psmisc::printlog('dev', 'blessed', "self=$self, class=$class package=", __PACKAGE__);
    #print (  'init ', 'class ', $class, __LINE__,,"[  ]\n\n");
    #$self->log( 'dev', 'prefunc', $self, $class );
  }
  local %_ = (
    'Listen'      => 10,
    'Timeout'     => 5,
    'myport'      => 412,                                                   #first try
    'myport_base' => 40000, 'myport_random' => 1000, 'myport_tries' => 5,
    #http://www.dcpp.net/wiki/index.php/%24MyINFO
    'description' => 'perl ' . __PACKAGE__ . ' bot',
    #====MOVE TO NMDC
    'connection' => 'LAN(T3)',
    #NMDC1: 28.8Kbps, 33.6Kbps, 56Kbps, Satellite, ISDN, DSL, Cable, LAN(T1), LAN(T3)
    #NMDC2: Modem, DSL, Cable, Satellite, LAN(T1), LAN(T3)
    'flag' => '1',                                                          # User status as ascii char (byte)
    #1 normal
    #2, 3 away
    #4, 5 server               The server icon is used when the client has
    #6, 7 server away          uptime > 2 hours, > 2 GB shared, upload > 200 MB.
    #8, 9 fireball             The fireball icon is used when the client
    #10, 11 fireball away      has had an upload > 100 kB/s.
    'email' => 'billgates@microsoft.com', 'sharesize' => 10 * 1024 * 1024 * 1024 + int rand( 1024 * 1024 ),    #10GB
    'client' => 'perl',    #'dcp++',                                                              #++: indicates the client
    #'protocol' => 'nmdc',    # or 'adc'
    'V' => $VERSION,       #. '_' . ( split( ' ', '$Revision$' ) )[1],    #V: tells you the version number
    #'M' => 'A',      #M: tells if the user is in active (A), passive (P), or SOCKS5 (5) mode
    'H' => '0/1/0'
    , #H: tells how many hubs the user is on and what is his status on the hubs. The first number means a normal user, second means VIP/registered hubs and the last one operator hubs (separated by the forward slash ['/']).
    'S' => '3',      #S: tells the number of slots user has opened
    'O' => undef,    #O: shows the value of the "Automatically open slot if speed is below xx KiB/s" setting, if non-zero
    'lock'     => 'EXTENDEDPROTOCOLABCABCABCABCABCABC Pk=DCPLUSPLUS0.668ABCABC',
    'cmd_sep'  => ' ',
    'no_print' => { map { $_ => 1 } qw(Search Quit MyINFO Hello SR UserCommand) },
    'log'      => sub (@) {
      my $self = ref $_[0] ? shift() : {};
      if ( ref $self->{'parent'}{'log'} eq 'CODE' ) { return $self->{'parent'}->log( "[$self->{'number'}]", @_ ); }
      print( join( ' ', "[$self->{'number'}]", @_ ), "\n" );
    },
    #'auto_recv'          => 1,
    'max_reads'          => 20,
    'wait_once'          => 0.1,
    'waits'              => 100,
    'wait_finish_tries'  => 600,
    'wait_finish_by'     => 1,
    'wait_connect_tries' => 600,
    'clients_max'        => 50,
    'wait_clients_tries' => 200,
    'wait_clients_by'    => 0.01,
    'work_sleep'         => 0.01,
    'select_timeout'     => 1,
    'cmd_recurse_sleep'  => 0,
    #( $^O eq 'MSWin32' ? () : ( 'nonblocking' => 1 ) ),
    'nonblocking' => 1,
    'informative' => [qw(number peernick status host port filebytes filetotal proxy bytes_send bytes_recv)],    # sharesize
    'informative_hash'     => [qw(clients)],    #NickList IpList PortList
    'disconnect_recursive' => 1,
    'reconnects'           => 5,
    'reconnect_sleep'      => 5,
    'partial_ext'          => '.partial',
    'file_send_by'         => 1024 * 1024,      #1024 * 64,
    'local_mask_rfc' => [qw(10 172.[123]\d 192\.168)], 'status' => 'disconnected', time_start => time,
    #'peers' => {},
    #'partial_prefix' => './partial/',
    #ADC
    #number => ++$global{'total'},
    #};
  );
  $self->{$_} ||= $_{$_} for keys %_;
  local %_ = @_;
  $self->{$_} = $_{$_} for keys %_;
  #psmisc::printlog('dev', 'init0', Dumper $self);

=del

for  ( $self->{'module'}, @{$self->{'modules'} || []} ) {
next unless length $_;
      #%self
#my $module = __PACKAGE__ . '::' . $self->{'module'};
      my $module = __PACKAGE__ . '::' . $_;
      #eval "use $module; $module\->init(\$self);";
      eval "use $module; $module\::init(\$self, \@param);";
      $self->log( 'err', 'cant load', $module, $@ ) if $@;
#}
  } #else {
=cut

  #psmisc::printlog('dev', 'func');
  $self->func();    #@param
  eval { $self->{'recv_flags'} = MSG_DONTWAIT; } unless $^O =~ /win/i;
  $self->{'recv_flags'} ||= 0;
  #psmisc::printlog('dev', 'init');
  $self->init();    #@param
  #}
  $self->{'number'} ||= ++$global{'total'};
  ++$global{'count'};
  $self->{activity} = time;
  #$self->{$_} ||= $self->{'parent'}{$_} for grep { exists $self->{'parent'}{$_} } qw(log sockets select select_send);
  #(!$self->{'parent'}{$_} ? () :  $self->{$_} = $self->{'parent'}{$_} ) for qw(log );
  $self->{'log'} = $self->{'parent'}{'log'} if $self->{'parent'}{'log'};
  $self->{$_} ||= $self->{'parent'}{$_} ||= {} for qw(want share_full share_tth sockets handler);
#  $self->log( 'dev', "my number=$self->{'number'} total=$global{'total'} count=$global{'count'}" );
  if ( $class eq __PACKAGE__ ) {
    #local %_ = (@param);
    #for keys
    #$self->{$_} = $_{$_} for keys %_;
#    $self->log( 'init00', $self, "h=$self->{'host'}", 'p=', $self->{'protocol'}, 'm=', $self->{'module'} );
    if ( !$self->{'module'} and !$self->{'protocol'} and $self->{'host'} ) {
      #$self->log( 'proto0 ', $1);
      my $p = lc $1 if $self->{'host'} =~ m{^(.+?)://};
      #$self->protocol_init($p);
      $self->{'protocol'} = $p;
      $self->{'protocol'} = 'nmdc' if !$self->{'protocol'} or $self->{'protocol'} eq 'dchub';
      #$self->{'protocol'}
#      $self->log( 'proto ', $self->{'protocol'} );
    }
    $self->{'module'} ||= $self->{'protocol'};
    if ( $self->{'module'} eq 'nmdc' ) { $self->{'module'} = $self->{'hub'} ? 'hubcli' : 'clihub'; }
    #$self->log( 'module load', $self->{'module'});
    #if ( $self->{'module'} ) {
  }
  #psmisc::printlog('dev', 'modules load', ( $self->{'module'}, @{ $self->{'modules'} || [] } ));
  my @modules;    #= ($self->{'module'});
  for (qw(module modules)) {
    push @modules, @{ $self->{$_} }      if ref $self->{$_} eq 'ARRAY';
    push @modules, keys %{ $self->{$_} } if ref $self->{$_} eq 'HASH';
    push @modules, split /[;,\s]/, $self->{$_} unless ref $self->{$_};
  }
  $self->module_load( $_, ) for (@modules);
  #@param
  #}
  $self->protocol_init();
#  $self->log( 'dev', $self, 'new inited', "MT:$self->{'message_type'}", 'autolisten=', $self->{'auto_listen'} );
  if ( $self->{'auto_listen'} ) { $self->listen(); }
  elsif ( $self->{'auto_connect'} ) {
    #$self->log( $self, 'new inited', "auto_connect MT:$self->{'message_type'}", ' with' );
    $self->connect();
    #$self->work();
    $self->wait_connect();
  }
  if ( $self->{'auto_work'} ) {
    #$self->log( $self, '', "auto_work ", $self->active() );
    while ( $self->active() ) {
      $self->work();    #forever
      #$self->{'auto_work'}->($self) if ref $self->{'auto_work'} eq 'CODE';
    }
    $self->disconnect();
  }
  #@  psmisc::file_rewrite( 'dump.new', Dumper $self);
  return $self;
}

sub log(@) {
  my $self = shift;
  #print 'LOG0 ', $self->{'log'}, '; ';
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
  } elsif ( $self->{'adc'} and length $dst == 1 and length $cmd == 3 ) {
    @ret = $self->cmd_adc( $dst, $cmd, @_ );
  } else {
    $self->log(
      'info', "UNKNOWN CMD:[$cmd]{@_} : please add \$dc->{'cmd'}{'$cmd'} = sub { ... };",
      #Dumper $self->{'cmd'},
      $self->{'parse'}
    );
    $self->{'cmd'}{$cmd} = sub { };
  }
  $ret = scalar @ret > 1 ? \@ret : $ret[0];
  $self->handler( $cmd . $handler . '_aft', \@_, $ret );
  if ( $self->{'cmd'}{$cmd} ) {
    if    ( $self->{'auto_wait'} ) { $self->wait(); }
    elsif ( $self->{'auto_recv'} ) { $self->recv_try(); }
  }
  $self->handler( $cmd . $handler . '_aft_aft', \@_, $ret );
  return wantarray ? @ret : $ret[0];
}

sub AUTOLOAD {
  #psmisc::printlog('autoload', $AUTOLOAD,@_);
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
  print "DESTROYing $self->{number}\n";
  $self->destroy();
  --$global{'count'};
}

sub handler {
  my $self = shift;
  shift if ref $_[0];
  my $cmd = shift;
  #$self->log('dev', 'handler select', $cmd, $self->{'handler_int'}{$cmd}, $self->{'handler'}{$cmd});
  $self->{'handler_int'}{$cmd}->( $self, @_ ) if ref $self->{'handler_int'}{$cmd} eq 'CODE';    #internal lib
  $self->{'handler'}{$cmd}->( $self, @_ ) if ref $self->{'handler'}{$cmd} eq 'CODE';
}
#sub baseinit {
#my $self = shift;
#$self->{'number'} = ++$global{'total'};
#$self->myport_generate();
#$self->{'port'} = $1 if $self->{'host'} =~ s/:(\d+)//;
#$self->{'want'}     ||= {};
#$self->{'NickList'} ||= {};
#$self->{'IpList'}   ||= {};
#$self->{'PortList'} ||= {};
#++$global{'count'};
#$self->{'status'} = 'disconnected';
#$self->protocol_init( $self->{'protocol'} );
#}
sub func {
  my $self = shift;
  #$self->{'log'}->( 'dev', 'func', __PACKAGE__, 'func', __FILE__, __LINE__ );
  $self->{'myport_generate'} ||= sub {
    my $self = shift;
    return $self->{'myport'} unless $self->{'myport_base'} or $self->{'myport_random'};
    $self->{'myport'} = undef if $_[0];
    return $self->{'myport'} ||= $self->{'myport_base'} + int( rand( $self->{'myport_random'} ) );
  };
  $self->{'protocol_init'} ||= sub {
    my $self = shift;
    my ($p) = @_;
    $p ||= $self->{'protocol'} || 'nmdc';
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
    #$self->log( 'protocol inited', $self->{'protocol'}, $self->{'cmd_bef'}, $self->{'cmd_aft'} );
    return $self->{'protocol'};
  };
  $self->{'select_add'} ||= sub {
    my $self = shift;
#$self->{'select'} ||= $self->{parent}{'select'}         $self->{'select_send'} ||= $self->{parent}{'select_send'}    if $self->{parent};
#$self->{'sockets'} ||= $self->{parent}{'sockets'} if $self->{parent};
    $self->{$_} ||= $self->{parent}{$_} ||= IO::Select->new() for qw (select select_send);
    #$self->{'select'}      ||= IO::Select->new();    #$self->{'socket'}
    #$self->{'select_send'} ||= IO::Select->new();    #$self->{'socket'}
    $self->{'select'}->add( $self->{'socket'} );
    $self->{'sockets'}{ $self->{'socket'} } = $self;
#    $self->log( 'dev', 'current select', $self->{'select'}->handles );
  };
  $self->{'connect'} ||= sub {
    my $self = shift;
    #$self->log( $self, 'connect0 inited', "MT:$self->{'message_type'}", ' with' );
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
    $self->{time_start} = time;
    $self->select_add();
    #$self->log( 'dev', "connected0", "[$self->{'socket'}] c=", $self->{'socket'}->connected() );
    $self->get_my_addr();
    $self->get_peer_addr();
    $self->{'hostip'} ||= $self->{'host'};
    #my $localmask ||= join '|', @{ $self->{'local_mask_rfc'} || [] }, @{ $self->{'local_mask'} || [] };
    my $localmask ||= join '|', map { ref $_ eq 'ARRAY' ? @$_ : $_ } grep { $_ } $self->{'local_mask_rfc'},
      $self->{'local_mask'};
    my $is_local_ip = sub ($) {
      #$self->log( 'info', "test ip [$_[0]] in [$localmask] ");
      return $_[0] =~ /^(?:$localmask)\./;
    };
    $self->log( 'info', "my internal ip detected, using passive mode", $self->{'myip'}, $self->{'hostip'}, $localmask ),
      $self->{'M'} = 'P'
      if !$self->{'M'}
        and $is_local_ip->( $self->{'myip'} )
        and !$is_local_ip->( $self->{'hostip'} );
    $self->{'M'} ||= 'A';
    #$self->log( 'info', "mode set [$self->{'M'}] ");
    $self->log( 'info', "connect to $self->{'host'}($self->{'hostip'}):$self->{'port'} [me=$self->{'myip'}] ok ", );
#    $self->log( $self, 'connected1 inited', "MT:$self->{'message_type'}", ' with' );
    $self->cmd('connect_aft');
    #$self->log($self, 'connected2 inited',"MT:$self->{'message_type'}", ' with');
    #$self->log( 'dev', "connect_aft after", );
    $self->recv_try();
    #$self->log( 'dev', "connect recv after", );
    return 0;
  };
  $self->{'connect_check'} ||= sub {
    my $self = shift;
    return 0
      if $self->{'Proto'} eq 'udp'
        or $self->{'incoming'}
        or $self->{'status'} eq 'listening'
        or ( $self->{'socket'} and $self->{'socket'}->connected() )
        or !$self->active();
    $self->{'status'} = 'reconnecting';
    #$self->log(          'warn', 'connect_check: must reconnect');
    $self->every(
      $self->{'reconnect_sleep'},
      $self->{'reconnect_func'} ||= sub {
        if ( $self->{'reconnect_tries'}++ <= $self->{'reconnects'} ) {
          $self->log(
            'warn',
            "reconnecting [$self->{'reconnect_tries'}/$self->{'reconnects'}] every",
            $self->{'reconnect_sleep'}
          );
          $self->connect();
        } else {
          $self->{'status'} = 'disconnected';
        }
      }
    );
    return 1;
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
    $self->log( 'err', 'listen off', "[$self->{'Listen'}] [$self->{'M'}] [$self->{'allow_passive_ConnectToMe'}]" ), return
      if !$self->{'Listen'}
        or ( $self->{'M'} eq 'P' and !$self->{'allow_passive_ConnectToMe'} );    #RENAME
    $self->myport_generate();
    for ( 1 .. $self->{'myport_tries'} ) {
      $self->{'socket'} ||= new IO::Socket::INET(
        'LocalPort' => $self->{'myport'},
        'Proto'     => $self->{'Proto'} || 'tcp',
        ( $self->{'Proto'} ne 'udp' ? ( 'Listen' => $self->{'Listen'} ) : () ),
        ( $self->{'nonblocking'} ? ( 'Blocking' => 0 ) : () ), %{ $self->{'sockopts'} or {} },
      );
      $self->select_add(), last if $self->{'socket'};
      $self->log( 'err', "listen $self->{'myport'} socket error: $@" ), $self->myport_generate(1), unless $self->{'socket'};
    }
    $self->log( 'err', 'cant listen' ), return unless $self->{'socket'};
    $self->log( 'dcdbg', "listening $self->{'myport'} $self->{'Proto'}" );
    $self->{'accept'} = 1 if $self->{'Proto'} ne 'udp';
    $self->{'status'} = 'listening';
    #$self->recv_try();
  };
  $self->{'disconnect'} ||= sub {
    my $self = shift;
    $self->{'status'} = 'disconnected';
    #$self->log( 'dev', "[$self->{'number'}] disconnected status=",$self->{'status'});
    if ( $self->{'socket'} ) {
      #$self->log( 'dev', "[$self->{'number'}] Closing socket",
      $self->{'select'}->remove( $self->{'socket'} )      if $self->{'select'};
      $self->{'select_send'}->remove( $self->{'socket'} ) if $self->{'select_send'};
      delete $self->{'sockets'}{ $self->{'socket'} };
      $self->{'socket'}->close();
      delete $self->{'socket'};
    }
#delete $self->{'select'};
#$self->log('dev',"delclient($self->{'clients'}{$_}->{'number'})[$_][$self->{'clients'}{$_}]\n") for grep {$_} keys %{ $self->{'clients'} };
    if ( $self->{'disconnect_recursive'} ) {
      for my $client ( grep { $self->{'clients'}{$_} and !$self->{'clients'}{$_}{'auto_listen'} } keys %{ $self->{'clients'} } )
      {
        #$self->log( 'dev', "destroy cli", $self->{'clients'}{$_}, ref $self->{'clients'}{$_}),
        $self->{'clients'}{$client}->destroy() if ref $self->{'clients'}{$client} and $self->{'clients'}{$client}{'destroy'};
        $self->{$_} += $self->{'clients'}{$client}{$_} for qw(bytes_recv bytes_send);
        delete( $self->{'clients'}{$client} );
      }
    }
    $self->file_close();
    delete $self->{$_} for qw(NickList IpList PortList peers);
    $self->log( 'info', "disconnected", __FILE__, __LINE__ );
    #$self->log('dev', caller($_)) for 0..5;
  };
  $self->{'destroy'} ||= sub {
    my $self = shift;
    $self->disconnect() if ref $self and !$self->{'destroying'}++;
    #!?  delete $self->{$_} for keys %$self;
    $self->info();
    #$self->{'status'} = 'destroy';
    #$self = {};
    %$self = ();
  };
  $self->{'recv'} ||= sub {
    my $self   = shift;
    my $client = shift;
    #my $socket = shift;
    #$self->log( 'dev', 'recv', $client, $self->{'socket'}, $self->{'accept'});
    if (
      $self->{'accept'}
      #and $client eq $self->{'socket'}
      )
    {
      if ( $_ = $self->{'socket'}->accept() ) {
        #$self->log( 'traceDEV', 'DC::recv', 'accept', $self->{'incomingclass'} );
        $self->log( 'err', 'cant accept, no incomingclass' ), return, unless $self->{'incomingclass'};
        $self->{'clients'}{$_} ||= $self->{'incomingclass'}->new(
          #%$self,                                clear(),
          'socket' => $_, 'LocalPort' => $self->{'myport'}, 'incoming' => 1,
#'want'         => \%{ $self->{'want'} },                'NickList'     => \%{ $self->{'NickList'} },                'IpList'       => \%{ $self->{'IpList'} },                'PortList'     => \%{ $self->{'PortList'} },
#'want'         => $self->{'want'},
#'NickList'     => $self->{'NickList'},
#'IpList'       => $self->{'IpList'},
#'PortList'     => $self->{'PortList'},
          'auto_listen' => 0, 'auto_connect' => 0, 'parent' => $self,
          #'share_tth'      => $self->{'share_tth'},
          'status' => 'connected',
          #$self->incomingopt(),
          %{ $self->{'incomingopt'} || {} },
        );
        $self->{'clients'}{$_}->select_add();
        #$self->log( 'dev', 'child created',            $_,   $self->{'clients'}{$_});
        #++$ret;
      } else {
        $self->log( 'err', "Accepting fail! [$self->{'Proto'}]" );
      }
      #next;
      return;
    }
    $self->log( 'dev', "SOCKERR", $client, $self->{'socket'}, $self->{'select'} ) if $client ne $self->{'socket'};
    $self->{'databuf'} = '';
    if ( !defined( my $r = $client->recv( $self->{'databuf'}, POSIX::BUFSIZ, $self->{'recv_flags'} ) )
      or !length( $self->{'databuf'} ) )
    {
      #TODO not here
      if ( $self->active() and !$self->{'incoming'} and $self->{'reconnect_tries'}++ < $self->{'reconnects'} ) {
        $self->log( 'dcdbg', "recv err, reconnect. d=[$self->{'databuf'}] i=[$self->{'incoming'}]" );
        #$self->log( 'dcdbg',  "recv err, reconnect," );
        $self->reconnect();
      } elsif ( $self->{'status'} ne 'listening' ) {
        $self->log( 'dcdbg', "recv err, destroy," );
        $self->destroy();
      }
    } else {
      #++$readed;
      #++$ret;
      $self->{bytes_recv} += length $self->{'databuf'};
      $self->{activity} = time;
      #$self->log( 'dcdmp', "[$self->{'number'}]", "raw recv ", length( $self->{'databuf'} ), $self->{'databuf'} );
    }
    if ( $self->{'filehandle'} ) { $self->file_write( \$self->{'databuf'} ); }
    else {
      $self->{'recv_buf'} .= $self->{'databuf'};
      local $self->{'cmd_aft'} = "\x0A" if !$self->{'adc'} and $self->{'recv_buf'} =~ /^[BCDEFHITU][A-Z]{,5} /;
#$self->log( 'dcdbg', "[$self->{'number'}]", "raw to parse [$self->{'buf'}] sep[$self->{'cmd_aft'}]" ) unless $self->{'filehandle'};
      while ( $self->{'recv_buf'} =~ s/^(.*?)\Q$self->{'cmd_aft'}//s ) {
        local $_ = $1;
        #$self->log('dcdmp', 'DC::recv', "parse [$_]($self->{'cmd_aft'})");
        last if $self->{'status'} eq 'destroy';
        #$self->log( 'dcdbg',"[$self->{'number'}] dev cycle ",length $_," [$_]", );
        last unless length $_ and length $self->{'cmd_aft'};
        next unless length;
        $self->parser($_);
        last if ( $self->{'filehandle'} );
      }
      $self->file_write( \$self->{'recv_buf'} ), $self->{'recv_buf'} = ''
        if length( $self->{'recv_buf'} )
          and $self->{'filehandle'};
    }
  };
  $self->{'recv_try'} ||= sub {
    my $self = shift;
    #$self->{'recv_runned'}{ $self->{'number'} } = 1;
    my $sleep = shift || $self->{'select_timeout'};
    my $ret = 0;
    #$self->connect_check();
    #$self->log( 'dev', 'cant recv, ret' ),
    #return unless $self->{'socket'} and ( $self->{'status'} eq 'listening' or $self->{'socket'}->connected );
    #$self->{'select'} = IO::Select->new( $self->{'socket'} ) if !$self->{'select'} and $self->{'socket'};
    #my ( $readed, $reads );
    #$self->{'databuf'} = '';
    #$self->log( 'traceD', 'DC::select', 'bef' );
    my ( $recv, $send, $exeption ) = IO::Select->select( $self->{'select'}, $self->{'select_send'}, $self->{'select'}, $sleep );
#$self->log( 'traceD', 'DC::select', 'aft' , Dumper ($recv, $send, $exeption));
#schedule(10, sub {        $self->log( 'dev', 'DC::select', 'aft' , Dumper ($recv, $send, $exeption), 'from', $self->{'select'}->handles() ,    'and ', $self->{'select_send'}->handles());        });
    for (@$exeption) { $self->log( 'err', 'exeption', $_, $self->{sockets}{$_}{number} ); }
    for (@$recv) { $self->{sockets}{$_}->recv($_); }
    for (@$send) {
      #$self->log( 'dev', 'can_send', $_, $self->{sockets}{$_}{number} );
      if ( $self->{sockets}{$_}{'filehandle_send'} ) { $self->{sockets}{$_}->file_send_part(); }
    }

=old
    if (0) {
      do {
        #$self->log( 'trace', 'DC::recv', 'in loop', $reads );
        $readed = 0;
        $ret = '0E0', last unless $self->{'select'} and $self->{'socket'};
        $self->log( 'err', "SOCKET UNEXISTS must delete select" ) unless $self->{'select'}->exists( $self->{'socket'} );
        $self->log( 'err', "SOCKET IS NOT CONNECTED must delete select" )
          if !$self->{'accept'}
            and !$self->{'socket'}->connected()
            and $self->{'Proto'} ne 'udp';
        for my $client ( $self->{'select'}->can_read($sleep) ) { $self->recv( $client, ); }
      } while ( $readed and $reads++ < $self->{'max_reads'} );
      #TODO !!! timed
    }
=cut    

    #if ( $self->{'filehandle_send'} ) { $self->file_send_part(); }
    #$self->{'recv_runned'}{ $self->{'number'} } = undef;
    return $ret;
  };
  $self->{'wait'} ||= sub {
    my $self = shift;
    my ( $waits, $wait_once ) = @_;
    $waits     ||= $self->{'waits'};
    $wait_once ||= $self->{'wait_once'};
    local $_;
    my $ret;
    $ret += $self->recv_try($wait_once) while --$waits > 0 and !$ret;
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
    for ( 0 .. ( $_[0] || $self->{'wait_connect_tries'} ) ) {
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
    #$self->periodic();
    schedule(
      1,
      #our $___work_every ||=
      sub {
        $self->connect_check();
        $_->() for grep { ref $_ eq 'CODE' } values %{ $self->{periodic} || {} };
        #print ("P:$_\n"),
        #$self->{periodic}{$_}->() for grep {ref$self->{periodic}{$_} eq 'CODE'}keys %{$self->{periodic} || {}};
        for ( keys %{ $self->{'clients'} } ) {
          $self->log(
            'dev',
"del client[$self->{'clients'}{$_}{'number'}][$_] socket=[$self->{'clients'}{$_}{'socket'}] status=[$self->{'clients'}{$_}{'status'}] last active=",
            time - $self->{'clients'}{$_}{activity}
            ),
            $self->{'clients'}{$_}->destroy(), delete( $self->{'clients'}{$_} ),
            $self->log( 'dev', "now clients",
            map { "[$self->{'clients'}{$_}{'number'}]$_" } sort keys %{ $self->{'clients'} } ), next
            if !$self->{'clients'}{$_}{'socket'}
              or !length $self->{'clients'}{$_}{'status'}
              or $self->{'clients'}{$_}{'status'} eq 'destroy'
              or (  $self->{'clients'}{$_}{'status'} ne 'listening'
                and $self->{'clients'}{$_}{inactive_timeout}
                and time - $self->{'clients'}{$_}{activity} > $self->{'clients'}{$_}{inactive_timeout} );
          #$ret += $self->{'clients'}{$_}->recv();
        }
        $self->{'auto_work'}->($self) if ref $self->{'auto_work'} eq 'CODE';
      }
    );
    return $self->wait_sleep(@params) if @params;
    return $self->recv_try( $self->{'work_sleep'} );
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
        if $self->{'nmdc'} and !exists $self->{'parse'}{$cmd};
      my ( @ret, $ret );
      #$self->log( 'dcinf', "parsing", $cmd, @_ ,'with',$self->{'parse'}{$cmd}, ref $self->{'parse'}{$cmd});
      my @self;
      #@self = $self if $self->{'adc'};
      @self = $self if !$self->{'nmdc'};
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
        ++$self->{count_parse}{$cmd};
      } else {
#$self->log( 'dcinf', "unknown", $cmd, @_ ,'with',$self->{'parse'}{$cmd}, ref $self->{'parse'}{$cmd}, 'run=', @self, 'unknown', $cmd,@param,);
        $self->handler( @self, 'unknown', $cmd, @param, );
      }
      #if ($self->{'parent'}{'hub'}) {           }
      $self->handler( @self, $cmd, @param, $ret );
      $self->handler( @self, $cmd . '_parse_aft_aft', @param, $ret );
    }
  };
  $self->{'send'} ||= sub {
    my $self = shift;
    local $_;    # = join( '', @_ );
    #$self->{bytes_send} += length $_;
    #eval { $_ = $self->{'socket'}->send( join( '', @_ ) ); } if $self->{'socket'};
    eval { $_ = $self->{'socket'}->send(@_); } if $self->{'socket'};
    $self->{bytes_send} += $_;
    $self->log( 'err', 'send error', $@ ) if $@;
    $self->{activity} = time;
    return $_;
  };
  $self->{'sendcmd'} ||= sub {
    my $self = shift;
    return if $self->connect_check();
    #$self->{'log'}->( $self,'sendcmd0', @_);
    local @_ = @_, $_[0] .= splice @_, 1, 1 if $self->{'adc'} and length $_[0] == 1;
    $self->log(  'dcdmp', 'sendcmd1', $self->{number}, @_ );
    push @{ $self->{'send_buffer'} }, $self->{'cmd_bef'} . join( $self->{'cmd_sep'}, @_ ) . $self->{'cmd_aft'} if @_;
    ++$self->{count_sendcmd}{ $_[0] };
    if ( ( $self->{'sendbuf'} and @_ ) or !@{ $self->{'send_buffer'} || [] } ) { }
    else {
      $self->log( 'err', "ERROR! no socket to send" ), return unless $self->{'socket'};
      $self->send( join( '', @{ $self->{'send_buffer'} }, ) );
      #local $_;
      #eval { $_ = $self->{'socket'}->send( join( '', @{ $self->{'send_buffer'} }, ) ); };
      #$self->log( 'err', 'send error', $@ ) if $@;
      $self->log( 'dcdmp', "we send [" . join( '', @{ $self->{'send_buffer'} } ) . "]:", $! );
      $self->{'send_buffer'} = [];
      $self->{'sendbuf'}     = 0;
    }
  };
  $self->{'sendcmd_all'} ||= sub {
    my $self = shift;
    #%{ $self->{'peers_sid'} }
    #eval {
    $_->sendcmd(@_)    #, $self->wait_sleep( $self->{'cmd_recurse_sleep'} )
      for grep { $_ } values( %{ $self->{'clients'} } );    #, $self;
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
    my ( $sid, $cid );
    $sid = $nick if $nick =~ /^[A-Z0-9]{4}$/;
    $cid = $nick if $nick =~ /^[A-Z0-9]{39}$/;
    $cid ||= $self->{peers}{$sid}{INF}{ID};
    $sid ||= $self->{peers}{$cid}{SID};
    local $_ = $as || $file;
    $self->log( 'warn', "file [$_] already exists size = ", -s $_ ) if -e $_;
    #todo by nick
    $self->wait_clients();
    $self->{'want'}{ $self->{peers}{$cid}{'INF'}{'ID'} || $nick }{$file} = $as || $file || '';
    $self->log( 'dbg', "getting [$nick] $file as $as" );
    if ( $self->{'adc'} ) {
      #my $token = $self->make_token($nick);
      local @_;
      if ( $self->{'M'} eq 'A' and $self->{'myip'} and !$self->{'passive_get'} ) {
        @_ = ( 'CTM', $sid, $self->{'connect_protocol'}, $self->{'myport'}, $self->make_token($nick) );
      } else {
        @_ = ( 'RCM', $sid, $self->{'connect_protocol'}, $self->make_token($nick) );
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
      #$self->{'file_recv_from'}
      #$self->{'fileas'}
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
    $self->{'file_recv_partial'} =
      $self->{'partial_prefix'} . ( $self->{'fileas'} || $self->{'filename'} ) . $self->{'partial_ext'};
    $self->{'filebytes'} = $self->{'file_recv_from'} = -s $self->{'file_recv_partial'};
    $self->log( 'dcdev', 'file_select3', $self->{'filename'}, $self->{'fileas'}, $self->{'file_recv_partial'},
      'from', $self->{'file_recv_from'} );
  };
  $self->{'file_open'} ||= sub {
    my $self = shift;
    #$self->{'fileas'}=$_[0] if !length $self->{'fileas'} or length $_[0];
    #$self->{'filetotal'} = $_[1]if ! $self->{'filetotal'} or $_[1];
    my $oparam = $self->{'fileas'} eq '-' ? '>-' : '>>' . $self->{'file_recv_partial'};
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
        $self->{'filecurrent'} = '', $self->{'file_recv_partial'} = '', $self->{'file_recv_from'} = undef,
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
      my $dest = ( $self->{'fileas'} || $self->{'filename'} );
      if ( length $self->{'partial_ext'} and $self->{'filebytes'} == $self->{'filetotal'} ) {
        $self->log( 'dcerr', 'cant move finished file' ) if !rename $self->{'file_recv_partial'}, $dest;
      }
      ( $self->{parent} || $self )->handler( 'file_recieved', $dest );
    }
    $self->{'select_send'}->remove( $self->{'socket'} ), close( $self->{'filehandle_send'} ), delete $self->{'filehandle_send'},
      #$self->{'socket'}->flush(),
      if $self->{'filehandle_send'};
    delete $self->{'file_send_left'};
    delete $self->{'file_send_total'};
    $self->{'status'} = 'connected';
  };
  $self->{'file_send_tth'} ||= sub {
    my $self = shift;
    my ( $file, $start, $size, $as ) = @_;
#$self->log( 'dcdev', 'my share', $self->{'share_full'}, scalar keys %{$self->{'share_full'} }, 'p share', $self->{'parent'}{'share_full'}, scalar keys %{$self->{'parent'}{'share_full'} }, );
#$self->{'share_tth'} ||=$self->{'parent'}{'share_tth'};
    if ( $self->{'share_full'}{$file} ) {
      $self->{'share_full'}{$file} =~ tr{\\}{/};
      $self->file_send( $self->{'share_full'}{$file}, $start, $size, $as );
    } else {
      $self->log(
        'dcerr', 'send', 'cant find file',
        $file, $self->{'share_full'}{$file},
        'from', scalar keys %{ $self->{'share_full'} }
      );
    }
  };
  $self->{'file_send'} ||= sub {
    my $self = shift;
    my ( $file, $start, $size, $as ) = @_;
    $start //= 0;
    $size  //= -s $file;
    $self->{'log'}->( 'dcerr', "cant find [$file]" ), $self->disconnect(), return if !-e $file or -d $file;
    $size = -s $file if $size < 0;
    if ( open $self->{'filehandle_send'}, '<', $file ) {
      binmode( $self->{'filehandle_send'} );
      seek( $self->{'filehandle_send'}, $start, SEEK_SET ) if $start;
      my $name = $file;
      $name =~ s{^.*[\\/]}{}g;
      $self->{'file_send_left'}   = $size;
      $self->{'file_send_total'}  = -s $file;
      $self->{'file_send_offset'} = $start || 0;
      $self->log( 'dev', "sendsize=$size from", $start, 'e', -e $file, $file, $self->{'file_send_total'} );
      if ( $self->{'adc'} ) { $self->cmd( 'C', 'SND', 'file', $as || $name, $start, $size ); }
      else                  { $self->cmd( 'ADCSND', 'file', $as || $name, $start, $size ); }
      $self->{'status'} = 'transfer';
      #$self->file_send_part();
      $self->{'select_send'}->add( $self->{'socket'} );
    } else {
      $self->file_close();
    }
  };
  $self->{'file_send_part'} ||= sub {
    #psmisc::printlog 'call', 'file_send_part', @_;
    my $self = shift;
    #my ($file, $start, $size) = @_;
    #return unless $self->{'file_send_left'};
    #my $buf;
    #$self->disconnect(),
    return
      unless ( $self->{'socket'}
      and $self->{'socket'}->connected()
      and $self->{'filehandle_send'}
      and $self->{'file_send_left'} );
    my $read = $self->{'file_send_left'};
    $read = $self->{'file_send_by'} if $self->{'file_send_by'} < $self->{'file_send_left'};
    #my $readed =
    my $sended;
    if ( $INC{'Sys/Sendfile.pm'} ) {    #works
      #Sys::Sendfile::sendfile fileno($self->{'socket'}), fileno($self->{'filehandle_send'}), $read;
      $self->{'file_send_offset'} += $sended =
        Sys::Sendfile::sendfile( $self->{'socket'}, $self->{'filehandle_send'}, $read, $self->{'file_send_offset'} );
 #);
 #$self->log( 'dev', 'ssendfile0', "$read, offset=$self->{'file_send_offset'}, left=$self->{'file_send_left'} sended=$sended" );
 #$self->{'file_send_offset'} += $sended;
    }

=sux	    
    elsif ( $INC{'Sys/Sendfile/FreeBSD.pm'}) {
#use Sys::Sendfile::FreeBSD qw(sendfile);
#use Errno qw(EINTR EIO :POSIX);
    $self->log(      'dev','fsendfile1',  $self->{'file_send_offset'}, $read, 'left', $self->{'file_send_left'}, '=', $sended, 'ff=', fileno($self->{'filehandle_send'}), fileno($self->{'socket'}));
#my $result = sendfile(fileno($self->{'filehandle_send'}), fileno($self->{'socket'}), $self->{'file_send_offset'}, $read, $sended);
my $result = sendfile( fileno($self->{'socket'}), fileno($self->{'filehandle_send'}),$self->{'file_send_offset'}, $read, $sended);
    $self->log(      'dev','fsendfile1',  $self->{'file_send_offset'}, $read, 'left', $self->{'file_send_left'}, 's=', $sended, 'r=',  $result, $!, 
    #Dumper \%!
#grep {$!{$_}} keys %!
    );

}
=cut

=sux
    elsif ($INC{'IO/AIO.pm'}) {

    $self->log(      'dev','sendfile0',  $self->{'file_send_offset'}, $read, 'left', $self->{'file_send_left'}, '=', $sended);
#use IO::AIO;
#$sended = IO::AIO::sendfile(  fileno($self->{'filehandle_send'}), $self->{'socket'}->fileno(),$self->{'file_send_offset'}, $read );
#$sended = IO::AIO::sendfile(   $self->{'socket'}->fileno(), fileno($self->{'filehandle_send'}),$self->{'file_send_offset'}, $read );
#$sended = IO::AIO::sendfile(   fileno($self->{'socket'}), fileno($self->{'filehandle_send'}),$self->{'file_send_offset'}, $read );
 $sended = IO::AIO::sendfile(   $self->{'socket'}, $self->{'filehandle_send'},$self->{'file_send_offset'}, $read );
 #$self->{'file_send_left'}

    $self->log(      'dev','sendfile1',  $self->{'file_send_offset'}, $read, 'left', $self->{'file_send_left'}, '=', $sended);
$self->{'file_send_offset'} += $sended;
#$self->{'file_send_offset'} += $read, $sended = $read,if $sended == 12;
} 
=cut

    else {
      read( $self->{'filehandle_send'}, $self->{'file_send_buf'}, $read ),
        $self->{'file_send_offset'} = tell $self->{'filehandle_send'},
        unless length $self->{'file_send_buf'};    #$self->{'file_send_by'};
      #send $self->{'socket'},
      #$self->{'socket'}->send( buf, POSIX::BUFSIZ, $self->{'recv_flags'} )
      #my $sended;
      #$self->log(      'snd',      length $self->{'file_send_buf'},
      $sended = $self->send( $self->{'file_send_buf'} );
      #eval {
      #$sended = $self->{'socket'}->send( $self->{'file_send_buf'} );
      #$_;
      #length $buf;
      #$sended;
      #};                                           # if $self->{'socket'};
      #$!    );
      #$self->log( 'err', 'send error', $@ ) if $@;
    }
    schedule 1, our $__stat_ ||= sub {
      our ( $lastmark, $lasttime );
      $self->log(
        'dev',                       "sended bytes",                    #length $self->{'file_send_buf'},
        "sended=[$sended] of buf [", length $self->{'file_send_buf'},
        "] by [$read:$self->{'file_send_by'}] left $self->{'file_send_left'}, now", $self->{'file_send_offset'}, 'of',
        $self->{'file_send_total'}, 's=', ( $self->{'file_send_offset'} - $lastmark ) / ( time - $lasttime or 1 ),
        "status=[$self->{'status'}]",
      );
      $lastmark = $self->{'file_send_offset'};
      $lasttime = time;
    };
    #$self->{activity} = time if $sended;
    #$self->{bytes_send} += $sended;
    $self->{'file_send_left'} -= $sended;
    substr( $self->{'file_send_buf'}, 0, $sended ) = undef;
#if (length $self->{'file_send_buf'}) {         $self->log( 'info', 'sended small', $sended, 'todo', length $self->{'file_send_buf'});    }
#$readed;
    if ( $self->{'file_send_left'} < 0 ) {
      $self->{'log'}->( 'err', "oversend [$self->{'file_send_left'}]" );
      $self->{'file_send_left'} = 0;
    }
    if (
      #$readed < $self->{'file_send_by'} or
      $self->{'file_send_left'} <= 0
      )
    {
      $self->{'log'}->(
        'dev', 'file completed', "r:", length $self->{'file_send_buf'},
        " by:$self->{'file_send_by'} left:$self->{'file_send_left'} total:$self->{'file_send_total'}",
        #caller 2
      );
      $self->file_close();
      #$self->{'status'} = 'connected';
      #?
      #$self->disconnect();
    }
  };
  $self->{'file_send_parse'} =
    #$self->{'ADCSND'} =
    sub {
    my $self = shift if ref $_[0];
    #$self->log(    'cmd_adcSND', Dumper \@_);
    #my ( $dst, $peerid, $toid ) = @{ shift() };
    if ( $_[0] eq 'file' ) {
      my $file = $_[1];
      if ( $file =~ s{^TTH/}{} ) { $self->file_send_tth( $file, $_[2], $_[3], $_[1] ); }
      else {
        #$self->file_send($file, $_[2], $_[3]);
        $self->file_send_tth( $file, $_[2], $_[3], $_[1] );
      }
    } elsif ( $_[0] eq 'list' ) {
      $self->file_send_tth( 'files.xml.bz2', );
    } elsif ( $_[0] eq 'tthl' ) {
      #TODO!! now fake
      ( my $tth = $_[1] ) =~ s{^TTH/}{};
      eval q{
        use MIME::Base32 qw( RFC );
        $tth = MIME::Base32::decode $tth;
      };
      if ( $self->{'adc'} ) { $self->cmd( 'C', 'SND', $_[0], $_[1], $_[2], length $tth ); }
      else                  { $self->cmd( 'ADCSND', $_[0], $_[1], $_[2], length $tth ); }
      $self->send($tth);
    } else {
      $self->log( 'dcerr', 'SND', "unknown type", @_ );
    }
    };
  $self->{'get_peer_addr'} ||= sub {
    my ($self) = @_;
    return unless $self->{'socket'};
    eval { @_ = unpack_sockaddr_in( getpeername( $self->{'socket'} ) || return ) };
    return unless $_[1];
    return unless $_[1] = inet_ntoa( $_[1] );
    $self->{'port'} = $_[0] if $_[0] and !$self->{'incoming'};
    $self->{'hostip'} = $_[1], $self->{'host'} ||= $self->{'hostip'} if $_[1];
    return $self->{'hostip'};
  };
  $self->{'get_my_addr'} ||= sub {
    my ($self) = @_;
    return unless $self->{'socket'};
    eval { @_ = unpack_sockaddr_in( getsockname( $self->{'socket'} ) || return ) };
    return unless $_[1];
    return unless $_[1] = inet_ntoa( $_[1] );
    #$self->{'log'}->('dev', "MYIP($self->{'myip'}) [$self->{'number'}] SOCKNAME $_[0],$_[1];");
    return $self->{'myip'} ||= $_[1];
  };
  #http://www.dcpp.net/wiki/index.php/LockToKey :
  $self->{'lock2key'} ||= sub {
    my $self = shift if ref $_[0];
    my ($lock) = @_;
    #$self->{'log'}->( 'dev', 'making lock from', $lock );
    my @lock = split( //, $lock );
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
      map( { $_ . '(' . scalar( keys %{ $self->{$_} } ) . ')=' . join( ',', sort keys %{ $self->{$_} } ) }
        grep { keys %{ $self->{$_} } } @{ $self->{'informative_hash'} } )
    );
    $self->log(
      'dcdbg',
      "protocol stat",
      Dumper( { map { $_ => $self->{$_} } grep { $self->{$_} } qw(count_sendcmd count_parse) } ),
    );
    ( ref $self->{'clients'}{$_}{info} ? $self->{'clients'}{$_}->info() : () ) for sort keys %{ $self->{'clients'} };
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
  $self->{'adc_make_string'} = sub (@) {
    my $self = shift if ref $_[0];
    join ' ', map {
      ref $_ eq 'ARRAY' ? @$_ : ref $_ eq 'HASH' ? do {
        my $h = $_;
        map { "$_$h->{$_}" } keys %$h;
        }
        : $_
    } @_;
  };
  $self->{'cmd_adc'} ||= sub {
    my ( $self, $dst, $cmd ) = ( shift, shift, shift );
    #$self->sendcmd( $dst, $cmd,map {ref $_ eq 'HASH'}@_);
    #$self->log(    'cmd_adc', Dumper \@_);
    $self->sendcmd(
      $dst, $cmd,
      #map {ref $_ eq 'ARRAY' ? @$_:ref $_ eq 'HASH' ? each : $_)    }@_
      ( $dst eq 'C' || !length $self->{'sid'} ? () : $self->{'sid'} ), $self->adc_make_string(@_)
        #( $dst eq 'D' || !length $self->{'sid'} ? () : $self->{'sid'} ),
    );
  };
  #sub adc_string_decode ($) {
  $self->{'adc_string_decode'} ||= sub ($) {
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
  $self->{'adc_path_encode'} = sub ($) {
    my $self = shift;
    local ($_) = @_;
    s{^(\w:)}{/${1}_}g;
    s{\\}{/}g;
    $self->adc_string_encode($_);
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
    for ( local @_ = @_ ) {
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
  local %_ = (
    'search' => sub {
      my $self = shift if ref $_[0];
      $self->log( 'search', @_ );
      return $self->cmd( 'search_tth', @_ ) if length $_[0] == 39 and $_[0] =~ /^[0-9A-Z]+$/;
      return $self->cmd( 'search_string', @_ ) if length $_[0];
    },
    'search_retry' => sub {
      my $self = shift if ref $_[0];
      unshift( @{ $self->{'search_todo'} }, $self->{'search_last'} ) if ref $self->{'search_last'} eq 'ARRAY';
      $self->{'search_last'} = undef;
    },
    'search_buffer' => sub {
      my $self = shift if ref $_[0];
      push( @{ $self->{'search_todo'} }, [@_] ) if @_;
      return unless @{ $self->{'search_todo'} || return };
#$self->log($self, 'search', Dumper \@_);
#$self->log( 'dcdev', "search too fast [$self->{'search_every'}], len=", scalar @{ $self->{'search_todo'} } )        if @_ and scalar @{ $self->{'search_todo'} } > 1;
      return if time() - $self->{'search_last_time'} < $self->{'search_every'} + 2;
      $self->{'search_last'} = shift( @{ $self->{'search_todo'} } );
      $self->{'search_todo'} = undef unless @{ $self->{'search_todo'} };
      $self->cmd('search_send');
#if ( $self->{'adc'} ) {
#}      else {
#$self->sendcmd( 'Search', $self->{'M'} eq 'P' ? 'Hub:' . $self->{'Nick'} : "$self->{'myip'}:$self->{'myport_udp'}", join '?', @{ $self->{'search_last'} } );
#}
      $self->{'search_last_time'} = time();
    },
    'nick_generate' => sub {
      my $self = shift if ref $_[0];
      $self->{'nick_base'} ||= $self->{'Nick'};
      $self->{'Nick'} = $self->{'nick_base'} . int( rand( $self->{'nick_random'} || 100 ) );
    },
  );
  $self->{$_} = $_{$_} for keys %_;
}
#print "N:DC:CALLER=", caller, "\n";
do {
  use lib '../';
  __PACKAGE__->new( auto_work => 1, @ARGV ),;
} unless caller;
1;
__END__

=head1 NAME

Net::DirectConnect - Perl Direct Connect protocol implementation

=head1 SYNOPSIS

  use Net::DirectConnect;
  my $dc = Net::DirectConnect->new(
    'host' => 'dc.mynet.com:4111', #if not 411
    'Nick' => 'Bender', 
    'description' => 'kill all humans',
     #'M'           => 'P', #passive mode, autodetect by default
     #'local_mask'       => [qw(80.240)], #mode=active if hub in this nets and your ip in gray
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
 self filelist making 
 segmented, multisource download;
 async connect;


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
