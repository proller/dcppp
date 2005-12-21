#!/usr/bin/perl
my $Id = '$Id$';
=copyright
dcpp for perl 
Copyright (C) 2003-2005 !!CONTACTS HERE!!

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

  use strict;

  require 'lib/dcppp.pm';
  require 'lib/dcppp/client.pm';
  require 'lib/dcppp/clicli.pm';
#  use dcppp; 
#  use dcppp::client;

  my $dc = dcppp::client->new(
   'host'=>'dc.setun.net',
   'ip'=>'10.20.199.104',
#   'host'=>'dcpp.migtel.ru',
   'LocalPort' => '6778',

  );

  $dc->{'debug'} = 1;

  $dc->{'handler'}{'MyINFO'} = sub {
    ($_) = $_[0] =~ /\S+\s+(\S+)\s+(.*)/;
    print "my cool info parser gets info about $1\n";
  }, 
 
  $dc->connect();
  $dc->cmd('chatline','hello world');
  $dc->cmd('GetNickList');
  $dc->listen();
  $dc->cmd('ConnectToMe', 'pro');

#  $dc->recv();
#  $dc->{'cmd'}{'GetINFO'}->('pro');
#  sleep 1;
#print "DIS\n";
#$dc->disconnect();
#print "OK\n";
  print"R\n",$dc->recv(), sleep 0.1 while 1;
#  sleep 1;
#  $dc->recv();

#sleep 10; 
