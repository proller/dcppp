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

  use strict;
  use IO::Socket;

# func:

# connect
# disconnect
# ..


# options:

# host 
# port
# name
# pass


sub new {
  my $class = shift;
  my $self = {};
  bless($self, $class);
  return $self;
}

sub connect {
  my ($self, $host, $port, $name, $pass) = @_;

print "connecting to $host, $port, $name, $pass";

  my $sockres = new IO::Socket::INET->new(PeerAddr=>$host, PeerPort => $port, Proto => 'tcp', 
                                Type => SOCK_STREAM)	 or return "socket: $@";

  close($sockres);

}

sub disconnect {
    shift;


}

sub import {
    shift;
}

sub unimport {
    shift;
}

1;
