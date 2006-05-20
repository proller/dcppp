#!/usr/bin/perl 	
my $Id = '$Id$';
=copyright
dcpp for perl 
Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proller AT mail DOT ru icq#89088275

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
#  use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
  use IO::Socket;
  use IO::Select;
  use POSIX;
  use strict;

#dbg
#use Time::HiRes qw(time);

#  my %want;
  our %global;

#  my %clear = ('clients' => {},'socket' => '', 'select' => '','accept' => 0, 'filehandle'=>'');
#  our %clear = ('clients' => {}, 'socket' => undef, 'select' => undef, 
#                'accept' => 0, 'filehandle' => undef, 'parse' => {},  'cmd' => {}, );
  sub clear {
    return ('clients' => {}, 'socket' => undef, 'select' => undef, 
                'accept' => 0, 'filehandle' => undef, 'parse' => {},  'cmd' => {}, );
  }
  
  sub new {
    my $class = shift;
    my $self = { 
	'Listen' => 10,
	# http://www.dcpp.net/wiki/index.php/%24MyINFO
	'description' => 'just dcppp bot',
	'connection' => 'LAN(T3)',
	#NMDC1: 28.8Kbps, 33.6Kbps, 56Kbps, Satellite, ISDN, DSL, Cable, LAN(T1), LAN(T3) 
	#NMDC2: Modem, DSL, Cable, Satellite, LAN(T1), LAN(T3) 
	'flag' => '1', # User status as ascii char (byte) 
	# 1 normal 
	# 2, 3 away 
	# 4, 5 server               The server icon is used when the client has 
	# 6, 7 server away          uptime > 2 hours, > 2 GB shared, upload > 200 MB. 
	# 8, 9 fireball             The fireball icon is used when the client 
	# 10, 11 fireball away      has had an upload > 100 kB/s. 
	'email' => 'billgates@microsoft.com',
	'sharesize' => 10 * 1024 * 1024 * 1024, #10GB 
	'client'	=> 'dcp++',	#++: indicates the client 
	'V'	=> (split(' ', '$Revision$'))[1],	#V: tells you the version number 
	'M'	=> 'A',		#M: tells if the user is in active (A), passive (P), or SOCKS5 (5) mode 
	'H'	=> '0/1/0',	#H: tells how many hubs the user is on and what is his status on the hubs. The first number means a normal user, second means VIP/registered hubs and the last one operator hubs (separated by the forward slash ['/']). 
	'S'	=> '2',		#S: tells the number of slots user has opened 
	'O'	=> undef,	#O: shows the value of the "Automatically open slot if speed is below xx KiB/s" setting, if non-zero 
    };
#print "self creat: [$self->{'number'}]\n";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n\n";
    bless($self, $class);
#print "self: $self \n";

#print "dcppp0[$self->{'socket'}]{",@_,"}\n";
    $self->init(@_);
#print "self init: [$self->{'number'}]\n";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n\n";
#print "dcppp1[$self->{'socket'}]\n";
#print "3: $self->{'Nick'}\n";
    $self->{'port'} = $1 if $self->{'host'} =~ s/:(\d+)//;
    $self->{'myport'} = $self->{'myport_base'} + int(rand($self->{'myport_random'})) if $self->{'myport_random'} and $self->{'myport_base'};
    $self->{'want'} = {} unless $self->{'want'};

    $self->{'number'} = ++$global{'total'};
    ++$global{'count'};
    $self->{'status'} = 'disconnected';

#print "new obj: [$self->{'number'}]\n";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";

#print "[$self->{'number'}]clr";print "[$_ = $clear{$_}]"for sort keys %clear;print "\n";
#print "[$self->{'number'}] dcppp new clients:{", keys %{$self->{'clients'}}, "}\n";

#print "created [$self->{'number'}] now=$global{'count'} ($self)\n" if $self->{'debug'};
#print "dcppp2[$self->{'socket'}]\n";
    return $self;
  }
 
  sub connect {
    my $self = shift;
    print "[$self->{'number'}] connecting to $self->{'host'}, $self->{'port'}\n"  if $self->{'debug'};
    $self->{'socket'} = new IO::Socket::INET('PeerAddr'=>$self->{'host'}, 'PeerPort' => $self->{'port'}, 'Proto' => 'tcp', 'Type' => SOCK_STREAM, )
	 or print("socket: $@"), return "socket: $@";
#    nonblock();
    setsockopt ($self->{'socket'},  &Socket::IPPROTO_TCP,  &Socket::TCP_NODELAY, 1);
#    $self->{'select'} = IO::Select->new($self->{'socket'});
print "connect to $self->{'host'} ok\n"  if $self->{'debug'};
    $self->{'status'} = 'connecting';
    $self->{'outgoing'} = 1;
    $self->recv();
#print "rec fr $self->{'host'} ok"  if $self->{'debug'};
  }

  sub listen {
    my $self = shift;
    print "listening $self->{'myport'}\n"  if $self->{'debug'};
    $self->{'socket'} = new IO::Socket::INET('LocalPort'=> $self->{'myport'}, 'Proto' => 'tcp', 'Type' => SOCK_STREAM, 'Listen' => $self->{'Listen'})
	 or print("listen $self->{'myport'} socket error: $@\n"), return ;
#    $self->{'select'} = IO::Select->new($self->{'socket'});
    setsockopt ($self->{'socket'},  &Socket::IPPROTO_TCP,  &Socket::TCP_NODELAY, 1);
#    nonblock();
    print "listening $self->{'myport'} ok\n"  if $self->{'debug'};
    $self->{'accept'} = 1;
    $self->recv();
  }


  sub disconnect {
#print( "disconnect from ", join(':', caller), "\n");
    my $self = shift;
#print "[$self->{'number'}] dcppp disconnect clients:{", keys %{$self->{'clients'}}, "}\n";
#print "disconnect($self->{'number'})\n";
#print "SO00[$self->{'socket'}]";
    $self->{'status'} = 'disconnected';
    if ($self->{'socket'}) {
#print "[$self->{'number'}] Closing socket\n";
      close($self->{'socket'}) or print "Error closing socket: $!\n";
      $self->{'socket'} = undef;
      --$global{'count'};
#    } else {
#      print "already ";
    }

#print " clidel {", keys %{$self->{'clients'}}, "}\n";

print("delclient($self->{'clients'}{$_}->{'number'})[$_][$self->{'clients'}{$_}]\n"),
    $self->{'clients'}{$_}->disconnect(), 
     $self->{'clients'}{$_} = undef,
     delete($self->{'clients'}{$_}) for grep $_, keys %{$self->{'clients'}};
#grep $self->{'number'} != $self->{'clients'}{$_}->{'number'},
#print "SO1[$self->{'socket'}]";
    close($self->{'filehandle'}),
     $self->{'filehandle'} = undef if $self->{'filehandle'};

#print "deleted [$self->{'number'}] now=$global{'count'}\n";
  }

  sub DESTROY {
    my $self = shift;
print( "[$self->{'number'}]($self)DESTROY from ", join(':', caller), " ($self)\n") if $self->{'debug'};
    $self->disconnect();
#print "DESTROY[$self->{'number'}]\n";
  }


