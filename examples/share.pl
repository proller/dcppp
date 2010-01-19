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

use strict;
use 5.10.0;
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
eval { use Time::HiRes qw(time sleep); };
#use utf8;
use Encode;
use lib '../lib';
#use Net::DirectConnect::clihub;
#use Net::DirectConnect::adc;
use Net::DirectConnect;
use lib '../lib';
use lib '../TigerHash/lib';
use lib './stat/pslib';
our ( %config, $db );
use psmisc;
use pssql;
psmisc::use_try 'Sys::Sendfile';    #ok!
#sux psmisc::use_try 'Sys::Sendfile::FreeBSD';# or
#psmisc::use_try 'IO::AIO';
$config{files} //= 'files.xml';
$config{ 'log_' . $_ } //= 0 for qw (dmp dcdmp);
$config{'log_pid'} //= 1;
$config{chrarset_fs} //= 'cp1251' if $^O ~~ 'MSWin32';
$config{chrarset_fs} //= 'koi8r'  if $^O ~~ 'freebsd';
$config{tth_cheat}         //= 1_000_000;    #try find file with same name-size-date
$config{tth_cheat_no_date} //= 0;            #--//-- only name-size
$config{file_min}          //= 0;            #skip files  smaller
##$config{share_root} //= '';
$config{filelist_scan} //= 3600;             #every seconds, 0 to disable
$config{share_full} ||= {};
$config{share_tth}  ||= {};
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
#$config{filelist} ||= 'C:\Program Files\ApexDC++\Settings\HashIndex.xml';
#$config{share_full} ||= { 'files.xml.bz2' => 'C:\Program Files\ApexDC++\Settings\files.xml.bz2' };    # = (tthash=>'/path', ...);
psmisc::config();
psmisc::lib_init();
$db ||= pssql->new( %{ $config{'sql'} || {} }, );
my ( $tq, $rq, $vq ) = $db->quotes();
#my $cantth;
#eval q{ use Net::DirectConnect::TigerHash qw(tthfile);  };
#printlog 'err', $@ if $@;
#psmisc::use_try 'Net::DirectConnect::TigerHash' ,qw(tthfile);
#if ($cantth) {
#print 'DUMp==',Dumper \%config;
#print Dumper  \%INC;
#for my $dir ( @{ $config{'share'} || [] } ) {
sub sharescan {
  my $notth;
  return unless psmisc::lock( 'sharescan', timeout => 0, old => 86400 );
  printlog( 'err', "sorry, cant load Net::DirectConnect::TigerHash for hashing" ), $notth = 1,
    unless psmisc::use_try 'Net::DirectConnect::TigerHash';    #( $INC{"Net/DirectConnect/TigerHash.pm"} );
  my $stopscan;
  my $level     = 0;
  my $levelreal = 0;
  my ( $sharesize, $sharefiles );
  psmisc::file_rewrite $config{files}, qq{<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<FileListing Version="1" Base="/" Generator="Net::DirectConnect $Net::DirectConnect::VERSION">
};
#<FileListing Version="1" CID="KIWZDBLTOFWIQOT6NWP7UOPJVDE2ABYPZJGN5TZ" Base="/" Generator="Net::DirectConnect $Net::DirectConnect::VERSION">
#};
  sub filelist_line ($) {
    for my $f (@_) {
      next if !length $f->{file} or !length $f->{'tth'};
      $sharesize += $f->{size};
      ++$sharefiles if $f->{size};
      #$f->{file} = Encode::encode( 'utf8', Encode::decode( $config{chrarset_fs}, $f->{file} ) ) if $config{chrarset_fs};
      psmisc::file_append $config{files}, "\t" x $level, qq{<File Name="$f->{file}" Size="$f->{size}" TTH="$f->{tth}"/>\n};
      #$config{share_full}{ $f->{tth} } = $f->{full} if $f->{tth};    $config{share_full}{ $f->{file} } ||= $f->{full};
      $f->{'full'} ||= $f->{'path'} . '/' . $f->{'file'};

=cu
      $config{share_full}{ $f->{'tth'} } = $f->{'full_local'}, $config{share_tth}{ $f->{'full_local'} } = $f->{'tth'},
        $config{share_tth}{ $f->{'file'} } = $f->{'tth'},
        if $f->{'tth'};
      $config{share_full}{ $f->{'file'} } ||= $f->{'full_local'};
=cut

    #printlog 'set share', "[$f->{file}], [$f->{tth}] = [$config{share_full}{ $f->{tth} }],[$config{share_full}{ $f->{file} }]";
    #printlog Dumper $config{share_full};
    }
  }

  sub scandir (@) {
    for my $dir (@_) {
      last if $stopscan;
      $dir =~ tr{\\}{/};
      $dir =~ s{/+$}{};
      opendir( my $dh, $dir ) or print("can't opendir $dir: $!\n"), next;
      #@dots =
      ( my $dirname = $dir );
      $dirname =
        #Encode::encode 'utf8',
        Encode::decode $config{chrarset_fs}, $dirname if $config{chrarset_fs};
      unless ($level) {
        for ( split '/', $dirname ) {
          psmisc::file_append $config{files}, "\t" x $level, qq{<Directory Name="$_">\n};
          ++$level;
        }
      } else {
        $dirname =~
          #W s/^\w://;
          #$dirname =~
          s{.*/}{};
        psmisc::file_append $config{files}, "\t" x $level, qq{<Directory Name="$dirname">\n};
        ++$level;
        ++$levelreal;
      }
      psmisc::schedule( [ 10, 10 ], our $my_every_10sec_sub__ ||= sub { printinfo() } );
      for my $file ( readdir($dh) ) {
        last if $stopscan;
        next if $file =~ /^\.\.?$/;
        #$file = Encode::encode( 'utf8', Encode::decode( $config{chrarset_fs}, $file ) ) if $config{chrarset_fs};
        my $f = { path => $dir, path_local => $dir, file => $file, file_local => $file, full_local => "$dir/$file", };
        #$f->{full_local} = "$f->{path_local}/$f->{file_local}";
        #print("d $f->{full}:\n"),
        $f->{dir} = -d $f->{full_local};
        #filelist_line($f),
        scandir( $f->{full_local} ), next if $f->{dir};
        $f->{size} = -s $f->{full_local} if -f $f->{full_local};
        next if $f->{size} < $config{file_min};
        $f->{file} =    #Encode::encode 'utf8',
          Encode::decode $config{chrarset_fs}, $f->{file} if $config{chrarset_fs};
        $f->{path} =    #Encode::encode 'utf8',
          Encode::decode $config{chrarset_fs}, $f->{path} if $config{chrarset_fs};
        $f->{full} = "$f->{path}/$f->{file}";
        $f->{time} = int( $^T - 86400 * -M $f->{full_local} );    #time() -
#printlog 'timed', $f->{time}, psmisc::human('date_time', $f->{time}), -M $f->{full_local}, int (86400 * -M $f->{full_local}), $^T;
#'res=',
#join "\n",     grep { !/^\.\.?/ and
#/^\./ &&     -f "$dir/$_"     }
#print " ", $file;
#todo - select not all cols
        my $indb =
          $db->line( "SELECT * FROM ${tq}filelist${tq} WHERE"
            . " ${rq}path${rq}="
            . $db->quote( $f->{path} )
            . " AND ${rq}file${rq}="
            . $db->quote( $f->{file} )
            . " AND ${rq}size${rq}="
            . $db->quote( $f->{size} )
            . " AND ${rq}time${rq}="
            . $db->quote( $f->{time} )
            . " LIMIT 1" );
        #printlog ('already scaned', $indb->{size}),
        filelist_line( { %$f, %$indb } ), next, if $indb->{size} ~~ $f->{size};
        #$db->select('filelist', {path=>$f->{path},file=>$f->{file}, });
        #printlog Dumper ;
        #print "\n";
        #my $tth;
        if ( $f->{size} > $config{tth_cheat} ) {
          my $indb =
            $db->line( "SELECT * FROM ${tq}filelist${tq} WHERE "
              . "${rq}file${rq}="
              . $db->quote( $f->{file} )
              . " AND ${rq}size${rq}="
              . $db->quote( $f->{size} )
              . ( $config{tth_cheat_no_date} ? () : " AND ${rq}time${rq}=" . $db->quote( $f->{time} ) )
              . " LIMIT 1" );
          #printlog 'sel', Dumper $indb;
          if ( $indb->{tth} ) {
            printlog 'dev', "already summed", %$f, '     as    ', %$indb;
            $f->{$_} ||= $indb->{$_} for keys %$indb;
            #filelist_line($f);
            #next;
          }
        }
        if ( !$notth and !$f->{tth} ) {
          #printlog 'calc', $f->{full};
          my $time = time();
          $f->{tth} = Net::DirectConnect::TigerHash::tthfile( $f->{full_local} );
          my $per = time - $time;
          printlog 'time', $f->{full}, psmisc::human( 'size', $f->{size} ), 'per', psmisc::human( 'time_period', $per ),
            'speed ps', psmisc::human( 'size', $f->{size} / ( $per or 1 ) ), 'total', psmisc::human( 'size', $sharesize )
            if
            #$f->{size} > 100_000 or
            $per > 1;
        }
        #$f->{tth} = $f->{size} > 1_000_000 ? 'bigtth' : tthfile( $f->{full} );    #if -f $full;
        #print Dumper $config{share_full};
        #next;
        #print ' ', tthfile($full) if -f $full ; #and -s $full < 1_000_000;
        #print ' ', $f->{tth};
        #print ' ', $f->{size};    #if -f $f->{full};
        #print join ':',-M $f->{full}, $^T + 86400 * -M $f->{full},$f->{time};
        #print "\n";
        filelist_line($f);
        $db->insert_hash( 'filelist', $f ) if $f->{tth};
      }
      --$level;
      --$levelreal;
      psmisc::file_append $config{files}, "\t" x $level, qq{</Directory>\n}; #<!-- $levelreal $level -->
      closedir $dh;
    }
    if ( $levelreal < 0 ) { 
#      psmisc::file_append $config{files}, "<!-- backing to root $levelreal $level -->\n";
psmisc::file_append $config{files}, "\t" x $level, qq{</Directory>\n} while --$level >= 0; 
$levelreal = $level = 0;
}

    #$level
  }
  #else {
  printlog "making filelist $config{files} from", grep { -d } @ARGV, @{ $config{'share'} || [] },;
  $db->do('ANALYZE');
  my $interrupted;
  sub printinfo() {
    printlog 'sharesize', psmisc::human( 'size', $sharesize ), $sharefiles, scalar keys %{ $config{share_full} };
  }
  $SIG{INT} = sub { ++$stopscan; ++$interrupted; print "INT rec, stopscan\n" };
  $SIG{INFO} = sub { printinfo(); };
  scandir $_ for ( grep { -d } @ARGV, @{ $config{'share'} || [] }, );
  undef $SIG{INT};
  undef $SIG{INFO};
  psmisc::file_append $config{files}, qq{</FileListing>};
  psmisc::file_append $config{files};
  $db->flush_insert();

  if ( psmisc::use_try 'IO::Compress::Bzip2'
    and local $_ = IO::Compress::Bzip2::bzip2( $config{files} => $config{files} . '.bz2' )
    or printlog "bzip2 failed: $IO::Compress::Bzip2::Bzip2Error" and 0 )
  {
  } else {
    printlog 'dev', 'using system bzip2', $_, $!,':',
    `bzip2 -f "$config{files}"`;
  }
#unless $interrupted;
#$config{share_full}{ $config{files} . '.bz2' } = $config{files} . '.bz2';  $config{share_full}{ $config{files} } = $config{files};
#}
  psmisc::unlock('sharescan');
  printinfo();
  return ( $sharesize, $sharefiles );
}
#print Dumper \%config;
#}
#}
printlog("usage: $1 [adc|dchub://]host[:port] [dir ...]\n"), exit if !$ARGV[0];
printlog( 'info', 'started:', $^X, $work{'$0'}, join ' ', @ARGV );
sharescan(), exit if $ARGV[0] ~~ 'filelist' and !caller;
#my ( $sharesize, $sharefiles, $shareloaded );
my ($shareloaded);

