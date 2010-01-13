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
eval { use Time::HiRes qw(time sleep); };
use lib '../lib';
#use Net::DirectConnect::clihub;
#use Net::DirectConnect::adc;
use Net::DirectConnect;
use lib '../lib';
use lib './stat/pslib';
our %config;
use psmisc;
psmisc::config();
my $filelist = 'C:\Program Files\ApexDC++\Settings\HashIndex.xml';
my %tth = ( 'files.xml.bz2' => 'C:\Program Files\ApexDC++\Settings\files.xml.bz2' );    # = (tthash=>'/path', ...);
my $cantth;
eval q{ use Net::DirectConnect::TigerHash qw(tthfile); ++$cantth; };
print $@ if $@;
#if ($cantth) {
for my $dir ( @{ $config{'share'} || [] } ) {
  print("sorry, cant load Net::DirectConnect::TigerHash for hashing\n"), last, unless ($cantth);
  print "scanning [$dir]\n";
  opendir( my $dh, $dir ) or print("can't opendir $dir: $!"), next;
  #@dots =
  for my $file ( readdir($dh) ) {
    next if $file =~ /^\.\.?/;
    my $full = "$dir/$file";
    print 'd: ' if -d $full;
    #'res=',
    #join "\n",     grep { !/^\.\.?/ and
    #/^\./ &&     -f "$dir/$_"     }
    print " ", $full;
    #print "\n";
    #my $tth;
    my $tth = tthfile($full);    #if -f $full;
    $tth{$tth} = $file if $tth;
    #print ' ', tthfile($full) if -f $full ; #and -s $full < 1_000_000;
    print ' ', $tth;
    print ' ', -s $full if -f $full;
    print "\n";
  }
  closedir $dh;
  #}
}
print("usage: $1 [adc|dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];
if ( open my $f, '<', $filelist ) {
  print "loading filelist..";
  local $/ = '<';
  while (<$f>) {
    if ( my ( $file, $time, $tiger ) = /^File Name="([^"]+)" TimeStamp="(\d+)" Root="([^"]+)"/i ) {
      #$self->{'share_tth'}{ $params->{TR} }
      $file =~ tr{\\}{/};
      $tth{$tiger} = $file;
    }
    #<File Name="c:\distr\neo\tmp" TimeStamp="1242907656" Root="3OPSFH2JD2UPBV4KIZAPLMP65DSTMNZRTJCYR4A"/>
  }
  close $f;
  print ".done:", ( scalar keys %tth ), "\n";
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
  'sharesize' => int( rand 10000000000 ) + int( rand 10000000000 ) * int( rand 100 ),
  #'log'		=>	sub {},	# no logging
  #'client'      => '++',
  #'V'           => '0.698',
  #'description' => '',
  #'M'           => 'P',
  'share_tth' => \%tth,
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
