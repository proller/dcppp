#!/usr/bin/perl -w
# $Id$ $URL$

=copyright
tests
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
use strict;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
use lib './lib';
use dcppp::clihub;
#  require 'lib/dcppp.pm';
#  require 'lib/dcppp/clihub.pm';
#  require 'lib/dcppp/clicli.pm';
#  use dcppp;
#  use dcppp::client;
#for my $host (qw(dc.setun.net  dc.setun.net dc.setun.net dc.crossnet.ru dc.lanport.ru )) {
for my $host (qw(dc.setun.net  )) {
  #for my $host (qw(dc.lanport.ru )) {
  #for my $host (qw(dc.crossnet.ru dc.ozerki.net)) {
  #for my $host (qw(fili.no-ip.org dc-files.info)) {
  my $dc = dcppp::clihub->new(
    #  'host' => 'dc.setun.net',
    #  'myip' => '10.20.199.104',
    #  'port' => 4111,
    #   'host'=>'dcpp.migtel.ru',
    #'myip'=> '88.210.52.26',
         'myport' => '412',
#         'myport' => '80',
    #     'myport' => '53333',
    #  'host' => 'hub.selfip.com',
    #  'host' => 'dc.crossnet.ru',
    'host' => $host,
    #  'host'=>'freehub.ru',
    #  'port' => 411,
  );

=example
  $dc->{'handler'}{'MyINFO'} = sub {
    ($_) = $_[0] =~ /\S+\s+(\S+)\s+(.*)/;
    print "my cool info parser gets info about $1\n";
  }, 
=cut
  #$dc->connect();
  #  $dc->listen();
  #$dc->{'autorecv'} = 1;
  #  $dc->cmd('chatline','hello world');
  #$dc->cmd('GetNickList');
  #  $dc->cmd('ConnectToMe', 'pro');
  $dc->work();
#  $dc->cmd('chatline','hello world! i\'m perl bot. Freebsd rulez.');
#  $dc->{'autorecv'} = 0;
#  $dc->{'MyINFO'}	= $_.'$ $LAN(T3)1$e-mail@mail.ru$1$',$dc->recv(),  print("! $_ !\n"),  $dc->cmd('MyINFO'),sleep 1for (1..1000);
#$dc->cmd('Quit');
#$dc->work(5);
#$dc->cmd('search', 'xxx');
#$dc->cmd('search', 'house');
#$dc->work(),

#UMBUUX4MUG4SQDVOAC6JWZVMXAI2HVLS4NG52QA

#print("! $_ !\n"), # $dc->cmd('ConnectToMe',$_)
  $dc->get( $_, 'files.xml.bz2', $_ . '.xml.bz2' )for qw(pro prrrrroo);
  $dc->get( $_, 'files.xml.bz2', $_ . '.xml.bz2' ), $dc->work() for grep $_ ne $dc->{'Nick'}, keys %{ $dc->{'NickList'} };
#  $dc->recv();
#  $dc->{'cmd'}{'GetINFO'}->('pro');
#  sleep 1;
#print "DIS\n";
#$dc->disconnect();
#print "OK\n";
# print"R\n",
  $dc->work(100);    #wait for download starting
  $dc->wait_finish();
  #$dc->recv(),  while 600;
  #  sleep 1;
  #  $dc->recv();
  #sleep 10;
  $dc->disconnect();
  #print Dumper $dc;
  $dc = undef;
}