sub filelist_load {

=old
  if ( $config{filelist} and open my $f, '<', $config{filelist} ) {
    printlog "loading filelist..";
    local $/ = '<';
    while (<$f>) {
      if ( my ( $file, $time, $tiger ) = /^File Name="([^"]+)" TimeStamp="(\d+)" Root="([^"]+)"/i ) {
        #$self->{'share_tth'}{ $params->{TR} }
        $file =~ tr{\\}{/};
        $config{share_full}{$tiger} = $file;
        $config{share_tth}{$file}   = $tiger;
      }
      #<File Name="c:\distr\neo\tmp" TimeStamp="1242907656" Root="3OPSFH2JD2UPBV4KIZAPLMP65DSTMNZRTJCYR4A"/>
    }
    close $f;
    printlog ".done:", ( scalar keys %{ $config{share_full} } ), "\n";
  }
=cut

  #printlog "filelist_load try", $shareloaded , -s $config{files};
  return
    if !(
        $config{files}
    and $shareloaded != -s $config{files}
    and (!$shareloaded or psmisc::lock( 'sharescan', timeout => 0, old => 86400 )) 
    and open my $f,
    '<', $config{files}
    );
  my ( $sharesize, $sharefiles );
  printlog "loading filelist", -s $f;
  $shareloaded = -s $f;
  local $/ = '<';
  %{ $config{share_full} } = %{ $config{share_tth} } = ();
  my $dir;

  while (<$f>) {
    #<Directory Name="distr">
    #<File Name="3470_2.x.rar" Size="18824575" TTH="CL3SVS5UWWSAFGKCQZTMGDD355WUV2QVLNNADIA"/>
    if ( my ( $file, $size, $tth ) = m{^File Name="([^"]+)" Size="(\d+)" TTH="([^"]+)"}i ) {
      my $full_local = ( my $full = "$dir/$file" );
#printlog 'loaded', $dir, $file  , $full;
      $full_local = Encode::encode $config{chrarset_fs}, $full if $config{chrarset_fs};

      $config{share_full}{$tth} = $full_local, $config{share_tth}{$full_local} = $tth, $config{share_tth}{$file} = $tth,
        if $tth;
      $config{share_full}{$file} ||= $full_local;
      ++$sharefiles;
      $sharesize += $size;
      #$self->{'share_tth'}{ $params->{TR} }
      #$file =~ tr{\\}{/};
    } elsif ( my ($curdir) = m{^Directory Name="([^"]+)">}i ) {
      $dir .= ( ( !length $dir and $^O ~~ [ 'MSWin32', 'cygwin' ] ) ? () : '/' ) . $curdir;
#      printlog 'now in', $dir;
      #$config{files}
    } elsif (m{^/Directory>}i) {
      $dir =~ s{(?:^|/)[^/]+$}{};
 #     printlog 'now ba', $dir;
    }
  }
  $config{share_full}{ $config{files} . '.bz2' } = $config{files} . '.bz2';
  $config{share_full}{ $config{files} } = $config{files};
  printlog "loaded filelist size", $shareloaded, ' : files=', $sharefiles, 'bytes=', psmisc::human( 'size', $sharesize ),
    scalar keys %{ $config{share_full} };
  psmisc::unlock('sharescan');
  $_[0]->( $sharesize, $sharefiles ) if ref $_[0] ~~ 'CODE';
  return ( $sharesize, $sharefiles );
}
$SIG{INT} = $SIG{KILL} = sub { printlog 'exiting', exit; };
my ( $sharesize, $sharefiles ) = filelist_load();
#print "Arg=",$ARGV[0],"\n";
#$ARGV[0] =~ m|^(?:\w+\://)?(.+?)(?:\:(\d+))?$|;
#my $dc = Net::DirectConnect::clihub->new(
my $dc = Net::DirectConnect
  #::adc
  ->new(
  #'host' => $1,
  'host' => $ARGV[0],
  #( $2 ? ( 'port' => $2 ) : () ),
  #'Nick' => ( $ARGV[1] or int( rand(100000000) ) ),
  #'Nick'		=>	'xxxx',
  'sharesize' => $sharesize || int( rand 10000000000 ) + int( rand 10000000000 ) * int( rand 100 ),
  INF => { SS => $sharesize, SF => $sharefiles, },
  #'log'		=>	sub {},	# no logging
  #'client'      => '++',
  #'V'           => '0.698',
  #'description' => '',
  #'M'           => 'P',
  'file_send_by' => 1024 * 1024 * 1,
  'share_full'   => $config{share_full},
  'share_tth'    => $config{share_tth},
  chrarset_fs    => $config{chrarset_fs},
  dev_http       => 1,
  'log'          => sub {
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
    psmisc::schedule(
      $config{filelist_scan},
      our $sharescan_sub__ ||= sub {
        #printlog ('filelist actual', -M $config{files},(time - $^T + 86400 * -M $config{files}) , $config{filelist_scan}),
        return if -e $config{files} and $config{filelist_scan} > time - $^T + 86400 * -M $config{files};
        psmisc::startme( 'filelist', grep { -d } @ARGV );
      }
    ) if $config{filelist_scan};
    psmisc::schedule(
      60,
      our $filelist_load_sub__ ||= sub {
        #psmisc::startme( 'filelist', grep { -d } @ARGV );
        #my($sharesize,$sharefiles) =
        filelist_load(
          sub {
            my ( $sharesize, $sharefiles ) = @_;
            $dc->{INF}{SS} = $sharesize, $dc->{INF}{SF} = $sharefiles, $dc->{sharesize} = $sharesize, if $sharesize;
            #todo! change INF cmd or myinfo
          }
        );
      }
    ) if $config{filelist_scan};
    #$config{filelist_scan}
    #or !-e $config{files} or !-e $config{files}.'.bz2';
  },
  %{ $config{dc} || {} },
  );
#$dc->work(10);
#$dc->get( $_, 'files.xml.bz2', $_ . '.xml.bz2' ), $dc->work() for grep $_ ne $dc->{'Nick'}, keys %{ $dc->{'NickList'} };
#while ( $dc->active() ) {  $dc->work(); }
$dc->destroy();
sleep(1);
