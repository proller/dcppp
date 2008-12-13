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

=todo

better nick-port-ip-lists

=cut

package dcppp;
use Socket;
use IO::Socket;
use IO::Select;
use POSIX;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
eval { use Time::HiRes qw(time); };
our $AUTOLOAD;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
our %global;

sub float {          #v1
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
  my $self = {
    'Listen'        => 10,
    'Timeout'       => 5,
    'myport'   => 4111, #first try
    'myport_base'   => 40000,
    'myport_random' => 1000,
    'myport_tries'  => 5,
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
    'email'  => 'billgates@microsoft.com', 'sharesize' => 10 * 1024 * 1024 * 1024,    #10GB
    'client' => 'dcp++',                                                              #++: indicates the client
    'V'      => $VERSION,                                                             #V: tells you the version number
    'M' => 'A',      #M: tells if the user is in active (A), passive (P), or SOCKS5 (5) mode
    'H' => '0/1/0'
    , #H: tells how many hubs the user is on and what is his status on the hubs. The first number means a normal user, second means VIP/registered hubs and the last one operator hubs (separated by the forward slash ['/']).
    'S' => '3',      #S: tells the number of slots user has opened
    'O' => undef,    #O: shows the value of the "Automatically open slot if speed is below xx KiB/s" setting, if non-zero
    'Lock' => 'EXTENDEDPROTOCOLABCABCABCABCABCABC Pk=DCPLUSPLUS0.668ABCABC',


    'log'               => sub { print( join( ' ', @_ ), "\n" ) },
    'auto_recv'         => 1,
    'wait_once'         => 0.1,
    'waits'             => 100,
    'wait_finish'       => 600,
    'wait_finish_by'    => 1,
    'wait_connect'       => 600,
    'clients_max'       => 50,
    'wait_clients'      => 200,
    'wait_clients_by'   => 0.01,
    'cmd_recurse_sleep' => 1,

    ( $^O eq 'MSWin32' ? () : ( 'nonblocking' => 1 ) ),
    'informative'          => [qw(number peernick status host port filebytes filetotal proxy)],    # sharesize
    'informative_hash'     => [qw(clients)],                                                       #NickList IpList PortList
    'disconnect_recursive' => 1,
    'no_print'             => { map { $_ => 1 } qw(Search Quit MyINFO Hello) },

#todo
'reconnects' => 5,
'reconnect_sleep' => 5,

  };
  #print "init2:", Dumper(\@_);
  eval { $self->{'recv_flags'} = MSG_DONTWAIT; } unless $^O =~ /win/i;
  #print "init3:", Dumper(\@_);
  $self->{'recv_flags'} ||= 0;
  bless( $self, $class );
  #print "init4:", Dumper(\@_);
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

sub log {
  my $self = shift;
  $self->{'log'}->(@_) if $self->{'log'};
}

sub myport_generate {
  my $self = shift;
  #  $self->log( 'dev', $self->{'myport'}, $self->{'myport_base'}, $self->{'myport_random'});
  return $self->{'myport'} unless $self->{'myport_base'} or $self->{'myport_random'};
  $self->{'myport'} = undef if $_[0];
  return $self->{'myport'} ||= $self->{'myport_base'} + int( rand( $self->{'myport_random'} ) );
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
}

sub connect {
  my $self = shift;
#psmisc::caller_trace(10);

if ($_[0]) {
$self->{'host'} = $_[0] ;
$self->{'host'} =~ s{^.*?://}{};
$self->{'host'} =~ s{/.*}{}g;
$self->{'port'} = $1 if $self->{'host'} =~ s{:(\d+)}{};
}
$self->{'port'} = $_[1] if $_[1];
  return 0 if ($self->{'socket'} and $self->{'socket'}->connected()) or grep { $self->{'status'} eq $_ } qw(destroy); #connected
  $self->log( 'dcdbg', "[$self->{'number'}] connecting to $self->{'host'}, $self->{'port'}", %{ $self->{'sockopts'} || {} } );
  $self->{'status'}   = 'connecting';
  $self->{'outgoing'} = 1;
$self->{'port'} = $1 if $self->{'host'} =~ s/:(\d+)//;
  $self->{'socket'} ||= new IO::Socket::INET(
    'PeerAddr' => $self->{'host'},
    'PeerPort' => $self->{'port'},
    'Proto'    => $self->{'Proto'} || 'tcp',
    #    'Type'     => SOCK_STREAM,
    'Timeout' => $self->{'Timeout'},
    ( $self->{'nonblocking'} ? ( 'Blocking' => 0 ) : () ),
    #    'Blocking' => 0,
    %{ $self->{'sockopts'} || {} },
  );
  $self->log( 'err', "[$self->{'number'}]", "connect socket  error: $@, $! [$self->{'socket'}]" ), return 1
    if !$self->{'socket'};
  $self->get_my_addr();
  $self->log( 'dcdbg', "[$self->{'number'}]", "connect to $self->{'host'} [me=$self->{'myip'}] ok ", #socket=[$self->{'socket'}]
  );    # Dumper($self->{'sockopts'})
  $self->recv();
  return 0;
}

sub connect_check {
  my $self = shift;

return 0 if $self->{'Proto'} eq 'udp' or $self->{'status'} eq 'listening' or ($self->{'socket'} and $self->{'socket'}->connected());
  $self->{'status'} = 'reconnecting';

#$self->{'reconnects'}
#$self->{'reconnect_sleep'},
$self->every($self->{'reconnect_sleep'}, $self->{'reconnect_func'} ||= sub {
if ($self->{'reconnect_tries'}++ <  $self->{'reconnects'}) {
  $self->log( 'warn', "[$self->{'number'}]", "reconnecting [$self->{'reconnect_tries'}/$self->{'reconnects'}] every", $self->{'reconnect_sleep'});

$self->connect();
#return if $self->{'socket'};


#sleep $self->{'reconnect_sleep'};
}
});

}


sub listen {
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
    $self->log( 'err', "[$self->{'number'}]", "listen $self->{'myport'} socket error: $@" ), $self->myport_generate(1),
      unless $self->{'socket'};
  }
  return unless $self->{'socket'};
  $self->log( 'dcdbg', "[$self->{'number'}]", "listening $self->{'myport'} $self->{'Proto'}" ); # , Dumper($self->{'sockopts'}));
  #    $self->log( 'dcdbg', "[$self->{'number'}] listening $self->{'myport'} ok" );
  $self->{'accept'} = 1 if $self->{'Proto'} ne 'udp';
  $self->{'status'} = 'listening';
  $self->recv();
  #    $self->log( 'dcdbg', "[$self->{'number'}] listen exit" );
}

sub disconnect {
  my $self = shift;
  $self->{'status'} = 'disconnected';
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
    $self->{'clients'}{$_}->destroy(), delete( $self->{'clients'}{$_} ) for grep {    #$_ and
      $self->{'clients'}{$_}
    } keys %{ $self->{'clients'} };
  }
  close( $self->{'filehandle'} ), delete $self->{'filehandle'} if $self->{'filehandle'};

 delete          $self->{$_} for qw(NickList IpList PortList);


  #        $self->log( 'dev', "[$self->{'number'}] disconnected sock=", $self->{'socket'});
}

