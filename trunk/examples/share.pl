#!/usr/bin/perl
#$Id$ $URL$

=head1 NAME

run dc client with file sharing

=head1 SYNOPSIS

 ./share.pl hub dir dir ...

 unix adc:
 ./share.pl adc://dc.hub.com:412 /share
 win nmdc:
 ./share.pl dc.hub.com c:/pub c:/distr

 build filelist:
 ./share.pl adc://dc.hub.com:412 filelist /share


=head1 INSTALL

recommended module: Sys::Sendfile

=head1 CONFIGURE 

 echo '$config{dc}{'share'} = [qw(/usr/ports/distfiles c:\distr c:\pub\ )];' >> config.pl

 also useful:
 $config{dc}{host} = 'myhub.net';


=head1 TUNING

freebsd:
speedup: sysctl net.inet.tcp.sendspace=200000
or: sysctl kern.ipc.maxsockbuf=8388608 net.inet.tcp.sendspace=3217968 

=head1 TODO

filelist xml escape chars

=cut

use 5.10.0;
use strict;
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
use Time::HiRes qw(time sleep);
#use Encode;
use lib '../lib';
#use lib '../TigerHash/lib';
use lib './stat/pslib';
our ( %config, $db );
use psmisc;
#use pssql;
use Net::DirectConnect;
use Net::DirectConnect::filelist;
#psmisc::use_try 'Sys::Sendfile';
$config{ 'log_' . $_ } //= 0 for qw (dmp dcdmp dcdbg);
$config{'log_pid'} //= 1;
psmisc::config();    #psmisc::lib_init();
printlog("usage: $1 [adc|dchub://]host[:port] [dir ...]\n"), exit if !$ARGV[0] and !$config{dc}{host};
printlog( 'info', 'started:', $^X, $0, join ' ', @ARGV );
my $log = sub (@) {
    my $dc = ref $_[0] ? shift : {};
    psmisc::printlog shift(), "[$dc->{'number'}]", @_,;
  };

#printlog('dev', 'started', @ARGV),
Net::DirectConnect::filelist->new(log=>$log, %{ $config{dc} || {} } )->filelist_make(@ARGV), exit if $ARGV[0] ~~ 'filelist' and !caller;
#use Net::DirectConnect::adc;
my $dc = Net::DirectConnect->new(
  modules  => ['filelist'],
  'filelist_builder' => (join ' ', $^X, $0, 'filelist'),

  dev_http => 1,
  'log'    => $log,
  'handler' => {
    map {
      my $msg = $_;
      $msg => sub {
        my $dc = shift;
        say join ' ', $msg, @_;
        },
      } qw(welcome chatline To)
  },
  auto_connect => 1,
  auto_work    => sub {
    my $dc = shift;
    psmisc::schedule(
      [ 20, 100 ],
      our $dump_sub__ ||= sub {
        printlog "Writing dump";
        psmisc::file_rewrite( $0 . '.dump', Dumper $dc);
      }
    ) if $config{debug};
  },
  %{ $config{dc} || {} },
  ( $ARGV[0] ? ( 'host' => $ARGV[0] ) : () ),
);
