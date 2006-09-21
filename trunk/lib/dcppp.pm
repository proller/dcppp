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
#  use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
  use IO::Socket;
  use IO::Select;
  use POSIX;

  eval { use Time::HiRes qw(time); };

  use strict;
  no warnings qw(uninitialized);
  our $VERSION = (split(' ', '$Revision$'))[1];


#dbg
#use Time::HiRes qw(time);

#  my %want;
  our %global;

#  my %clear = ('clients' => {},'socket' => '', 'select' => '','accept' => 0, 'filehandle'=>'');
#  our %clear = ('clients' => {}, 'socket' => undef, 'select' => undef, 
#                'accept' => 0, 'filehandle' => undef, 'parse' => {},  'cmd' => {}, );
#from lib/misc
  sub float { #v1
    my $self = shift;
    return ($_[0] < 8 and $_[0] - int($_[0])) ? sprintf('%.'.($_[0] < 1 ? 3 : ($_[0] < 3 ? 2 : 1)).'f', $_[0]) : int($_[0]);
  };


  sub clear {
    return ('clients' => {}, 'socket' => undef, 'select' => undef, 
                'accept' => 0, 'filehandle' => undef, 'parse' => {},  'cmd' => {}, );
  }
  
  sub new {
    my $class = shift;
    my $self = { 
	'Listen' => 10,
	'myport_base' => 40000,
	'myport_random' => 1000,
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
	'V'	=> $VERSION,	#V: tells you the version number 
	'M'	=> 'A',		#M: tells if the user is in active (A), passive (P), or SOCKS5 (5) mode 
	'H'	=> '0/1/0',	#H: tells how many hubs the user is on and what is his status on the hubs. The first number means a normal user, second means VIP/registered hubs and the last one operator hubs (separated by the forward slash ['/']). 
	'S'	=> '2',		#S: tells the number of slots user has opened 
	'O'	=> undef,	#O: shows the value of the "Automatically open slot if speed is below xx KiB/s" setting, if non-zero 
	'log'   => sub { print(join(' ', @_), "\n")},
    };
#print "self creat: [$self->{'number'}]\n";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n\n";
    bless($self, $class);
#print "self: $self \n";

#print "dcppp0[$self->{'socket'}]{",@_,"}\n";
    $self->init(@_);
#print "self init: [$self->{'number'}]\n";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n\n";
#print "dcppp1[$self->{'socket'}]\n";
#print "3: $self->{'Nick'}\n";

#print "[$self->{'number'}] myport pre: $self->{'myport'}\n";
#print "[$self->{'number'}] myport aft: $self->{'myport'}\n";


#print "new obj: [$self->{'number'}]\n";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";

#print "[$self->{'number'}]clr";print "[$_ = $clear{$_}]"for sort keys %clear;print "\n";
#print "[$self->{'number'}] dcppp new clients:{", keys %{$self->{'clients'}}, "}\n";

#print "created [$self->{'number'}] now=$global{'count'} ($self)\n" if $self->{'debug'};
#print "dcppp2[$self->{'socket'}]\n";
    return $self;
  }

  sub log {
    my $self = shift;
    $self->{'log'}->(@_) if $self->{'log'};
  }

  sub baseinit {
    my $self = shift;
    $self->{'number'} = ++$global{'total'};
    $self->{'myport'} ||= $self->{'myport_base'} + int(rand($self->{'myport_random'})) if $self->{'myport_random'} and $self->{'myport_base'};
    $self->{'port'} = $1 if $self->{'host'} =~ s/:(\d+)//;

    $self->{'want'} ||= {};
    $self->{'NickList'} ||= {};
    $self->{'IpList'} ||= {};
    $self->{'PortList'} ||= {};

    ++$global{'count'};
    $self->{'status'} = 'disconnected';

  }
 
  sub connect {
    my $self = shift;
    $self->log('dcdbg', "[$self->{'number'}] connecting to $self->{'host'}, $self->{'port'}");
#    print "[$self->{'number'}] connecting to $self->{'host'}, $self->{'port'}\n"  if $self->{'debug'};
    $self->{'socket'} = new IO::Socket::INET('PeerAddr'=>$self->{'host'}, 'PeerPort' => $self->{'port'}, 'Proto' => 'tcp', 'Type' => SOCK_STREAM, )
	 or $self->log('err',"connect socket  error: $@"), return;
    $self->nonblock();
    setsockopt ($self->{'socket'},  &Socket::IPPROTO_TCP,  &Socket::TCP_NODELAY, 1);
#    $self->{'select'} = IO::Select->new($self->{'socket'});

#print "connect to $self->{'host'} ok\n"  if $self->{'debug'};
    $self->log('dcdbg', "connect to $self->{'host'} ok"); #  if $self->{'debug'};
#exit;

    $self->{'status'} = 'connecting';
    $self->{'outgoing'} = 1;
    $self->recv();
#print "rec fr $self->{'host'} ok"  if $self->{'debug'};
  }

  sub listen {
    my $self = shift;

$self->log('dcdbg', "listening $self->{'myport'}"); #  if $self->{'debug'};
    $self->{'socket'} = new IO::Socket::INET('LocalPort'=> $self->{'myport'}, 'Proto' => 'tcp', 'Type' => SOCK_STREAM, 'Listen' => $self->{'Listen'})
	 or $self->log('err',"listen $self->{'myport'} socket error: $@"), return;
#    $self->{'select'} = IO::Select->new($self->{'socket'});
    setsockopt ($self->{'socket'},  &Socket::IPPROTO_TCP,  &Socket::TCP_NODELAY, 1);
    $self->nonblock();
    $self->log('dcdbg', "listening $self->{'myport'} ok");
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
      close($self->{'socket'}) or $self->log('err',"Error closing socket: $!");
      $self->{'socket'} = undef;
      --$global{'count'};
#    } else {
#      print "already ";
    }

