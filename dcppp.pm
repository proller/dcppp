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

#  our SOCK_STREAM;

package dcppp;
#  use Socket;
#  use Fcntl;
  use IO::Socket;
  use IO::Select;
  use POSIX;
  use strict;

  sub new {
    my $class = shift;
    my $self = {
#        'MAXLEN' => 1024*1024,
	@_ };
    bless($self, $class);
    $self->init(@_);
    return $self;
  }

 
  sub connect {
    my $self = shift;
    print "connecting to $self->{'host'}, $self->{'port'}, $self->{'Nick'}, $self->{'pass'}\n"  if $self->{'debug'};

    $self->{'socket'} = new IO::Socket::INET('PeerAddr'=>$self->{'host'}, 'PeerPort' => $self->{'port'}, 'Proto' => 'tcp', 
                                  'Type' => SOCK_STREAM, )	 or return "socket: $@";
#    nonblock($self->{'socket'});
    $self->{'select'} = IO::Select->new($self->{'socket'});
#print "zz";
#    ++$self->{'mustrecv'};
#    $self->checkrecv();
    $self->recv();
  }

  sub disconnect {
    my $self = shift;
    close($self->{'socket'});
  }

  sub recv {
    my $self = shift;
    my ($buf, $databuf, $readed);
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
         #TODO close
        }
        $buf =~ s/(.*\|)//;
        $self->parsehub(/^\$/ ? $_ : ($_ = '$chatline ' . $_))for(grep $_, split(/\|/, $1));
      }
    } while ($readed);
  }
 
  sub parsehub {
    my $self = shift;
    for(@_) {
      s/^\$(\w+)\s*//;
      my $cmd = $1;
      if($self->{'parse'}{$cmd}) {
        $self->{'parse'}{$cmd}->($_);
      } else {
        print "UNKHUBCMD:[$cmd]{$_}\n";
      }                                                 
      $self->{'handler'}{$cmd}->($_) if $self->{'handler'}{$cmd};
    }
  }

{ my @sendbuf;
  sub sendcmd {
    my $self = shift;
    if ($self->{'sendbuf'})  {
      push @sendbuf , '$' . join(' ', @_) . '|';
    } else {
      $self->{'socket'}->send($_ = join('', @sendbuf, '$' . join(' ', @_) . '|')); 
      @sendbuf = ();
      print"we send [$_]\n" if $self->{'debug'};
    }
  }
}


1;
