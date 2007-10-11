my $Id = '$Id$';

=copyright
dcpp for perl 
Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proler@gmail.com icq#89088275

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA,
or download it from http://www.gnu.org/licenses/gpl.html
=cut

package dcppp;
use Socket;
use IO::Socket;
use IO::Select;
use POSIX;
eval { use Time::HiRes qw(time); };
our $AUTOLOAD;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
our %global;

sub float {    #v1
  my $self = shift;
  return ( $_[0] < 8 and $_[0] - int( $_[0] ) )
    ? sprintf( '%.' . ( $_[0] < 1 ? 3 : ( $_[0] < 3 ? 2 : 1 ) ) . 'f', $_[0] )
    : int( $_[0] );
}
sub clear {
  return (
    'clients'    => {},
    'socket'     => undef,
    'select'     => undef,
    'accept'     => 0,
    'filehandle' => undef,
    'parse'      => {},
    'cmd'        => {},
  );
}

sub new {
  my $class = shift;
  my $self  = {
    'Listen'        => 10,
    'Timeout'       => 5,
    'myport_base'   => 40000,
    'myport_random' => 1000,
    # http://www.dcpp.net/wiki/index.php/%24MyINFO
    'description' => 'just dcppp bot', 'connection' => 'LAN(T3)',
    #NMDC1: 28.8Kbps, 33.6Kbps, 56Kbps, Satellite, ISDN, DSL, Cable, LAN(T1), LAN(T3)
    #NMDC2: Modem, DSL, Cable, Satellite, LAN(T1), LAN(T3)
    'flag' => '1',    # User status as ascii char (byte)
    # 1 normal
    # 2, 3 away
    # 4, 5 server               The server icon is used when the client has
    # 6, 7 server away          uptime > 2 hours, > 2 GB shared, upload > 200 MB.
    # 8, 9 fireball             The fireball icon is used when the client
    # 10, 11 fireball away      has had an upload > 100 kB/s.
    'email' => 'billgates@microsoft.com', 'sharesize' => 10 * 1024 * 1024 * 1024,    #10GB
    'client' => 'dcp++',     #++: indicates the client
    'V'      => $VERSION,    #V: tells you the version number
    'M'      => 'A',         #M: tells if the user is in active (A), passive (P), or SOCKS5 (5) mode
    'H'      => '0/1/0'
    , #H: tells how many hubs the user is on and what is his status on the hubs. The first number means a normal user, second means VIP/registered hubs and the last one operator hubs (separated by the forward slash ['/']).
    'S' => '3',      #S: tells the number of slots user has opened
    'O' => undef,    #O: shows the value of the "Automatically open slot if speed is below xx KiB/s" setting, if non-zero
    'log'               => sub { print( join( ' ', @_ ), "\n" ) },
    'auto_connect'      => 1,
    'auto_recv'         => 1,
    'wait_once'         => 0.1,
    'waits'             => 100,
    'wait_finish'       => 600,
    'wait_finish_by'    => 1,
    'clients_max'       => 50,
    'wait_clients'      => 200,
    'wait_clients_by'   => 0.01,
    'cmd_recurse_sleep' => 1,
    'auto_GetNickList'  => 1,
    'NoGetINFO'         => 1,
    'NoHello'           => 1,
    'UserIP2'           => 1,
    ( $^O eq 'MSWin32' ? () : ( 'nonblocking' => 1 ) ),
    'Version'              => '1,0091',
    'informative'          => [qw(number peernick status host port filebytes filetotal proxy)],# sharesize
    'informative_hash'     => [qw(clients)],                                             #NickList IpList PortList
    'disconnect_recursive' => 1,
  };
  eval { $self->{'recv_flags'} = MSG_DONTWAIT; } unless $^O =~ /win/i;
  $self->{'recv_flags'} ||= 0;
  bless( $self, $class );
  $self->init(@_);
  $self->connect(), $self->wait() if $self->{'auto_connect'};
  $self->listen(),  $self->wait() if $self->{'auto_listen'};
  return $self;
}

