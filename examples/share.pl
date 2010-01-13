#!/usr/bin/perl
#$Id$ $URL$

=readme

todo:

scan 
 hash
make filelist


enable sharing : 
echo '$config{'share'} = [qw(C:\distr C:\pub\ )];' >> config.pl

=cut

use strict;
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
eval { use Time::HiRes qw(time sleep); };
use lib '../lib';
#use Net::DirectConnect::clihub;
#use Net::DirectConnect::adc;
use Net::DirectConnect;
use lib '../lib';
use lib './stat/pslib';
our ( %config, $db );
use psmisc;
use pssql;
$config{'sql'} ||= {
  'driver' => 'sqlite',
  'dbname' => 'files.sqlite',
  #'auto_connect'        => 1,
  'log' => sub { shift; psmisc::printlog(@_) },
  #'cp_in'               => 'cp1251',
  'connect_tries' => 0, 'connect_chain_tries' => 0, 'error_tries' => 0, 'error_chain_tries' => 0,
  #nav_all => 1,
  'table' => {
    'filelist' => {
      'path' => pssql::row( undef, 'type'        => 'VARCHAR', 'length' => 255, 'default' => '', 'index' => 1, 'primary' => 1 ),
      'file' => pssql::row( undef, 'type'        => 'VARCHAR', 'length' => 255, 'default' => '', 'index' => 1, 'primary' => 1 ),
      'tth'  => pssql::row( undef, 'type'        => 'VARCHAR', 'length' => 40,  'default' => '', 'index' => 1 ),
      'size' => pssql::row( undef, 'type'        => 'BIGINT',  'index'  => 1, ),
      'time' => pssql::row( 'time', ), #'index' => 1,
      #'added'  => pssql::row( 'added', ),
      'exists' => pssql::row( undef, 'type' => 'SMALLINT', 'index' => 1, ),
    },
  }
};
$config{filelist} ||= 'C:\Program Files\ApexDC++\Settings\HashIndex.xml';
$config{filetth} ||= { 'files.xml.bz2' => 'C:\Program Files\ApexDC++\Settings\files.xml.bz2' };    # = (tthash=>'/path', ...);
psmisc::config();
psmisc::lib_init();
$db ||= pssql->new( %{ $config{'sql'} || {} }, );
my ( $tq, $rq, $vq ) = $db->quotes();
#my $cantth;
eval q{ use Net::DirectConnect::TigerHash qw(tthfile);  };
print $@ if $@;
#if ($cantth) {
#print 'DUMp==',Dumper \%config;
#print Dumper  \%INC;
my $stopscan;
my $level = 0;
my $sharesize;

sub filelist_line ($) {
  my ($f) = @_;
  $sharesize += $f->{size};
}