#print " clidel {", keys %{$self->{'clients'}}, "}\n";

#print("delclient($self->{'clients'}{$_}->{'number'})[$_][$self->{'clients'}{$_}]\n"),
    $self->{'clients'}{$_}->disconnect(), 
     $self->{'clients'}{$_} = undef,
     delete($self->{'clients'}{$_}) for grep $_, keys %{$self->{'clients'}};
#grep $self->{'number'} != $self->{'clients'}{$_}->{'number'},
#print "SO1[$self->{'socket'}]";
    close($self->{'filehandle'}),
     $self->{'filehandle'} = undef if $self->{'filehandle'};

#print "deleted [$self->{'number'}] now=$global{'count'}\n";
  }

  sub destroy {
    my $self = shift;
#print "\n[$self->{'number'}]DESTROY MANUAL TRY\n";
#    return;
    $self->disconnect();
    $self->log('dcdbg', "[$self->{'number'}]($self)TOTAL MANUAL DESTROY from ", join(':', caller), " ($self)");
    delete $self->{$_} for keys %$self;
    $self = undef;
  }

  sub DESTROY {
    my $self = shift;
#print "\n[$self->{'number'}]DESTROY AUTO TRY\n";
    $self->log('dcdbg', "[$self->{'number'}]($self)AUTO DESTROY from ", join(':', caller), " ($self)");
#    $self->disconnect();
    $self->destroy();
#print "NOLOG DESTROY[$self->{'number'}]\n";
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
$self->log('dctim', "[$self->{'number'}] readstart");
      for my $client ($self->{'select'}->can_read(1)) {
$self->log('dctim', "[$self->{'number'}] canread");
#print ("can_read per ", (time() - $tim), "\n");

#print "can read : $self->{'number'} [$self->{'select'} : $self->{'socket'}]\n" if $self->{'debug'};
        if ($self->{'accept'} and $client == $self->{'socket'}) {
#print "nconn\n";
          if ($_ = $self->{'socket'}->accept()) {
#MORE INFO HERE
#print "[$self->{'number'}] newinc [$self->{'accept'}]\n";
#print "accpt total bef ", scalar keys %{$self->{'clients'}}  ,"\n";
            $self->{'clients'}{$_} = $self->{'incomingclass'}->new( %$self, clear(), 'socket' => $_, 'LocalPort'=>$self->{'myport'}, 'incoming'=>1, 'want' => \%{$self->{'want'}},  'NickList' => \%{$self->{'NickList'}}, 'IpList' => \%{$self->{'IpList'}}, 'PortList' => \%{$self->{'PortList'}}), $self->{'clients'}{$_}->cmd('MyNick') unless $self->{'clients'}{$_}; #'debug'=>1,
#print "accpt total aft ", scalar keys %{$self->{'clients'}}  ,"\n";
#print "ok\n";
          } else {
             $self->log('err', "($self->{'number'}) Accepting fail!");
          }
#print "next\n";
          next;
        }

        $databuf = '';
#        my $rv = ;
#$self->log('dctim', "[$self->{'number'}] prerecv");
        if (!defined($client->recv($databuf, POSIX::BUFSIZ, 0)) or !length($databuf)) {
#$self->log('dctim', "[$self->{'number'}] pstrecv");
#        if (!defined($client->recv($databuf, POSIX::BUFSIZ, 0)) ) {
          $self->log('dcdbg', "($self->{'number'}) CLOSEME [$!][$@]");
          $self->{'select'}->remove($client);
          $self->disconnect();
          $self->{'status'} = 'todestroy';
#          $self->destroy();
#          return;
        } else {
          ++$readed;
        }
        if ($self->{'filehandle'}) {
          $self->writefile(\$databuf);
        } else {
#print "($self->{'number'}) ",length($databuf), ' of ', POSIX::BUFSIZ, " {$databuf}\n" if $self->{'debug'};
#$self->log('dcdmp',  "($self->{'number'}) ",length($databuf), ' of ', POSIX::BUFSIZ, " {$databuf}");
          $buf .= $databuf;
#print("PBUF:[$buf]\n");
          $buf =~ s/(.*\|)//s;
#          my $forparse = $1;
#          $buf =~ /^(.*)$/;
#          if (length $1) {
#print("PP[$1]\n");
#my $tim = time();
#!! while here..

#            $self->parse(/^\$/ ? $_ : ($_ = '$'.($self->{'status'} eq 'connected' ? 'chatline' : 'welcome').' ' . $_)) for grep /\w/, split /\|+/, $1;
#          my $numbuf;
          for (split /\|/, $1) {
          $self->log('dcdev', "($self->{'number'}) preparse writefile [$_]"),
#            ($numbuf++ ? $_ .= '|' : 0), $self->writefile(\$_), next if ($self->{'filehandle'});
            last if $self->{'status'} eq 'todestroy';
            $_ .= '|', $self->writefile(\$_), next if ($self->{'filehandle'});
            next unless /\w/;
            $self->parse(/^\$/ ? $_ : ($_ = '$'.($self->{'status'} eq 'connected' ? 'chatline' : 'welcome').' ' . $_));
          }
          $self->log('dcdev', "($self->{'number'}) preparse writefile postbuf  [$buf]"),
          $self->writefile(\$buf), $buf = '' if length($buf) and $self->{'filehandle'};
#print ("parse ", (time() - $tim), "\n");
#          }
        }
      }
#      }
#print ("recv per ", (time() - $tim), "\n");
   $self->log('dctim', "[$self->{'number'}] readend");

#  $self->destroy() , return if $self->{'status'} eq 'todestroy';

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

  $self->destroy() if $self->{'status'} eq 'todestroy';
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
        if ($cmd ne 'Search') {
          $self->log('dcdmp', "($self->{'number'}) rcv: $cmd $_", ($self->{'skip_print_search'} ? ", skipped searches: $self->{'skip_print_search'}" : ()));
          $self->{'skip_print_search'} = 0;
        } else {
          ++$self->{'skip_print_search'};
        }
#print "($self->{'number'}) rcv: $cmd $_\n" if $cmd ne 'Search' and $self->{'debug'};
        $self->{'parse'}{$cmd}->($_);
      } else {
        $self->log('info',  "($self->{'number'}) UNKNOWN PEERCMD:[$cmd]{$_} : please add \$dc->{'parse'}{'$cmd'} = sub { ... };");
#        print "($self->{'number'}) UNKNOWN PEERCMD:[$cmd]{$_} : please add \$dc->{'parse'}{'$cmd'} = sub { ... };\n";
        $self->{'parse'}{$cmd} = sub { };
      }                                                 
      $self->{'handler'}{$cmd}->($_) if $self->{'handler'}{$cmd};
    }
  }