{ my $buf;
  sub recv {
    my $self = shift;
#print "[$self->{'number'}] dcppp readstart clients:{", keys %{$self->{'clients'}}, "}\n";
=z
    if ($self->{'selectin'}) {
      for my $client ($self->{'selectin'}->can_read(1)) {
print "Lcanread\n";
#print "2\n";
      }
#print "3\n";
    }
#print "4\n";
=cut

    return unless $self->{'socket'};

    $self->{'select'} = IO::Select->new($self->{'socket'}) unless $self->{'select'};
#print "TRYREAD $self->{'host'} $self->{'number'} [$self->{'select'} : $self->{'socket'}]\n" if $self->{'debug'};
#print "R$self->{'number'} " if $self->{'debug'};
    my ($databuf, $readed);
    do {
      $readed = 0;
#print "R[$self->{'number'}]\n";
#print "[$self->{'number'}] dcppp read clients:{", keys %{$self->{'clients'}}, "} is $self->{'socket'}\n";

#      for my $select (grep $_, $self->{'select'}, $self->{'selectin'} ) {
#my $tim = time();
      for my $client ($self->{'select'}->can_read(1)) {
#print ("can_read per ", (time() - $tim), "\n");

#print "can read : $self->{'number'} [$self->{'select'} : $self->{'socket'}]\n" if $self->{'debug'};
        if ($self->{'accept'} and $client == $self->{'socket'}) {
#print "nconn\n";
          if ($_ = $self->{'socket'}->accept()) {
#MORE INFO HERE
#print "[$self->{'number'}] newinc [$self->{'accept'}]\n";
#print "accpt total bef ", scalar keys %{$self->{'clients'}}  ,"\n";
            $self->{'clients'}{$_} = $self->{'incomingclass'}->new( %$self, clear(), 'socket' => $_, 'LocalPort'=>$self->{'myport'}, 'incoming'=>1, 'want' => \%{$self->{'want'}},  ), $self->{'clients'}{$_}->cmd('MyNick') unless $self->{'clients'}{$_}; #'debug'=>1,
#print "accpt total aft ", scalar keys %{$self->{'clients'}}  ,"\n";
#print "ok\n";
          } else {
             print "Accepting fail!\n";
          }
#print "next\n";
          next;
        }

        $databuf = '';
#        my $rv = ;
        if (!defined($client->recv($databuf, POSIX::BUFSIZ, 0)) or !length($databuf)) {
#        if (!defined($client->recv($databuf, POSIX::BUFSIZ, 0)) ) {
print "CLOSEME $self->{'number'} [$!][$@]\n" if $self->{'debug'};
          $self->{'select'}->remove($client);
          $self->disconnect();
        } else {
          ++$readed;
        }
        if ($self->{'filehandle'}) {
          $self->{'filebytes'} += length $databuf;
#print "recv $self->{'filebytes'} of $self->{'filetotal'} file $self->{'filename'}\n";
          my $fh = $self->{'filehandle'};
          print $fh $databuf;
print("[$self->{'number'}] file complete ($self->{'filebytes'})\n"),
#          close($self->{'filehandle'}), $self->{'filehandle'} = undef,
            $self->disconnect()
            if $self->{'filebytes'} == $self->{'filetotal'};

#print("aft fc\n");

        } else {
#print "($self->{'number'}) ",length($databuf), ' of ', POSIX::BUFSIZ, " {$databuf}\n" if $self->{'debug'};
          $buf .= $databuf;
#print("PBUF:[$buf]\n");
          $buf =~ s/(.*\|)//s;
#          $buf =~ /^(.*)$/;
#          if (length $1) {
#print("PP[$1]\n");
#my $tim = time();
            $self->parse(/^\$/ ? $_ : ($_ = '$'.($self->{'status'} eq 'connected' ? 'chatline' : 'welcome').' ' . $_)) for grep /\w/, split /\|+/, $1;
#print ("parse ", (time() - $tim), "\n");
#          }
        }
      }
#      }
#print ("recv per ", (time() - $tim), "\n");
    } while ($readed);
#print "CLIents[$self->{'number'}:$self->{'clients'}]";

#print "[$self->{'number'}] dcppp readaft clients:{", keys %{$self->{'clients'}}, "}\n";
    for (keys %{$self->{'clients'}}) { #grep $self->{'number'} != $self->{'clients'}{$_}->{'number'}, 
#print("\n!!$self->{'clients'}{$_}->{'number'}!!\n"),
#print("\nDEL!!$self->{'clients'}{$_}->{'number'}!!\n"),

#      print "child($self->{'clients'}{$_}->{'number'}) ";
#    print ("readdel($self->{'clients'}{$_}->{'number'}) \n"),
      $self->{'clients'}{$_} = undef,
      delete($self->{'clients'}{$_}), next if !$self->{'clients'}{$_}->{'socket'};
#or $self->{'clients'}{$_}->{'socket'} eq $self->{'socket'};
#      print "child start recv ";

      $self->{'clients'}{$_}->recv();
    }
#    $self->SUPER::recv();

  }

}
 
  sub parse {
    my $self = shift;
    for(@_) {
#print "[$self->{'number'}] PRECMD:{$_}\n" ;
      s/^\$(\w+)\s*//;
      my $cmd = $1;
#print "[$self->{'number'}] CMD:[$cmd]{$_}\n" unless $cmd eq 'Search';
      if($self->{'parse'}{$cmd}) {
print "($self->{'number'}) rcv: $cmd $_\n" if $cmd ne 'Search' and $self->{'debug'};
        $self->{'parse'}{$cmd}->($_);
      } else {
        print "UNKNOWN PEERCMD:[$cmd]{$_} : please add \$dc->{'parse'}{'$cmd'} = sub { ... };\n";
        $self->{'parse'}{$cmd} = sub { };
      }                                                 
      $self->{'handler'}{$cmd}->($_) if $self->{'handler'}{$cmd};
    }
  }