sub destroy {
  my $self = shift;
  $self->disconnect();
  #    $self->log( 'dcdbg', "[$self->{'number'}]($self)TOTAL MANUAL DESTROY from ", join( ':', caller ), " ($self)" );
  #!?  delete $self->{$_} for keys %$self;
  $self = undef;
}
#sub END {
#  my $self = shift;
#print "\ndcppp END\n" ;
#}
sub DESTROY {
  my $self = shift;
  #print "\n[$self->{'number'}]DESTROY AUTO TRY\n";
  #    $self->log( 'dcdbg', "[$self->{'number'}]($self)AUTO DESTROY from ", join( ':', caller ), " ($self)" );
  #    $self->disconnect();
  $self->destroy();
  #print "NOLOG DESTROY[$self->{'number'}]\n";
  --$global{'count'};
}

sub recv {
  my $self = shift;
  return '0E0' if $self->{'recv_runned'}{$self->{'number'}};
  $self->{'recv_runned'}{$self->{'number'}} = 1;
  my $sleep = shift || 0;
  my $ret = 0;
   $self->connect_check();
  #  return unless $self->{'socket'};
#                $self->log( 'dcdbg',"[$self->{'number'}] recv $self->{'select'};$self->{'socket'}") if $self->{'number'} > 3;
  $self->{'select'} = IO::Select->new( $self->{'socket'} ) if !$self->{'select'} and $self->{'socket'};
  my ($readed);
  $self->{'databuf'} = '';
  #  my $reads = 5;
  #LOOP:
  {
    do {
      $readed = 0;
$ret = '0E0',
      last unless $self->{'select'} and $self->{'socket'};
      #      $self->info();
#                $self->log( 'dcdbg',"[$self->{'number'}] canread r=$readed w=$sleep $self->{'select'};$self->{'socket'}") if $self->{'number'} > 3;
      $self->log( 'err', "[$self->{'number'}]", "SOCKET UNEXISTS must delete select" )
        unless $self->{'select'}->exists( $self->{'socket'} );
      $self->log( 'err', "[$self->{'number'}]", "SOCKET IS NOT CONNECTED must delete select" )
        if !$self->{'accept'}
          and !$self->{'socket'}->connected()
          and $self->{'Proto'} ne 'udp';
      for my $client ( $self->{'select'}->can_read($sleep) ) {
        if ( $self->{'accept'} and $client == $self->{'socket'} ) {
          if ( $_ = $self->{'socket'}->accept() ) {
            $self->{'clients'}{$_} ||= $self->{'incomingclass'}->new(
              %$self, clear(),
              'socket'      => $_,
              'LocalPort'   => $self->{'myport'},
              'incoming'    => 1,
              'want'        => \%{ $self->{'want'} },
              'NickList'    => \%{ $self->{'NickList'} },
              'IpList'      => \%{ $self->{'IpList'} },
              'PortList'    => \%{ $self->{'PortList'} },
              'auto_listen' => 0,
    'auto_connect'      => 0,
'parent' => $self,

            );    #unless $self->{'clients'}{$_};
            ++$ret;
            #          } elsif ($self->{'Proto'} eq 'udp') {
            #        if ( !defined(
            #$client->recv( $self->{'databuf'}, POSIX::BUFSIZ, $self->{'recv_flags'} );
            #) )
            #$self->log( 'dev', "rcv udp [$self->{'databuf'}]");
          } else {
            $self->log( 'err', "[$self->{'number'}] Accepting fail! [$self->{'Proto'}]" );
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
          $self->{'status'} = 'destroy';
          #}        elsif (!length( $self->{'databuf'} ) ) {
          #    $self->log( 'dcdbg', "[$self->{'number'}]","recv warn, len=", length( $self->{'databuf'} )  );
        } else {
          ++$readed;
          ++$ret;
#                  $self->log( 'dcdbg', "[$self->{'number'}]", "raw recv ", length( $self->{'databuf'} ), $self->{'databuf'} );
        }
        if ( $self->{'filehandle'} ) { $self->writefile( \$self->{'databuf'} ); }
        else {
          $self->{'buf'} .= $self->{'databuf'};
  #                  $self->log( 'dcdbg', "[$self->{'number'}]", "raw to parse [$self->{'buf'}]" ) unless $self->{'filehandle'};
  #        $self->{'buf'} =~ s/(.*\|)//s;
  #        for ( split /\|/, $1 ) {
  #        while ($self->{'buf'} =~ s/^([^|]+)\|//) {
  #TODO HERE !!!
          my $endmsg = '[' . ( $self->{'buf'} =~ /^CSND\s/ ? "\n" : '' ) . '|]';
          while ( $self->{'buf'} =~ s/^(.*?)$endmsg//s ) {
            local $_ = $1;
            last if $self->{'status'} eq 'destroy';
            #     $self->log( 'dcdbg',"[$self->{'number'}] dev cycle ",length $_," [$_]", );
            #     $self->log( 'dcdbg',"[$self->{'number'}] bin write ",length $_," [$_]", ),
            #$_ .= '|',
            #(          $_ ?

=z
$self->writefile( 
          \$_, \'|'
#          \($_. '|')
          #, \$` 
          ) 
          #: ()), 
          ,
          #next 
          last
          if ( $self->{'filehandle'} );
=cut

            next unless /\w/;
            $self->parse( (
                /^\$/ ? '' :    #$_ =
                  '$'
                  . (
                  defined( $self->{'parse'}{ (/^(\S+)/)[0] } )
                  ? ''
                  : ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' ) . ' '
                  )
              )
              . $_
            );
            #          $self->parse( /^\$/ ? $_ : ( #$_ =
            #                    '$' . ( $self->{'status'} eq 'connected' ? 'chatline' : 'welcome' ) . ' ' . $_) );
            #     $self->log( 'dcdbg',"[$self->{'number'}] dev lastexit ",length($self->{'buf'} )," [$self->{'buf'} ]", );
            last if ( $self->{'filehandle'} );
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
    delete( $self->{'clients'}{$_} ), next
      if !$self->{'clients'}{$_}->{'socket'}
        or $self->{'clients'}{$_}->{'status'} eq 'destroy';
    $ret += $self->{'clients'}{$_}->recv();
  }
  #!  ++$ret, $self->destroy() if $self->{'status'} eq 'destroy';
  $self->{'recv_runned'}{$self->{'number'}} = undef;
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
  $self->log(
    'dcdev', "[$self->{'number'}]",
    'not finished file:',
    "$self->{'filebytes'} / $self->{'filetotal'}",
    $self->{'peernick'}
    ),
    return 0
    if ( $self->{'filebytes'} and $self->{'filetotal'} and $self->{'filebytes'} < $self->{'filetotal'} - 1 );
  local @_;
  $self->log( 'dcdev', "[$self->{'number'}]", 'not finished clients:', @_ ), return 0
    if @_ = grep { !$self->{'clients'}{$_}->finished() } keys %{ $self->{'clients'} };
  return 1;
}


sub wait_connect {
  my $self = shift;
  for ( 0 .. ($_[0] || $self->{'wait_connect'}) ) {
    last if $self->{'status'} eq 'connected';
    $self->wait();
  }
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
  $self->wait(@_) while $starttime + $how > time();
}

sub work {
  my $self = shift;
  my @params = @_;
  $self->{'periodic'}->() if ref $self->{'periodic'} eq 'CODE';

  return $self->wait_sleep(@params) if @params;
  return $self->recv();
}

sub parse {
  my $self = shift;
  for ( local @_ = @_ ) {
    s/^\$(\w+)\s*//;
    my $cmd = $1;
    my ( @ret, $ret );
    #print "[$self->{'number'}] CMD:[$cmd]{$_}\n" unless $cmd eq 'Search';
    $self->handler( $cmd . '_parse_bef_bef', $_ );
    if ( $self->{'parse'}{$cmd} ) {
      if (
        !exists $self->{'no_print'}{$cmd}
        #( $self->{'print_search'} or $cmd ne 'Search' ) and ( $self->{'print_myinfo'} or $cmd ne 'MyINFO' )
        )
      {
        local $_ = $_;
local @_ = map { $self->{ 'skip_print_' . $_ } ? $_ = "$_:$self->{'skip_print_'.$_}" : ''; } keys %{ $self->{'no_print'} || {} };
        $self->log(
          'dcdmp',
          "[$self->{'number'}] rcv: $cmd $_",
(@_ ? ('  [',@_,']') : ())
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
      $self->handler( $cmd . '_parse_bef', $_ );
      @ret = $self->{'parse'}{$cmd}->($_);
      $ret = scalar @ret > 1 ? \@ret : $ret[0];
      $self->handler( $cmd . '_parse_aft', $_, $ret );
    } else {
      $self->log( 'dcinf',
        "[$self->{'number'}] UNKNOWN PEERCMD:[$cmd]{$_} : please add \$dc->{'parse'}{'$cmd'} = sub { ... };" );
      $self->{'parse'}{$cmd} = sub { };
    }
    $self->handler( $cmd, $_, $ret );
    $self->handler( $cmd . '_parse_aft_aft', $_, $ret );
  }
}

sub handler {
  my ( $self, $cmd ) = ( shift, shift );
  #    $self->log('dev', "handlerdbg [$cmd]", @_, $self->{'handler'}{$cmd});
  $self->{'handler'}{$cmd}->( $self, @_ ) if ref $self->{'handler'}{$cmd} eq 'CODE';
}
{
  my @sendbuf;

  sub sendcmd {
    my $self = shift;
   $self->connect_check();
    $self->log( 'err', "[$self->{'number'}] ERROR! no socket to send" ), return unless $self->{'socket'};
    if ( $self->{'sendbuf'} ) { push @sendbuf, '$' . join( ' ', @_ ) . '|'; }
    else {
      local $_;
#$self->log( "atmark:", $self->{'socket'}->atmark, " timeout=",$self->{'socket'}->timeout,  'conn=',$self->{'socket'}->connected,'so=', $self->{'socket'});
      eval { $_ = $self->{'socket'}->send( join( '', @sendbuf, '$' . join( ' ', @_ ) . '|' ) ); };
      $self->log( 'err', "[$self->{'number'}]", 'send error', $@ ) if $@;
      $self->log( 'dcdmp', "[$self->{'number'}] we send [", join( '', @sendbuf, '$' . join( ' ', @_ ) . '|' ), "]:", $_, $! );
      @sendbuf = ();
    }
  }
}

sub cmd {
  #print "CMD PRE param[",@_,"]\n" ;
  my $self = shift;
  my $cmd  = shift;
  my ( @ret, $ret );
  $self->handler( $cmd . '_cmd_bef_bef', @_ );
  if ( $self->{'min_cmd_delay'} and ( time - $self->{'last_cmd_time'} < $self->{'min_cmd_delay'} ) ) {
    $self->{'log'}->( 'dbg', 'sleepcmd', $self->{'min_cmd_delay'} - time + $self->{'last_cmd_time'} );
    sleep( $self->{'min_cmd_delay'} - time + $self->{'last_cmd_time'} );
  }
  $self->{'last_cmd_time'} = time;
  if ( $self->{'cmd'}{$cmd} ) {
    $self->handler( $cmd . '_cmd_bef', @_ );
    @ret = $self->{'cmd'}{$cmd}->(@_);
    $ret = scalar @ret > 1 ? \@ret : $ret[0];
    $self->handler( $cmd . '_cmd_aft', \@_, $ret );
  } else {
    $self->log( 'info', "[$self->{'number'}]", "UNKNOWN CMD:[$cmd]{@_} : please add \$dc->{'cmd'}{'$cmd'} = sub { ... };" );
    $self->{'cmd'}{$cmd} = sub { };
  }
  if    ( $self->{'auto_wait'} ) { $self->wait(); }
  elsif ( $self->{'auto_recv'} ) { $self->recv(); }
  $self->handler( $cmd . '_cmd_aft_aft', @_, $ret );
}

sub rcmd {
  my $self = shift;
  eval {
    eval { $_->cmd(@_) }, $self->wait_sleep( $self->{'cmd_recurse_sleep'} )
      for grep { $_ } values( %{ $self->{'clients'} } ), $self;
  };
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
  my $oparam = ( ( $self->{'fileas'} eq '-' ) ? '>-' : '>' . ( $self->{'fileas'} || $self->{'filename'} ) );
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
  my $fh = $self->{'filehandle'} || return;
  for my $databuf (@_) {
    $self->{'filebytes'} += length $$databuf;
#       $self->log( 'dcdbg', "($self->{'number'}) recv ".length($$databuf)." [$self->{'filebytes'}] of $self->{'filetotal'} file $self->{'filename'}" );
    $self->log( 'dcdbg', "[$self->{'number'}] recv " . length($$databuf) . " [$$databuf]" ) if length $$databuf < 10;
    print $fh $$databuf;
    $self->log( 'err', "[$self->{'number'}] file download error! extra bytes ($self->{'filebytes'}/$self->{'filetotal'}) " )
      if $self->{'filebytes'} > $self->{'filetotal'};
    #    close($fh),
    $self->log(
      'info',
      "[$self->{'number'}] file complete ($self->{'filebytes'}) per",
      $self->float( time - $self->{'file_start_time'} ),
      's at', $self->float( $self->{'filebytes'} / ( ( time - $self->{'file_start_time'} ) or 1 ) ), 'b/s'
      ),
      $self->disconnect(), $self->{'status'} = 'destroy', $self->{'file_start_time'} = 0
      if $self->{'filebytes'} >= $self->{'filetotal'};
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
  #  $self->{'log'}->('dev', "MYIP($self->{'myip'}) [$self->{'number'}] SOCKNAME $_[0],$_[1];");
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
  return join( '', @key );
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

#sub active {  my $self = shift;  return map { $_->{'number'} } grep { $_->{'socket'} } $self, values %{ $self->{'clients'} };}

sub active {
  my $self = shift;

return 1 if grep {$self->{'status'} eq $_} qw(connecting   connected   reconnecting);
return 0;

}

#sub status {


#now states:
#connecting   connected   reconnecting disconnected destroy 
#need checks:
#           \ connected?/ 
#\------------active?----------------/




#}

#my %every;

sub every {
  my ( $self, $sec, $func ) = ( shift, shift, shift );
  #printlog('dev','every', $sec, $every{$func}, time, $func ),
  $func->(@_), $self->{'every'}{$func} = time if $self->{'every'}{$func} + $sec < time and ref $func eq 'CODE';
}



sub AUTOLOAD {
  my $self = shift      || return;
  my $type = ref($self) || return;
  my $name = $AUTOLOAD;
  $name =~ s/.*://;
  #print "CMD[", Dumper ($self), " : $type];\n";
  return $self->cmd( $name, @_ );
}
1;