{ my @sendbuf;
  sub sendcmd {
    my $self = shift;
#print caller, "snd [@_] to [$self->{'number'}]\n" if $self->{'debug'};
    $self->log('err',"ERROR! no socket to send"),
      return unless $self->{'socket'};
    if ($self->{'sendbuf'})  {
      push @sendbuf , '$' . join(' ', @_) . '|';
    } else {
#print "snd to [$self->{'socket'}] \n";
#eval {
#$self->{'socket'}->send('$|');
#      print"sending [$_] to [$self->{'number'}]\n" ;
      $self->log('dcdmp', "($self->{'number'}) we send [",join('', @sendbuf, '$' . join(' ', @_) . '|'),"]");
#print"we send [",join('', @sendbuf, '$' . join(' ', @_) . '|'),"] to [$self->{'number'}]\n" if $self->{'debug'};
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

#print "[$self->{'number'}] CMD:$cmd param[",@_,"]\n" if $self->{'debug'};
      $self->{'cmd'}{$cmd}->(@_);
    } else {
      $self->log('info', "UNKNOWN CMD:[$cmd]{@_} : please add \$dc->{'cmd'}{'$cmd'} = sub { ... };");
      $self->{'cmd'}{$cmd} = sub { };
    }
    $self->recv() if $self->{'autorecv'};
#print "[$self->{'number'}] dcppp cmdaft clients:{", keys %{$self->{'clients'}}, "}\n";
  }

  sub get {
    my ($self, $nick, $file, $as) = @_;
#print "get from [$nick] [$file] as [$as]\n";
    $self->{'want'}->{$nick}{$file} = ($as or $file);
#print "[nick:$_]" for keys %{$self->{'want'}};
#print "go conn [$nick] \n";
    $self->cmd((($self->{'M'} eq 'A' and $self->{'myip'} ) ? '' : 'Rev') . 'ConnectToMe', $nick);
  }

  sub openfile {
    my $self = shift;
    open($self->{'filehandle'}, '>', ($self->{'fileas'} or $self->{'filename'})) or return 1;
    binmode($self->{'filehandle'});
    return 0;
  }

  sub writefile {
    my $self = shift;
    $self->{'file_start_time'} ||= time;
    for my $databuf ( @_) {
#print("self:$self;\n");
          $self->{'filebytes'} += length $$databuf;
$self->log('dcdbg', "($self->{'number'}) recv $self->{'filebytes'} of $self->{'filetotal'} file $self->{'filename'}");
#print "recv $self->{'filebytes'} of $self->{'filetotal'} file $self->{'filename'}\n" if $self->{'debug'};
          my $fh = $self->{'filehandle'};
          print $fh $$databuf if $fh;
          $self->log('info',"($self->{'number'}) file complete ($self->{'filebytes'}) per", $self->float(time - $self->{'file_start_time'}), 's at', $self->float($self->{'filebytes'} / ((time - $self->{'file_start_time'}) or 1)), 'b/s'),
#          close($self->{'filehandle'}), $self->{'filehandle'} = undef,
            $self->disconnect(),
#            $self->destroy(),
            $self->{'status'} = 'todestroy',
            $self->{'file_start_time'} = 0
            if $self->{'filebytes'} == $self->{'filetotal'};

#print("aft fc\n");
    }
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
    return $self->{'Nick'} . ' ' . $self->{'description'} . '<' . $self->tag() . '>' . '$' . ($self->{'M'} or ' ') .'$' . $self->{'connection'} . (length($self->{'flag'}) ? chr($self->{'flag'}) : '') . '$' . $self->{'email'} . '$' . $self->{'sharesize'} . '$';
  }

  sub supports { 
    my $self = shift;
    return join ' ', grep $self->{$_}, @{$self->{'supports_avail'}};
  }

  sub supports_parse { 
    my $self = shift;
    my ($str, $save) = @_;
    $save->{$_} = 1 for split /\s+/, $str;
    delete $save->{$_} for grep ! length $save->{$_}, keys %$save;
#print " $_ = $save->{$_}; " for keys %$save; print "\n";
    return wantarray ? %$save : $save;
  }

#=c
sub nonblock {
    return;
    my $self = shift;
    my $flags = fcntl($self->{'socket'}, F_GETFL, 0)
            or $self->log('err', "Can't get flags for socket: $!"), return;
    fcntl($self->{'socket'}, F_SETFL, $flags | O_NONBLOCK)
            or $self->log('err', "Can't make socket nonblocking: $!"), return;
}
#=cut

 
#[Hub security$ $$$0$]
  sub info_parse {
    my $self = shift;
    my ($info, $save) = @_;
#print "parsing info [$info] to $save :";
    $save->{'info'} = $info;
#    $save->{'infofor'} = $1 if $info =~ s/^\s*(?:MyINFO)?\s*(\$ALL)?\s*// and $1;
#    $save->{'Nick'} = $1 if $info =~ s/^\s*([^\s\$]+)\s*//; 
    $save->{'description'} = $1 if $info =~ s/^([^<\$]+)(<|\$)/$2/; 
    ($save->{'tag'}, $save->{'M'}, $save->{'connection'}, $save->{'email'}, $save->{'sharesize'}) = split /\s*\$\s*/, $info;
    $save->{'flag'} = ord($1) if $save->{'connection'} =~ s/([\x00-\x1F])$//e;
    $self->tag_parse($save->{'tag'}, $save);
#    $save->{'sharesize'} = $1 if $info =~ s/\$(\d+)\$$//;
    delete $save->{$_} for grep ! length $save->{$_}, keys %$save;
#print " $_ = $save->{$_}; " for keys %$save; print "\n";
    return wantarray ? %$save : $save;
  }

#rcv: MyINFO $ALL WolF <++ V:0.668,M:A,H:10/0/0,S:40>$ $LAN(T3)$$15100817262$

  sub tag_parse {
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