{ my @sendbuf;
  sub sendcmd {
    my $self = shift;
#print caller, "snd [@_] to [$self->{'number'}]\n" if $self->{'debug'};
    print("ERROR! no socket to send\n"),
     return unless $self->{'socket'};

    if ($self->{'sendbuf'})  {
      push @sendbuf , '$' . join(' ', @_) . '|';
    } else {
#print "snd to [$self->{'socket'}] \n";
#eval {
#$self->{'socket'}->send('$|');
#      print"sending [$_] to [$self->{'number'}]\n" ;
print"we send [",join('', @sendbuf, '$' . join(' ', @_) . '|'),"] to [$self->{'number'}]\n" if $self->{'debug'};
      $self->{'socket'}->send( join('', @sendbuf, '$' . join(' ', @_) . '|') ); 
#      $_ = $self->{'socket'};
#      print $_ join('', @sendbuf, '$' . join(' ', @_) . '|'); 
#}      
      @sendbuf = ();
    }
  }
}

  sub cmd {
#print "CMD PRE param[",@_,"]\n" ;
    my $self = shift;
    my $cmd = shift;
#print "[$self->{'number'}] dcppp cmdbeg ($self->{'autorecv'})clients:{", keys %{$self->{'clients'}}, "}\n" if ;

    if($self->{'cmd'}{$cmd}) {

print "[$self->{'number'}] CMD:$cmd param[",@_,"]\n" ;
      $self->{'cmd'}{$cmd}->(@_);
    } else {
      print "UNKNOWN CMD:[$cmd]{@_} : please add \$dc->{'cmd'}{'$cmd'} = sub { ... };\n";
      $self->{'cmd'}{$cmd} = sub { };
    }
    $self->recv() if $self->{'autorecv'};
#print "[$self->{'number'}] dcppp cmdaft clients:{", keys %{$self->{'clients'}}, "}\n";
  }

  sub get {
    my ($self, $nick, $file, $as, $passive) = @_;
#print "get from [$nick] [$file] as [$as]\n";
    $self->{'want'}->{$nick}{$file} = ($as or $file);
#print "[nick:$_]" for keys %{$self->{'want'}};
#print "go conn [$nick] \n";
    $self->cmd(($self->{'M'} eq 'A' ? '' : 'Rev') . 'ConnectToMe', $nick);
  }


  sub get_peer_addr {
    my ($self) = @_;
#print "SO9[$self->{'socket'}]";
    ($self->{'peerport'}, $self->{'peerip'}) = unpack_sockaddr_in( getpeername( $self->{'socket'} ) ) if $self->{'socket'};
    $self->{'peerip'}  = inet_ntoa($self->{'peerip'}) if $self->{'peerip'};
  }

