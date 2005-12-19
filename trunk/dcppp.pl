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

#  require 'dcppp.pm';
  use dcppp; 
  use dcppp::client;

  my $dc = dcppp::client->new(
   'host'=>'dc.setun.net',
#   'host'=>'dcpp.migtel.ru',
  );

#  $dc->{'debug'} = 1;
  $dc->connect();
#  $dc->chatline('hello world');
  $dc->{'cmd'}{'GetNickList'}->();
  $dc->recv();
  $dc->{'cmd'}{'GetINFO'}->('pro');
#  sleep 1;
  $dc->recv() while 1;
#  sleep 1;
#  $dc->recv();

#sleep 10; 
