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

  sub new {
    my $class = shift;
    my $self = { };
    bless($self, $class);
    $self->init(@_);
    return $self;
  }
 
  sub connect {
    my $self = shift;
    print "connecting to $self->{'host'}, $self->{'port'}, $self->{'Nick'}, $self->{'pass'}\n"  if $self->{'debug'};
    $self->{'socket'} = new IO::Socket::INET('PeerAddr'=>$self->{'host'}, 'PeerPort' => $self->{'port'}, 'Proto' => 'tcp', 'Type' => SOCK_STREAM, )
	 or return "socket: $@";
    $self->{'select'} = IO::Select->new($self->{'socket'});
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
print "TRYREAD" if $self->{'debug'};
    return unless $self->{'socket'};
    my ($databuf, $readed);
    do {
      $readed = 0;
      for my $client ($self->{'select'}->can_read(1)) {
        ++$readed;
        $databuf = '';
        my $rv = $client->recv($databuf, POSIX::BUFSIZ, 0);
        $buf .= $databuf;
print "($rv) ", POSIX::BUFSIZ, " {$databuf}\n" if $self->{'debug'};
        unless (defined($rv) && length($databuf)) {
print "CLOSEME" if $self->{'debug'};
         $self->{'select'}->remove($client);
         $self->disconnect();
         #TODO close
        }
        $buf =~ s/(.*\|)//;
        $self->parse(/^\$/ ? $_ : ($_ = '$chatline ' . $_)) for (grep $_, split(/\|/, $1));
      }
    } while ($readed);
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
        print "UNKNOWN HUBCMD:[$cmd]{$_} : please add \$dc->{'parse'}{'$cmd'} = sub { ... };\n";
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
      print"we send [$_]\n" if $self->{'debug'};
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
  }

1;