sub scandir (@) {
  for my $dir (@_) {
    last if $stopscan;
    $dir =~ tr{\\}{/};
    $dir =~ s{/+$}{};
    opendir( my $dh, $dir ) or print("can't opendir $dir: $!"), next;
    #@dots =
    ++$level;
    for my $file ( readdir($dh) ) {
      last if $stopscan;
      next if $file =~ /^\.\.?/;
      my $f = { path => $dir, file => $file, };
      $f->{full} = "$dir/$file";
      print("d $f->{full}:\n"), $f->{dir} = -d $f->{full};
      filelist_line($f), scandir( $f->{full} ), next if $f->{dir};
      $f->{size} = -s $f->{full} if -f $f->{full};
      $f->{time} = int( $^T + 86400 * -M $f->{full} );    #time() -
      #'res=',
      #join "\n",     grep { !/^\.\.?/ and
      #/^\./ &&     -f "$dir/$_"     }
      print " ", $file;
      #todo - select not all cols
      my $indb =
        $db->line( "SELECT * FROM ${tq}filelist${tq} WHERE ${rq}size${rq}="
          . $db->quote( $f->{size} )
          . " AND ${rq}path${rq}="
          . $db->quote( $f->{path} )
          . " AND ${rq}file${rq}="
          . $db->quote( $f->{file} )
          . " LIMIT 1" );
      #printlog ('already scaned', $indb->{size}),
      filelist_line($f), next, if $indb->{size} == $f->{size};
      #$db->select('filelist', {path=>$f->{path},file=>$f->{file}, });
      #printlog Dumper ;
      #print "\n";
      #my $tth;
      if ( $f->{size} > 100_000 ) {
        my $indb =
          $db->line( "SELECT * FROM ${tq}filelist${tq} WHERE ${rq}size${rq}="
            . $db->quote( $f->{size} )
            . " AND ${rq}file${rq}="
            . $db->quote( $f->{file} )
            . " LIMIT 1" );
        #printlog 'sel', Dumper $indb;
        if ( $indb->{tth} ) {
          $f->{$_} ||= $indb->{$_} for keys %$indb;
          #printlog "already summed", %$f;
          filelist_line($f);
          next;
        }
      }
      if ( !$f->{tth} ) {
        printlog 'calc', $f->{full};
        my $time = time();
        $f->{tth} = tthfile( $f->{full} );
        printlog 'time', psmisc::human( 'size', $f->{size} ), 'per', psmisc::human( 'time_period', time - $time ), 'speed ps',
          psmisc::human( 'size', $f->{size} / ( time - $time or 1 ) )
          if $f->{size};
      }
      #$f->{tth} = $f->{size} > 1_000_000 ? 'bigtth' : tthfile( $f->{full} );    #if -f $full;
      #print Dumper $config{filetth};
      #next;
      $config{filetth}{ $f->{tth} } = $f->{full} if $f->{tth};
      $config{filetth}{$file} ||= $f->{full};
      #print ' ', tthfile($full) if -f $full ; #and -s $full < 1_000_000;
      print ' ', $f->{tth};
      print ' ', $f->{size};    #if -f $f->{full};
      #print join ':',-M $f->{full}, $^T + 86400 * -M $f->{full},$f->{time};
      print "\n";
      filelist_line($f);
      $db->insert_hash( 'filelist', $f );
    }
    --$level;
    closedir $dh;
  }
}
#for my $dir ( @{ $config{'share'} || [] } ) {
unless ( $INC{"Net/DirectConnect/TigerHash.pm"} ) { print("sorry, cant load Net::DirectConnect::TigerHash for hashing\n"),; }
else {
  #print "scanning [$dir]\n";
  $SIG{INT} = sub { ++$stopscan; print "INT rec, stopscan\n" };
  scandir( @{ $config{'share'} || [] } );
  undef $SIG{INT};
  printlog 'sharesize', $sharesize;
}
#print Dumper \%config;
#}
#}
print("usage: $1 [adc|dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];
if ( open my $f, '<', $config{filelist} ) {
  print "loading filelist..";
  local $/ = '<';
  while (<$f>) {
    if ( my ( $file, $time, $tiger ) = /^File Name="([^"]+)" TimeStamp="(\d+)" Root="([^"]+)"/i ) {
      #$self->{'share_tth'}{ $params->{TR} }
      $file =~ tr{\\}{/};
      $config{filetth}{$tiger} = $file;
    }
    #<File Name="c:\distr\neo\tmp" TimeStamp="1242907656" Root="3OPSFH2JD2UPBV4KIZAPLMP65DSTMNZRTJCYR4A"/>
  }
  close $f;
  print ".done:", ( scalar keys %{ $config{filetth} } ), "\n";
}
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
  #'log'		=>	sub {},	# no logging
  #'client'      => '++',
  #'V'           => '0.698',
  #'description' => '',
  #'M'           => 'P',
  'share_tth' => $config{filetth},
  dev_http    => 1,
  'log'       => sub {
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
  );
$dc->work(10);
#$dc->get( $_, 'files.xml.bz2', $_ . '.xml.bz2' ), $dc->work() for grep $_ ne $dc->{'Nick'}, keys %{ $dc->{'NickList'} };
while ( $dc->active() ) {
  $dc->work();
  psmisc::schedule(
    [ 30, 10000 ],
    our $search_sub__ ||= sub {
      #print "Writing dump\n";
      #psmisc::file_rewrite( 'dump', Dumper $dc);
      #$dc->search('house');
    }
  );
  #}while ( $dc->active() ) {
  #$dc->work();
  psmisc::schedule(
    [ 20, 100 ],
    our $dump_sub__ ||= sub {
      print "Writing dump\n";
      psmisc::file_rewrite( 'dump', Dumper $dc);
    }
  );
}
$dc->destroy();
sleep(1);
