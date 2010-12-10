#!/usr/bin/perl
#$Id$ $URL$

=head1 NAME

run dc client with file sharing

=head1 SYNOPSIS

 ./share.pl dchub://hub.net hub.com adc://hub.edu dir /dir/dir ...

 unix adc:
 ./share.pl adc://dc.hub.com:412 /share
 win nmdc:
 ./share.pl dc.hub.com c:/pub c:/distr

 manual build filelist:
 ./share.pl /share /sharemore

=head1 INSTALL

recommended module: Sys::Sendfile

=head1 CONFIGURE

 create config.pl and fill with your sharedir, hubs and other options:
  cp config.pl config.pl.dist 
 
 config with sharedirs:
  $config{dc}{'share'} = [qw(/usr/ports/distfiles c:\distr c:\pub\ )];

 predefined dc hubs:
  $config{dc}{host} = ['myhub.net', 'adc://otherhub.com'];

 if hubs and shares defined in config you can use simple
  ./share.pl

 full list of options available in ../lib/Net/DirectConnect/filelist.pm:
  $self->{file_min} in filelist.pm must be written as 
  $config{dc}{file_min} = 1_000_000; #skip files smaller 1MB 
  
=head1 TUNING

freebsd:
speedup: sysctl net.inet.tcp.sendspace=200000
or: sysctl kern.ipc.maxsockbuf=8388608 net.inet.tcp.sendspace=3217968 

=head1 TODO

filelist xml escape chars

=head1 windows install:
get perl from http://strawberryperl.com/ and install and run
C:\strawberry\perl\bin\cpan.bat Net::DirectConnect::TigerHash
C:\strawberry\perl\bin\cpan.bat Net::DirectConnect
C:\strawberry\perl\site\bin\share.bat 
or with config:
get tar.gz from http://search.cpan.org/dist/Net-DirectConnect/
unpack, 
cd examples
cp config.pl.dist config.pl
edit config.pl
perl share.pl

=cut

use 5.10.0;
use strict;
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
use Time::HiRes qw(time sleep);
use Encode;

#use Encode;
use lib::abs '../lib';
#use lib '../TigerHash/lib';
#use lib './stat/pslib';
our ( %config, $db );
use Net::DirectConnect::pslib::psmisc;# qw(:config :log);
#use pssql;
use Net::DirectConnect;
use Net::DirectConnect::filelist;
#psmisc::use_try 'Sys::Sendfile';
$config{ 'log_' . $_ } //= 0 for qw (dmp dcdmp dcdbg adcdev);
$config{'log_pid'} //= 1;
psmisc::config();      #psmisc::lib_init();
psmisc::lib_init();    #for die handler
psmisc::printlog("usage: $1 [adc|dchub://]host[:port] [dir ...]\n"), exit if !$ARGV[0] and !$config{dc}{host};
psmisc::printlog( 'info', 'started:', $^X, $0, join ' ', @ARGV );
my $log = sub (@) {
  my $dc = ref $_[0] ? shift : {};
  psmisc::printlog shift(), "[$dc->{'number'}]", @_,;
};
$SIG{PIPE} = sub { printlog( 'sig', 'PIPE' ) };
my @dirs = grep { -d } @ARGV;
#printlog('dev', 'started', @ARGV),
my $filelist = shift @ARGV if $ARGV[0] ~~ 'filelist';
@ARGV = grep { !-d } @ARGV;
Net::DirectConnect::filelist->new( log => $log, %{ $config{dc} || {} } )->filelist_make(@dirs), exit
  if ($filelist and !caller) or (!@ARGV and !$config{dc}{host});
#use Net::DirectConnect::adc;
#my $dc =
my @dc;
@dc = map {
  Net::DirectConnect->new(
    modules            => ['filelist'],
    share => \@dirs,
    'filelist_builder' => ( join ' ', $^X, $0, 'filelist' ),
    dev_http           => 1,
    'log'              => $log,
    'handler'          => {
      map {
        my $msg = $_;
        $msg => sub {
          my $dc = shift;
          #warn join ' ', "c$dc->{charset_console}, $dc->{charset_chat} , $dc->{charset_protocol}";
          if ($dc->{nmdc}) {
            @_ = Encode::encode $dc->{charset_console}, Encode::decode(($dc->{charset_chat} || $dc->{charset_protocol}), join ' ', @_);
          }
          say join ' ', $msg, @_;
          },
        } qw(welcome chatline To)
    },
    auto_connect => 1,
    #auto_work    => 1,
    worker => sub {
      my $dc = shift;
      psmisc::schedule(
        [ 20, 100 ],
        our $dump_sub__ ||= sub {
          psmisc::printlog "Writing dump";
          psmisc::file_rewrite( $0 . '.dump', Dumper @dc );
        }
      ) if $config{debug};
    },
    %{ $config{dc} || {} },
    #( $ARGV[0] ? ( 'host' => $ARGV[0] ) : () ),
    'host' => $_,
    )
  } (
  grep {
    $_
    } @ARGV ? @ARGV : ref $config{dc}{host} eq 'ARRAY' ? @{ $config{dc}{host} } : $config{dc}{host},
  
  );
while ( @dc = grep { $_ and $_->active() } @dc ) {
  $_->work() for @dc;
}
