#!/usr/bin/perl
#$Id$ $URL$

=readme

chat watch 

=cut

use strict;
eval { use Time::HiRes qw(time sleep); };
use lib '../lib';
#use Net::DirectConnect::clihub;
#use Net::DirectConnect::adc;
use Net::DirectConnect;
#use Net::DirectConnect::TigerHash qw(tthfile);
use lib '../lib';
use lib './stat/pslib';
use psmisc;
psmisc::config();
print("usage: flood.pl [dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];
my $filelist = 'C:\Program Files\ApexDC++\Settings\HashIndex.xml';
my %tth = ( 'files.xml.bz2' => 'C:\Program Files\ApexDC++\Settings\files.xml.bz2' );    # = (tthash=>'/path', ...);

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
      $dc->search('house');
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