sub log {
  my $self = shift;
  $self->{'log'}->(@_) if $self->{'log'};
}

sub baseinit {
  my $self = shift;
  $self->{'number'} = ++$global{'total'};
  $self->{'myport'} ||= $self->{'myport_base'} + int( rand( $self->{'myport_random'} ) )
    if $self->{'myport_random'} and $self->{'myport_base'};
  $self->{'port'} = $1 if $self->{'host'} =~ s/:(\d+)//;
  $self->{'want'}     ||= {};
  $self->{'NickList'} ||= {};
  $self->{'IpList'}   ||= {};
  $self->{'PortList'} ||= {};
  ++$global{'count'};
  $self->{'status'} = 'disconnected';
}

sub connect {
  my $self = shift;
  return 0 if grep { $self->{'status'} eq $_ } qw(connected todestroy);
  $self->log( 'dcdbg', "[$self->{'number'}] connecting to $self->{'host'}, $self->{'port'}", %{ $self->{'sockopts'} || {} } );
  $self->{'status'}   = 'connecting';
  $self->{'outgoing'} = 1;
  $self->{'socket'} ||= new IO::Socket::INET(
    'PeerAddr' => $self->{'host'},
    'PeerPort' => $self->{'port'},
    'Proto'    => 'tcp',
    'Type'     => SOCK_STREAM,
    'Timeout'  => $self->{'Timeout'},
    ( $self->{'nonblocking'} ? ( 'Blocking' => 0 ) : () ),
    #    'Blocking' => 0,
    %{ $self->{'sockopts'} || {} },
  );
  $self->log( 'err', "[$self->{'number'}]", "connect socket  error: $@, $!" ), return 1 if !$self->{'socket'};
  $self->get_my_addr();
  $self->log( 'dcdbg', "[$self->{'number'}]",
    "connect to $self->{'host'} [me=$self->{'myip'}] ok, socket=[$self->{'socket'}]" );
  $self->recv();
  return 0;
}

sub listen {
  my $self = shift;
  return if !$self->{'Listen'} or ( $self->{'M'} eq 'P' and !$self->{'allow_passive_ConnectToMe'} );
  #  $self->log( 'dcdbg', "[$self->{'number'}]listening $self->{'myport'}" );
  $self->{'socket'} = (
    new IO::Socket::INET(
      'LocalPort' => $self->{'myport'},
      'Proto'     => 'tcp',
      'Type'      => SOCK_STREAM,
      'Listen'    => $self->{'Listen'},
      ( $self->{'nonblocking'} ? ( 'Blocking' => 0 ) : () ),
      #    ($^O eq 'MSWin32' ? () : ('Blocking'  => 0)),
      %{ $self->{'sockopts'} or {} },
      )
      or $self->log( 'err', "[$self->{'number'}]", "listen $self->{'myport'} socket error: $@" ),
    return
  );
  #  $self->log( 'dcdbg', "[$self->{'number'}] listening $self->{'myport'} ok" );
  $self->{'accept'} = 1;
  $self->{'status'} = 'listening';
  $self->recv();
}

sub disconnect {
  my $self = shift;
  $self->{'status'} = 'disconnected';
  if ( $self->{'socket'} ) {
    #    $self->log( 'dev', "[$self->{'number'}] Closing socket",
    $self->{'socket'}->shutdown(2);
    #    );
    delete $self->{'socket'};
    --$global{'count'};
  }
#  $self->log('dev',"delclient($self->{'clients'}{$_}->{'number'})[$_][$self->{'clients'}{$_}]\n") for grep {$_} keys %{ $self->{'clients'} };
  if ( $self->{'disconnect_recursive'} ) {
    $self->{'clients'}{$_}->destroy(), delete( $self->{'clients'}{$_} ) for grep {    #$_ and
      $self->{'clients'}{$_}
    } keys %{ $self->{'clients'} };
  }
  close( $self->{'filehandle'} ), delete $self->{'filehandle'} if $self->{'filehandle'};
}

