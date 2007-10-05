#!/usr/bin/perl
# $Id$ $URL$

=copyright
flood tests
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
eval { use Time::HiRes qw(time sleep); };
use lib './lib';
use dcppp::clihub;
our (%config);

sub shuffle {
  my $deck = shift;    # $deck is a reference to an array
  my $i    = @$deck;
  while ( $i-- ) {
    my $j = int rand( $i + 1 );
    @$deck[ $i, $j ] = @$deck[ $j, $i ];
  }
  return $deck;
}

sub rand_int {
  my ( $from, $to ) = @_;
  return $from + int rand( $to - $from );
}

sub rand_char {
  my ( $from, $to ) = @_;
  #perl -e "print chr($_) for (32+65..32+65+25)"
  $from ||= 32 + 65;
  $to   ||= 32 + 65 + 25;
  return chr( rand_int( $from, $to ) );
}

sub rand_str {
  my ( $len, $from, $to ) = @_;
  $len ||= 10;
  my $ret;
  $ret .= rand_char( $from, $to ) for ( 0 .. $len );
  return $ret;
}

sub rand_str_ex {
  my ( $str, $chg ) = @_;
  $chg ||= int( length($str) / 10 );
  local @_ = split( //, $str );
  for ( 0 .. $chg ) {
    $_[ rand scalar @_ ] = rand_char();
  }
  return join '', @_;
}

sub handler {
  my $name = shift;
  #  print "handler($name) = [$config{'handler'}{$name}]\n";
  return $config{'handler'}{$name}->(@_) if ref $config{'handler'}{$name} eq 'CODE';
  return;
}
require 'flooddef.pl';
do 'floodmy.pl';
print("usage: flood.pl [dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];
handler( 'mail_loop_bef', @ARGV );

sub createbot {
  my ( $host, $port ) = @_;
  local $_ = dcppp::clihub->new(
    'host' => $host,
    ( $port ? ( 'port' => $port ) : () ),
    'auto_connect' => 0,
    #    'log'              => sub { local $_ = shift;    return if $_ eq 'dcdmp';    print( join( ' ', $_, @_ ), "\n" ) },
    %{ ( ref $config{'dcbot_param'} eq 'CODE' ? $config{'dcbot_param'}->() : $config{'dcbot_param'} ) or {} },
    handler('param'),
  );
  handler( 'create_aft', $_ );
  $_->connect();
  return $_;
}
TRY: for ( 0 .. $config{'flood_tries'} ) {
  print("try $_\n"), handler( 'create_bef', $_ );
  $ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?$|i;
  #print("host=$1; port=$2;\n");
  my $dc = createbot( $1, $2 );
  $dc->{'disconnect_recursive'} = 0;
  $dc->{'clients'}{$_} = createbot( $1, $2 ), print("addbot[$_] = $dc->{'clients'}{$_}{'number'}\n"),
    #  handler( 'create_aft', $dc->{'clients'}{$_} ),
    #  $dc->wait(),
    #  sleep(0.1),
    #  $dc->wait(),
    $dc->wait_sleep(),
    #  $dc->info(),
    for 2 .. $config{'bots'};
  #
  $dc->info();
  handler( 'destroy', $dc ), next if !$dc->{'socket'};
  for ( 1 .. $config{'connect_wait'} ) {    #sleep(5); $dc->recv();
    last if !$dc->{'socket'} or $dc->{'status'} eq 'connected';
    $dc->wait() for 0 .. 10;
    #    sleep(1);
  }
  handler( 'destroy', $dc ), next if !$dc->{'socket'};
  $dc->wait(),
    #    sleep(1)
    for ( 0 .. $config{'connect_aft_wait'} );
  handler( 'destroy', $dc ), next if !$dc->{'socket'};
  handler( 'send_bef', $dc );
  for ( 0 .. $config{'send_tries'} ) {
    last if !$dc->{'socket'} or $dc->{'status'} ne 'connected';
    handler( 'send', $dc, $_ ), sleep( $config{'send_sleep'} );
    $dc->recv(),;
  }
  handler( 'send_aft', $dc );
  $dc->recv();
  handler( 'destroy_bef', $dc );
  handler( 'destroy',     $dc );
  $dc->destroy() if !$config{'no_destroy'};
  sleep( $config{'after_sleep'} );
  print "ok\n";
  handler( 'aft', $dc );
}
handler('end');
