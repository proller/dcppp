#!/usr/bin/perl
#$Id$ $URL$

=readme

recommended: Sys::Sendfile
speedup: sysctl net.inet.tcp.sendspace=200000
or: sysctl kern.ipc.maxsockbuf=8388608 net.inet.tcp.sendspace=3217968 

todo:

scan 
 hash
make filelist

filelist xml escape chars


enable sharing : 
echo '$config{'share'} = [qw(C:\distr C:\pub\ )];' >> config.pl

=cut

use 5.10.0;
use strict;
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
#eval {
use Time::HiRes qw(time sleep);
#};
#use utf8;
use Encode;
use lib '../lib';
#use Net::DirectConnect::clihub;
#use Net::DirectConnect::adc;
use lib '../lib';
use lib '../TigerHash/lib';
use lib './stat/pslib';
our ( %config, $db );
use psmisc;
use pssql;
use Net::DirectConnect;
use Net::DirectConnect::filelist;
psmisc::use_try 'Sys::Sendfile';    #ok!
#sux psmisc::use_try 'Sys::Sendfile::FreeBSD';# or
#psmisc::use_try 'IO::AIO';
$config{ 'log_' . $_ } //= 0 for qw (dmp dcdmp dcdbg);
$config{'log_pid'} //= 1;
##$config{share_root} //= '';

=old
$config{tth_cheat}         //= 1_000_000;    #try find file with same name-size-date
$config{tth_cheat_no_date} //= 0;            #--//-- only name-size
$config{file_min}          //= 0;            #skip files  smaller
$config{share_full} ||= {};
$config{share_tth}  ||= {};
$config{chrarset_fs} //= 'cp1251' if $^O ~~ 'MSWin32';
$config{chrarset_fs} //= 'koi8r'  if $^O ~~ 'freebsd';
$config{'sql'} //= {
  'driver' => 'sqlite',
  'dbname' => 'files.sqlite',
  #'auto_connect'        => 1,
  'log' => sub { shift; psmisc::printlog(@_) },
  #'cp_in'               => 'cp1251',
  'connect_tries' => 0, 'connect_chain_tries' => 0, 'error_tries' => 0, 'error_chain_tries' => 0,
  #insert_by => 1000,
  #nav_all => 1,
  'table' => {
    'filelist' => {
      'path' => pssql::row( undef, 'type'        => 'VARCHAR', 'length' => 255, 'default' => '', 'index' => 1, 'primary' => 1 ),
      'file' => pssql::row( undef, 'type'        => 'VARCHAR', 'length' => 255, 'default' => '', 'index' => 1, 'primary' => 1 ),
      'tth'  => pssql::row( undef, 'type'        => 'VARCHAR', 'length' => 40,  'default' => '', 'index' => 1 ),
      'size' => pssql::row( undef, 'type'        => 'BIGINT',  'index'  => 1, ),
      'time' => pssql::row( 'time', ), #'index' => 1,
      #'added'  => pssql::row( 'added', ),
      #'exists' => pssql::row( undef, 'type' => 'SMALLINT', 'index' => 1, ),
    },
  }
};
=cut

#$config{filelist} ||= 'C:\Program Files\ApexDC++\Settings\HashIndex.xml';
#$config{share_full} ||= { 'files.xml.bz2' => 'C:\Program Files\ApexDC++\Settings\files.xml.bz2' };    # = (tthash=>'/path', ...);
psmisc::config();
#psmisc::lib_init();
#$db ||= pssql->new( %{ $config{'sql'} || {} }, );
#my ( $tq, $rq, $vq ) = $db->quotes();
#my $cantth;
#eval q{ use Net::DirectConnect::TigerHash qw(tthfile);  };
#printlog 'err', $@ if $@;
#psmisc::use_try 'Net::DirectConnect::TigerHash' ,qw(tthfile);
#if ($cantth) {
#print 'DUMp==',Dumper \%config;
#print Dumper  \%INC;
#for my $dir ( @{ $config{'share'} || [] } ) {
#print Dumper \%config;
#}
#}
printlog("usage: $1 [adc|dchub://]host[:port] [dir ...]\n"), exit if !$ARGV[0];
printlog( 'info', 'started:', $^X, $work{'$0'}, join ' ', @ARGV );
#sharescan(),
#print (Dumper $config{dc}),
Net::DirectConnect::filelist->new( %{ $config{dc} || {} } )->filelist_make(@ARGV), exit if $ARGV[0] ~~ 'filelist' and !caller;
#my ( $sharesize, $sharefiles, $shareloaded );
$SIG{INT} = $SIG{KILL} = sub { printlog 'exiting', exit; };
#my ( $sharesize, $sharefiles );    #= filelist_load();
#print "Arg=",$ARGV[0],"\n";
#$ARGV[0] =~ m|^(?:\w+\://)?(.+?)(?:\:(\d+))?$|;
#my $dc = Net::DirectConnect::clihub->new(
my $dc = Net::DirectConnect
  #::adc
  ->new(
  modules => ['filelist'],
  #'host' => $1,
  'host' => $ARGV[0],
  #( $2 ? ( 'port' => $2 ) : () ),
  #'Nick' => ( $ARGV[1] or int( rand(100000000) ) ),
  #'Nick'		=>	'xxxx',
  #'sharesize' => $sharesize || int( rand 10000000000 ) + int( rand 10000000000 ) * int( rand 100 ),
  #INF => { SS => $sharesize, SF => $sharefiles, },
  #'log'		=>	sub {},	# no logging
  #'client'      => '++',
  #'V'           => '0.698',
  #'description' => '',
  #'M'           => 'P',
  #'share_full'   => $config{share_full},
  #'share_tth'    => $config{share_tth},
  #chrarset_fs    => $config{chrarset_fs},
  dev_http => 1,
  'log'    => sub {
    my $dc = ref $_[0] ? shift : {};
    #psmisc::printlog shift(), $dc->{'number'}, join ' ', psmisc::human('time'), @_, "\n";
    psmisc::printlog shift(), "[$dc->{'number'}]", @_,;
  },
  'handler' => {
    map {
      my $msg = $_;
      $msg => sub {
        my $dc = shift;
        print join ' ', $msg, @_, "\n";
        },
      } qw(welcome chatline To)
  },
  auto_connect => 1,
  auto_work    => sub {
    my $dc = shift;

=dev
  psmisc::schedule(
    [ 30, 10000 ],
    our $search_sub__ ||= sub {
      #print "Writing dump\n";
      #psmisc::file_rewrite( 'dump', Dumper $dc);
      $dc->search('house');
    }
  );
=cut

    #}while ( $dc->active() ) {
    #$dc->work();
    psmisc::schedule(
      [ 20, 100 ],
      our $dump_sub__ ||= sub {
        printlog "Writing dump";
        psmisc::file_rewrite( $0 . '.dump', Dumper $dc);
      }
    ) if $config{debug};
    #$config{filelist_scan}
    #or !-e $config{files} or !-e $config{files}.'.bz2';
  },
  %{ $config{dc} || {} },
  );
#$dc->work(10);
#$dc->get( $_, 'files.xml.bz2', $_ . '.xml.bz2' ), $dc->work() for grep $_ ne $dc->{'Nick'}, keys %{ $dc->{'NickList'} };
#while ( $dc->active() ) {  $dc->work(); }
#$dc->destroy();
#sleep(1);