sub destroy {
  my $self = shift;
  $self->disconnect();
  #  $self->log( 'dcdbg', "[$self->{'number'}]($self)TOTAL MANUAL DESTROY from ", join( ':', caller ), " ($self)" );
  #!?  delete $self->{$_} for keys %$self;
  $self = undef;
}

sub DESTROY {
  my $self = shift;
  #print "\n[$self->{'number'}]DESTROY AUTO TRY\n";
  #  $self->log( 'dcdbg', "[$self->{'number'}]($self)AUTO DESTROY from ", join( ':', caller ), " ($self)" );
  #    $self->disconnect();
  $self->destroy();
  #print "NOLOG DESTROY[$self->{'number'}]\n";
}

sub recv {
  my $self  = shift;
  my $sleep = shift || 0;
  my $ret   = 0;
#  return unless $self->{'socket'};
  $self->{'select'} = IO::Select->new( $self->{'socket'} ) if !$self->{'select'} and $self->{'socket'};
  my ($readed);
  $self->{'databuf'} = '';
  #  my $reads = 5;
  #LOOP:
  {
  do {
    $readed = 0;
    last unless $self->{'select'} and $self->{'socket'};
    #      $self->info();
#          $self->log( 'dcdbg',"[$self->{'number'}] canread r=$readed w=$sleep $self->{'select'};$self->{'socket'}");
    for my $client ( $self->{'select'}->can_read($sleep) ) {
      if ( $self->{'accept'} and $client == $self->{'socket'} ) {
        if ( $_ = $self->{'socket'}->accept() ) {
          $self->{'clients'}{$_} ||= $self->{'incomingclass'}->new(
            %$self, clear(),
            'socket'    => $_,
            'LocalPort' => $self->{'myport'},
            'incoming'  => 1,
            'want'      => \%{ $self->{'want'} },
            'NickList'  => \%{ $self->{'NickList'} },
            'IpList'    => \%{ $self->{'IpList'} },
            'PortList'  => \%{ $self->{'PortList'} },
             'auto_listen' => 0,
 
          ) ; #unless $self->{'clients'}{$_};
          ++$ret;
        } else {
          $self->log( 'err', "[$self->{'number'}] Accepting fail!" );
        }
        next;
      }
      $self->{'databuf'} = '';
      #       local $_;
      if ( !defined( $client->recv( $self->{'databuf'}, POSIX::BUFSIZ, $self->{'recv_flags'} ) )
        or !length( $self->{'databuf'} ) )
      {
#        $self->log( 'dcdbg', "[$self->{'number'}]", "recv err, disconnect," );
        $self->{'select'}->remove($client);
        $self->disconnect();
        $self->{'status'} = 'todestroy';
        #}        elsif (!length( $self->{'databuf'} ) ) {
        #    $self->log( 'dcdbg', "[$self->{'number'}]","recv warn, len=", length( $self->{'databuf'} )  );
      } else {
        ++$readed;
        ++$ret;
      }
      if ( $self->{'filehandle'} ) { $self->writefile( \$self->{'databuf'} ); }
      else {
        $self->{'buf'} .= $self->{'databuf'};
        $self->{'buf'} =~ s/(.*\|)//s;
        for ( split /\|/, $1 ) {
          last if $self->{'status'} eq 'todestroy';
          $_ .= '|', $self->writefile( \$_ ), next if ( $self->{'filehandle'} );
          next unless /\w/;
          $self->parse( /^\$/ ? $_ : ( $_ = '$' . ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' ) . ' ' . $_ ) );
        }
        $self->writefile( \$self->{'buf'} ), $self->{'buf'} = '' if length( $self->{'buf'} ) and $self->{'filehandle'};
      }
    }
    #     $self->log( 'dcdbg',"[$self->{'number'}] canread fin r=$readed");
  } while ($readed);
    }
  for ( keys %{ $self->{'clients'} } ) {
    #    $self->{'clients'}{$_} = undef,
   #     $self->log( 'dev', "del client[$_]", ),
    delete( $self->{'clients'}{$_} ), next if !$self->{'clients'}{$_}->{'socket'} or $self->{'clients'}{$_}->{'status'} eq 'todestroy';
    $ret += $self->{'clients'}{$_}->recv();
  }
  #!  ++$ret, $self->destroy() if $self->{'status'} eq 'todestroy';
  return $ret;
}

sub wait {
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
}

sub finished {
  my $self = shift;
  $self->log( 'dcdev', "[$self->{'number'}]", 'not finished file:', "$self->{'filebytes'} / $self->{'filetotal'}", $self->{'peernick'} ), return 0
    if ( $self->{'filebytes'} and $self->{'filetotal'} and $self->{'filebytes'} < $self->{'filetotal'} - 1 );
  local @_;
  $self->log( 'dcdev', "[$self->{'number'}]", 'not finished clients:', @_ ), return 0
    if @_ = grep { !$self->{'clients'}{$_}->finished() } keys %{ $self->{'clients'} };
  return 1;
}

sub wait_finish {
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
}

sub wait_clients {
  my $self = shift;
  for ( 0 .. $self->{'wait_clients'} ) {
    last if $self->{'clients_max'} > scalar keys %{ $self->{'clients'} };
    $self->info() unless $_;
    $self->log( 'info',
      "wait clients " . scalar( keys %{ $self->{'clients'} } ) . "/$self->{'clients_max'}  $_/$self->{'wait_clients'}" );
    #    $self->log( 'info',      "wait RUN", undef, $self->{'wait_clients_by'} );
    $self->wait( undef, $self->{'wait_clients_by'} );
  }
}

sub wait_sleep {
  my $self      = shift;
  my $how       = shift || 1;
  my $starttime = time();
  $self->wait() while $starttime + $how > time();
}

sub parse {
  my $self = shift;
  for (@_) {
    s/^\$(\w+)\s*//;
    my $cmd = $1;
    #print "[$self->{'number'}] CMD:[$cmd]{$_}\n" unless $cmd eq 'Search';
    if ( $self->{'parse'}{$cmd} ) {
      if ( $cmd ne 'Search' ) {
        $self->log(
          'dcdmp',
          "[$self->{'number'}] rcv: $cmd $_",
          ( $self->{'skip_print_search'} ? ", skipped searches: $self->{'skip_print_search'}" : () )
        );
        $self->{'skip_print_search'} = 0;
      } else {
        ++$self->{'skip_print_search'};
      }
      #print "[$self->{'number'}] rcv: $cmd $_\n" if $cmd ne 'Search' and $self->{'debug'};
      $self->{'parse'}{$cmd}->($_);
    } else {
      $self->log( 'dcinf',
        "[$self->{'number'}] UNKNOWN PEERCMD:[$cmd]{$_} : please add \$dc->{'parse'}{'$cmd'} = sub { ... };" );
      $self->{'parse'}{$cmd} = sub { };
    }
    $self->handler( $cmd, $_ );
  }
}

sub handler {
  my ( $self, $cmd ) = ( shift, shift );
  #  $self->log('dev', "handlerdbg [$cmd]", @_, $self->{'handler'}{$cmd});
  $self->{'handler'}{$cmd}->(@_) if $self->{'handler'}{$cmd};
}
{
  my @sendbuf;

  sub sendcmd {
    my $self = shift;
    $self->log( 'err', "[$self->{'number'}] ERROR! no socket to send" ), return unless $self->{'socket'};
    if ( $self->{'sendbuf'} ) { push @sendbuf, '$' . join( ' ', @_ ) . '|'; }
    else {
      local $_;
      eval { $_ = $self->{'socket'}->send( join( '', @sendbuf, '$' . join( ' ', @_ ) . '|' ) ) };
      $self->log( 'err', "[$self->{'number'}]", 'send error', $@ ) if $@;
      $self->log( 'dcdmp', "[$self->{'number'}] we send [", join( '', @sendbuf, '$' . join( ' ', @_ ) . '|' ), "]:", $_,, $! );
      @sendbuf = ();
    }
  }
}

sub cmd {
  #print "CMD PRE param[",@_,"]\n" ;
  my $self = shift;
  my $cmd  = shift;
  if ( $self->{'min_cmd_delay'} and ( time - $self->{'last_cmd_time'} < $self->{'min_cmd_delay'} ) ) {
    $self->{'log'}->( 'dbg', 'sleepcmd', $self->{'min_cmd_delay'} - time + $self->{'last_cmd_time'} );
    sleep( $self->{'min_cmd_delay'} - time + $self->{'last_cmd_time'} );
  }
  $self->{'last_cmd_time'} = time;
  if ( $self->{'cmd'}{$cmd} ) { $self->{'cmd'}{$cmd}->(@_); }
  else {
    $self->log( 'info', "[$self->{'number'}]", "UNKNOWN CMD:[$cmd]{@_} : please add \$dc->{'cmd'}{'$cmd'} = sub { ... };" );
    $self->{'cmd'}{$cmd} = sub { };
  }
  if    ( $self->{'auto_wait'} ) { $self->wait(); }
  elsif ( $self->{'auto_recv'} ) { $self->recv(); }
}

sub rcmd {
  my $self = shift;
  eval {eval {$_->cmd(@_)}, $self->wait_sleep( $self->{'cmd_recurse_sleep'} ) for grep {$_} values( %{ $self->{'clients'} } ), $self;};
  #  $self->cmd(@_);
}

sub get {
  my ( $self, $nick, $file, $as ) = @_;
  $self->wait_clients();
  $self->{'want'}->{$nick}{$file} = ( $as or $file );
  $self->cmd( ( ( $self->{'M'} eq 'A' and $self->{'myip'} and !$self->{'passive_get'} ) ? '' : 'Rev' ) . 'ConnectToMe', $nick );
}

sub openfile {
  my $self = shift;
  my $oparam = ( ( $self->{'fileas'} eq '-' ) ? '>-' : '>' . ( $self->{'fileas'} or $self->{'filename'} ) );
  $self->handler( 'openfile_before', $oparam );
  $self->log( 'dbg', "[$self->{'number'}] openfile pre", $oparam );
  open( $self->{'filehandle'}, $oparam )
    or $self->log( 'dcerr', "[$self->{'number'}] openfile error", $!, $oparam ),
    $self->handler( 'openfile_error', $!, $oparam ), return 1;
  binmode( $self->{'filehandle'} );
  $self->handler('openfile_after');
  $self->{'status'} = 'transfer';
  return 0;
}

sub writefile {
  my $self = shift;
  $self->{'file_start_time'} ||= time;
  $self->handler('writefile_before');
  for my $databuf (@_) {
    $self->{'filebytes'} += length $$databuf;
   #    $self->log( 'dcdbg', "($self->{'number'}) recv $self->{'filebytes'} of $self->{'filetotal'} file $self->{'filename'}" );
    my $fh = $self->{'filehandle'};
    print $fh $$databuf if $fh;
    $self->log(
      'info',
      "[$self->{'number'}] file complete ($self->{'filebytes'}) per",
      $self->float( time - $self->{'file_start_time'} ),
      's at', $self->float( $self->{'filebytes'} / ( ( time - $self->{'file_start_time'} ) or 1 ) ), 'b/s'
      ),
      $self->disconnect(), $self->{'status'} = 'todestroy', $self->{'file_start_time'} = 0
      if $self->{'filebytes'} == $self->{'filetotal'};
  }
}

sub get_peer_addr {
  my ($self) = @_;
  return unless $self->{'socket'};
  eval { @_ = unpack_sockaddr_in( getpeername( $self->{'socket'} ) ) };
  return unless $_[1];
  return unless $_[1] = inet_ntoa( $_[1] );
  $self->{'port'} = $_[0] if $_[0] and !$self->{'incoming'};
  return $self->{'host'} = $_[1] if $_[1];
}

sub get_my_addr {
  my ($self) = @_;
  return unless $self->{'socket'};
  eval { @_ = unpack_sockaddr_in( getsockname( $self->{'socket'} ) ) };
  return unless $_[1];
  return unless $_[1] = inet_ntoa( $_[1] );
  #$self->{'log'}->('dev', "[$self->{'number'}] SOCKNAME $_[0],$_[1];");
  return $self->{'myip'} ||= $_[1];
}
# http://www.dcpp.net/wiki/index.php/LockToKey :
sub lock2key {
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
  return join( "", @key );
}

sub tag {
  my $self = shift;
  $self->{'client'} . ' ' . join( ',', map $_ . ':' . $self->{$_}, grep defined( $self->{$_} ), qw(V M H S O) );
}

sub myinfo {
  my $self = shift;
  return $self->{'Nick'} . ' '
    . $self->{'description'} . '<'
    . $self->tag() . '>' . '$' . ' ' . '$'
    . $self->{'connection'}
    . ( length( $self->{'flag'} ) ? chr( $self->{'flag'} ) : '' ) . '$'
    . $self->{'email'} . '$'
    . $self->{'sharesize'} . '$';
}

sub supports {
  my $self = shift;
  return join ' ', grep $self->{$_}, @{ $self->{'supports_avail'} };
}

sub supports_parse {
  my $self = shift;
  my ( $str, $save ) = @_;
  $save->{$_} = 1 for split /\s+/, $str;
  delete $save->{$_} for grep !length $save->{$_}, keys %$save;
  return wantarray ? %$save : $save;
}

sub info_parse {
  my $self = shift;
  my ( $info, $save ) = @_;
  $save->{'info'} = $info;
  $save->{'description'} = $1 if $info =~ s/^([^<\$]+)(<|\$)/$2/;
  ( $save->{'tag'}, $save->{'M'}, $save->{'connection'}, $save->{'email'}, $save->{'sharesize'} ) = split /\s*\$\s*/, $info;
  $save->{'flag'} = ord($1) if $save->{'connection'} =~ s/([\x00-\x1F])$//e;
  $self->tag_parse( $save->{'tag'}, $save );
  delete $save->{$_} for grep !length $save->{$_}, keys %$save;
  return wantarray ? %$save : $save;
}

sub tag_parse {
  my $self = shift;
  my ( $tag, $save ) = @_;
  $save->{'tag'} = $tag;
  $tag =~ s/(^\s*<\s*)|(\s*>\s*$)//g;
  $save->{'client'} = $1 if $tag =~ s/^(\S+)\s*//;
  /(.+):(.+)/, $save->{$1} = $2 for split /,/, $tag;
  return wantarray ? %$save : $save;
}

sub info {
  my $self = shift;
  #local @_ = $self->active();
  #  $self->log('info', 'active', @_) if @_;
  $self->log(
    'info',
    map( {"$_=$self->{$_}"} grep { $self->{$_} } @{ $self->{'informative'} } ),
    map(
      { $_ . '(' . scalar( keys %{ $self->{$_} } ) . ')=' . join( ',', keys %{ $self->{$_} } ) } grep { keys %{ $self->{$_} } }
        @{ $self->{'informative_hash'} } )
  );
  $self->{'clients'}{$_}->info() for keys %{ $self->{'clients'} };
}

sub active {
  my $self = shift;
  return map { $_->{'number'} } grep { $_->{'socket'} } $self, values %{ $self->{'clients'} };
}

sub AUTOLOAD {
  my $self = shift;
  my $type = ref($self) or return;
  my $name = $AUTOLOAD;
  $name =~ s/.*://;
  return $self->cmd( $name, @_ );
}
1;
