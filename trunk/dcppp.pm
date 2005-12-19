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
  use IO::Socket;
  use strict;

  sub new {
    my $class = shift;
    my $self = {
	'host'	=> 'localhost', 
	'port'	=> 4111, 
	'Nick'	=> 'dcpppBot', 
	'pass'	=> '', 
        'MAXLEN' => 1024*1024,
	'Version'	=> '++ V:0.673,M:A,H:0/1/0,S:2', 
	'Key'	=> 'zzz', 
	'MyINFO'	=> 'interest$ $LAN(T3)1$e-mail@mail.ru$1$',
	@_ };
    bless($self, $class);
    $self->init();
    return $self;
  }

 
  sub connect {
    my $self = shift;
    print "connecting to $self->{'host'}, $self->{'port'}, $self->{'Nick'}, $self->{'pass'}\n"  if $self->{'debug'};

    $self->{'hubsock'} = new IO::Socket::INET('PeerAddr'=>$self->{'host'}, 'PeerPort' => $self->{'port'}, Proto => 'tcp', 
                                  'Type' => SOCK_STREAM, )	 or return "socket: $@";
#print "zz";
    ++$self->{'mustrecv'};
    $self->checkrecv();
#    $self->recv();
  }

  sub disconnect {
    my $self = shift;
    close($self->{'hubsock'});
  }

  sub recv {
    my $self = shift;
#print "[b", $self->{'hubsock'}->atmark  , "]";
    my $ret = $self->{'hubsock'}->recv($self->{'recieved'}, $self->{'MAXLEN'});
#print "[a", $self->{'hubsock'}->atmark  , "]";
    print "($ret){$self->{'recieved'}}\n" if $self->{'debug'};
    for(grep $_, split(/\|/, $self->{'recieved'})) {
      $self->parsehub($_), next if /^\$/;
      $self->chatrecv($_);
    }
  }

  sub checkrecv {
    my $self = shift;
    $self->recv(), $self->{'mustrecv'} = 0 if $self->{'mustrecv'};
  }
  
  sub chatline {
    my $self = shift;
    $self->{'hubsock'}->send("<$self->{'Nick'}> $_|") for(@_);
  }
    
  sub chatrecv {
    my $self = shift;
    print "CHATLINE:", @_, "\n";
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
      $self->{'hubsock'}->send($_ = join('', @sendbuf, '$' . join(' ', @_) . '|')); 
      @sendbuf = ();
      print"we send [$_]\n" if $self->{'debug'};
    }
  }
}

#package dcpppclient;




1;
