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


#  my %want;
  my %global;

#  my %clear = ('clients' => {},'socket' => '', 'select' => '','accept' => 0, 'filehandle'=>'');
  my %clear = ('clients' => {},'socket' => '', 'select' => '','accept' => 0, 'filehandle'=>undef, 'parse'=>{},  'cmd'=>{}, );
  
  sub new {
    my $class = shift;
    my $self = { 
      'Listen' => 10,
    };
    bless($self, $class);

    $self->init(@_);
#print "3: $self->{'Nick'}\n";

    $self->{'want'} = {} unless $self->{'want'};

    $self->{'number'} = ++$global{'total'};
    ++$global{'count'};

#print "new obj: [$self->{'number'}]";print "[$_ = $self->{$_}]"for sort keys %$self;print "\n";

#print "[$self->{'number'}]clr";print "[$_ = $clear{$_}]"for sort keys %clear;print "\n";

print "created [$self->{'number'}] now=$global{'count'}\n" if $self->{'debug'};
    return $self;
  }
 
  sub connect {
    my $self = shift;
    print "connecting to $self->{'host'}, $self->{'port'}\n"  if $self->{'debug'};
    $self->{'socket'} = new IO::Socket::INET('PeerAddr'=>$self->{'host'}, 'PeerPort' => $self->{'port'}, 'Proto' => 'tcp', 'Type' => SOCK_STREAM, )
	 or return "socket: $@";
#    nonblock();
    setsockopt ($self->{'socket'},  &Socket::IPPROTO_TCP,  &Socket::TCP_NODELAY, 1);
#    $self->{'select'} = IO::Select->new($self->{'socket'});
print "connect to $self->{'host'} ok"  if $self->{'debug'};
    $self->recv();
#print "rec fr $self->{'host'} ok"  if $self->{'debug'};
  }

  sub listen {
    my $self = shift;
    print "listening $self->{'myport'}\n"  if $self->{'debug'};
    $self->{'socket'} = new IO::Socket::INET('LocalPort'=> $self->{'myport'}, 'Proto' => 'tcp', 'Type' => SOCK_STREAM, 'Listen' => $self->{'Listen'})
	 or return "socket: $@";
#    $self->{'select'} = IO::Select->new($self->{'socket'});
    setsockopt ($self->{'socket'},  &Socket::IPPROTO_TCP,  &Socket::TCP_NODELAY, 1);
#    nonblock();
    print "listening $self->{'myport'} ok\n"  if $self->{'debug'};
    $self->{'accept'} = 1;
    $self->recv();
  }


  sub disconnect {
    my $self = shift;
#print "disconnect($self->{'number'})\n";
    if ($self->{'socket'}) {
      close($self->{'socket'});
      delete $self->{'socket'};
      --$global{'count'};
#    } else {
#      print "already ";
    }

    $self->{'clients'}{$_}->disconnect() for keys %{$self->{'clients'}};

#print "deleted [$self->{'number'}] now=$global{'count'}\n";
  }

  sub DESTROY {
    my $self = shift;
    $self->disconnect();
#print "DESTROY[$self->{'number'}]\n";
  }

{ my $buf;
  sub recv {
    my $self = shift;
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
print "TRYREAD $self->{'host'} $self->{'number'} [$self->{'select'} : $self->{'socket'}]\n" if $self->{'debug'};
    my ($databuf, $readed);
    do {
      $readed = 0;
#print "R[$self->{'number'}]\n";

#      for my $select (grep $_, $self->{'select'}, $self->{'selectin'} ) {
      for my $client ($self->{'select'}->can_read(1)) {
#print "can read : $self->{'number'} [$self->{'select'} : $self->{'socket'}]\n" if $self->{'debug'};
        if ($self->{'accept'} and $client == $self->{'socket'}) {
#print "nconn\n";
          if ($_ = $self->{'socket'}->accept()) {
#MORE INFO HERE
            $self->{'clients'}{$_} = $self->{'incomingclass'}->new( %$self, %clear, 'socket' => $_, 'LocalPort'=>$self->{'myport'}, 'incoming'=>1, 'want' => \%{$self->{'want'}},  ), $self->{'clients'}{$_}->cmd('MyNick') unless $self->{'clients'}{$_}; #'debug'=>1,
#print "ok\n";
          } else {
             print "Accepting fail!\n";
          }
#print "1\n";
          next;
        }

        $databuf = '';
        my $rv = $client->recv($databuf, POSIX::BUFSIZ, 0);
        unless (defined($rv) && length($databuf)) {
#print "CLOSEME $self->{'number'}\n" if $self->{'debug'};
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
print("file complete ($self->{'filebytes'})\n"),
          close($self->{'filehandle'}), undef($self->{'filehandle'}),
            $self->disconnect()
            if $self->{'filebytes'} == $self->{'filetotal'};
        } else {
print "($self->{'number'}) ",length($databuf), ' of ', POSIX::BUFSIZ, " {$databuf}\n" if $self->{'debug'};
          $buf .= $databuf;
          $buf =~ s/(.*\|)//;
#          if (length $1) {
##print("PP[$1]");
            $self->parse(/^\$/ ? $_ : ($_ = '$chatline ' . $_)) for grep /\w/, split /\|+/, $1;
#          }
        }
      }
#      }
    } while ($readed);
#print "CLIents[$self->{'number'}:$self->{'clients'}]";

    for (keys %{$self->{'clients'}}) {
#print("\n!!$self->{'clients'}{$_}->{'number'}!!\n"),
#print("\nDEL!!$self->{'clients'}{$_}->{'number'}!!\n"),
      delete $self->{'clients'}{$_}, next unless $self->{'clients'}{$_}->{'socket'};
      $self->{'clients'}{$_}->recv();
    }
#    $self->SUPER::recv();

  }
}
 
  sub parse {
    my $self = shift;
    for(@_) {
      s/^\$(\w+)\s*//;
      my $cmd = $1;
#print "CMD:[$cmd]{$_}\n" unless $cmd eq 'Search';

      if($self->{'parse'}{$cmd}) {
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
    return unless $self->{'socket'};
    if ($self->{'sendbuf'})  {
      push @sendbuf , '$' . join(' ', @_) . '|';
    } else {
      $self->{'socket'}->send($_ = join('', @sendbuf, '$' . join(' ', @_) . '|')); 
      @sendbuf = ();
      print"we send [$_] to [$self->{'number'}]\n" if $self->{'debug'};
    }
  }
}

  sub cmd {
    my $self = shift;
    my $cmd = shift;
    if($self->{'cmd'}{$cmd}) {
      $self->{'cmd'}{$cmd}->(@_);
    } else {
      print "UNKNOWN CMD:[$cmd]{@_} : please add \$dc->{'cmd'}{'$cmd'} = sub { ... };\n";
      $self->{'cmd'}{$cmd} = sub { };
    }
    $self->recv() if $self->{'autorecv'};
  }

  sub get {
    my ($self, $nick, $file, $as) = @_;
#print "get from $nick $file\n";
    $self->{'want'}->{$nick}{$file} = ($as or $file);
#print "[nick:$_]" for keys %{$self->{'want'}};
    $self->cmd('ConnectToMe',$nick);
  }


  sub get_peer_addr {
    my ($self) = @_;
print "SO[$self->{'socket'}]";
    ($self->{'peerport'}, $self->{'peerip'}) = unpack_sockaddr_in( getpeername( $self->{'socket'} ) ) if $self->{'socket'};
    $self->{'peerip'}  = inet_ntoa($self->{'peerip'}) if $self->{'peerip'};
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
1;