# http://www.dcpp.net/wiki/index.php/LockToKey :
sub lock2key
{
   my @lock = split( // , shift );
   my $i;
   my @key = ();
   # convert to ordinal
   foreach( @lock ) {
       $_ = ord;
   }
   # calc key[0] with some xor-ing magic
   push( @key , $lock[0] ^ 5 );
   # calc rest of key with some other xor-ing magic
   for( $i = 1 ; $i < @lock ; $i++ ) {
       push( @key , ( $lock[$i] ^ $lock[$i - 1] ) );
   }
   # nibble swapping
   for( $i = 0 ; $i < @key ; $i++ ) {
       $key[$i] = ( (($key[$i] << 4) & 240) | ( ($key[$i] >> 4) & 15 )) & 0xff;
   }
   #temp[0] = (u_int8_t)(temp[0] ^ temp[aLock.length()-1]);
   $key[0] = $key[0] ^ $key[ @key - 1 ];
   # escape some
   foreach( @key ) {
       if ( $_ == 0 || $_ == 5 || $_ == 36 || $_ == 96 || $_ == 124 || $_ == 126 ) {
           $_ = sprintf( '/%%DCN%03i%%/' , $_ );
       } else {
           $_ = chr;
       }
   }
   # done
   return join( "" , @key );
}

  sub tag { 
    my $self = shift;
    $self->{'client'} . ' ' . 
    join(',', map $_ . ':' . $self->{$_}, grep defined($self->{$_}), qw(V M H S O) );
  }

  sub myinfo { 
    my $self = shift;
    return $self->{'Nick'} . ' ' . $self->{'description'} . '<' . $self->tag() . '>' . '$ $' . $self->{'connection'} . (length($self->{'flag'}) ? chr($self->{'flag'}) : '') . '$' . $self->{'email'} . '$' . $self->{'sharesize'} . '$';
  }
=c
sub nonblock {
    my $self = shift;
    my $flags = fcntl($self->{'socket'}, F_GETFL, 0)
            or die "Can't get flags for socket: $!\n";
    fcntl($self->{'socket'}, F_SETFL, $flags | O_NONBLOCK)
            or die "Can't make socket nonblocking: $!\n";
}
=cut

 
  sub parseinfo {
    my $self = shift;
    my ($info, $save) = @_;
#print "parsing info [$info] to $save :";
    $save->{'info'} = $info;
    $save->{'infofor'} = $2 if $info =~ s/^\s*(MyINFO)?\s*(\$ALL)?\s*// and $2;
    $save->{'Nick'} = $1 if $info =~ s/^\s*([^\s\$]+)\s*//; 
    ($save->{'tag'}, $save->{'M'}, $save->{'connection'}, $save->{'email'}, $save->{'sharesize'}) = split /\s*\$\s*/, $info;
    $save->{'flag'} = ord($1) if $save->{'connection'} =~ s/([\x00-\x1F])$//e;
    $self->parsetag($save->{'tag'}, $save);
#    $save->{'sharesize'} = $1 if $info =~ s/\$(\d+)\$$//;
    delete $save->{$_} for grep ! length $save->{$_}, keys %$save;
#print " $_ = $save->{$_}; " for keys %$save; print "\n";
    return wantarray ? %$save : $save;
  }

#rcv: MyINFO $ALL WolF <++ V:0.668,M:A,H:10/0/0,S:40>$ $LAN(T3)$$15100817262$

  sub parsetag {
    my $self = shift;
    my ($tag, $save) = @_;
#print "parsing tag [$tag] to $save\n";
    $save->{'tag'} = $tag;
    $tag =~ s/(^\s*<\s*)|(\s*>\s*$)//g;
    $save->{'client'} = $1 if $tag =~ s/^(\S+)\s*//;
#print "\npars[$tag]\n";
    /(.+):(.+)/, $save->{$1} = $2 for split /,/, $tag;
#print " $_ = $save->{$_}; " for keys %$save;
    return wantarray ? %$save : $save;
  }

1;
