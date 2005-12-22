#!/usr/bin/perl 	
my $Id = '$Id$';
=copyright
dcpp for perl 
Copyright (C) 2005-2006 !!CONTACTS HERE!!

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
#  use Socket;
#  use Fcntl;
  use IO::Socket;
  use IO::Select;
  use POSIX;
  use strict;


#  my %want;

  sub new {
    my $class = shift;
    my $self = { 
      'Listen' => 10,
    };
    bless($self, $class);
    $self->init(@_);
    $self->{'want'} = {} unless $self->{'want'};
    return $self;
  }
 
  sub connect {
    my $self = shift;
    print "connecting to $self->{'host'}, $self->{'port'}\n"  if $self->{'debug'};
    $self->{'socket'} = new IO::Socket::INET('PeerAddr'=>$self->{'host'}, 'PeerPort' => $self->{'port'}, 'Proto' => 'tcp', 'Type' => SOCK_STREAM, )
	 or return "socket: $@";
#    $self->{'select'} = IO::Select->new($self->{'socket'});
print "connect to $self->{'host'} ok"  if $self->{'debug'};
    $self->recv();
print "rec fr $self->{'host'} ok"  if $self->{'debug'};
  }

  sub listen {
    my $self = shift;
    print "listening $self->{'LocalPort'}\n"  if $self->{'debug'};
    $self->{'socket'} = new IO::Socket::INET('LocalPort'=> $self->{'LocalPort'}, 'Proto' => 'tcp', 'Type' => SOCK_STREAM, 'Listen' => $self->{'Listen'})
	 or return "socket: $@";
#    $self->{'select'} = IO::Select->new($self->{'socket'});
    print "listening $self->{'LocalPort'} ok\n"  if $self->{'debug'};
    $self->{'accept'} = 1;
    $self->recv();
  }


  sub disconnect {
    my $self = shift;
    close($self->{'socket'});
    delete $self->{'socket'};
  }

  sub DESTROY {
    my $self = shift;
    $self->disconnect();
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

#print "TRYREAD $self->{'host'} [$self->{'select'}]\n" if $self->{'debug'};
    my ($databuf, $readed);
    do {
      $readed = 0;

#      for my $select (grep $_, $self->{'select'}, $self->{'selectin'} ) {
      for my $client ($self->{'select'}->can_read(1)) {
        if ($self->{'accept'} and $client == $self->{'socket'}) {
print "nconn\n";
          if ($_ = $self->{'socket'}->accept()) {
print "creat\n";
            $self->{'clients'}{$_} = $self->{'incomingclass'}->new( 'socket' => $_, 'LocalPort'=>$self->{'LocalPort'}, 'incoming'=>1, 'want' => \%{$self->{'want'}}, 'debug'=>1,), $self->{'clients'}{$_}->cmd('MyNick') unless $self->{'clients'}{$_};
#print "ok\n";
          }
#print "1\n";
          next;
        }

        ++$readed;
        $databuf = '';
        my $rv = $client->recv($databuf, POSIX::BUFSIZ, 0);
        unless (defined($rv) && length($databuf)) {
print "CLOSEME" if $self->{'debug'};
          $self->{'select'}->remove($client);
          $self->disconnect();
        }
        if ($self->{'filehandle'}) {
          $self->{'filebytes'} += length $databuf;
print "recv $self->{'filebytes'} of file\n";
          my $fh = $self->{'filehandle'};
          print $fh $databuf;
          close($self->{'filehandle'}), delete($self->{'filehandle'}) 
            if $self->{'filebytes'} == $self->{'filetotal'};
        } else {
print "($rv) ", POSIX::BUFSIZ, " {$databuf}\n" if $self->{'debug'};
          $buf .= $databuf;
          if (length $buf) {
            $buf =~ s/(.*\|)//;
            $self->parse(/^\$/ ? $_ : ($_ = '$chatline ' . $_)) for (grep $_, split(/\|/, $1));
          }
        }
      }
#      }
    } while ($readed);
    for (keys %{$self->{'clients'}}) {
#print "\n!! $self->{'clients'}{$_}->{'socket'} !!\n" ;
      delete $self->{'clients'}{$_}, last unless $self->{'clients'}{$_}->{'socket'};
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
    return unless $self->{'socket'};
    if ($self->{'sendbuf'})  {
      push @sendbuf , '$' . join(' ', @_) . '|';
    } else {
      $self->{'socket'}->send($_ = join('', @sendbuf, '$' . join(' ', @_) . '|')); 
      @sendbuf = ();
      print"we send [$_] to [$self->{'socket'}]\n" if $self->{'debug'};
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

1;
