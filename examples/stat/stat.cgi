#!/usr/bin/perl
# $Id$ $URL$

=todo

users-share per hub -per hour
chat stats

main page: only by 10 res , make pages for every req by 100

stats:
fast slow slowbytime


=cut

use strict;
eval { use Time::HiRes qw(time sleep); };
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
our ( %config, $db );
our $root_path;

BEGIN {
  ( $ENV{'SCRIPT_FILENAME'} || $0 ) =~ m|^(.+)[/\\].+?$|;    #v0w
  $root_path = $1 . '/' if $1;
  $root_path =~ s|\\|/|g;
  eval "use lib '$root_path'" if $root_path;
  eval "use lib '$root_path./pslib'; use psmisc; use pssql; use psweb;";
  print( "Content-type: text/html\n\n", " lib load error rp=$root_path o=$0 sf=$ENV{'SCRIPT_FILENAME'}; ", $@ ), exit if $@;
}
#use lib qw(./pslib ./../pslib ./../../pslib);
#use pssql;
#use psmisc;
#use psweb;
my $param = get_params();
print "Content-type: text/html; charset=utf-8\n\n" if $ENV{'SERVER_PORT'};
print '<html><head><title>RU DC stat</title><style>
.tth {font-family:monospace, "Courier New";font-size:4px;} 
.magnet-darr {font: bolder larger; text-decoration:none; color:green;}
</style></head><body><script type="text/javascript" src="pslib/lib.js"></script>';
#print "[$root_path]";
#psmisc::config();
#$config{'log_all'} = 0;
our %queries;
do $root_path . 'stat.pl';
#print 'hi';
$config{'log_all'} = '0' unless $param->{'debug'};
$config{'log_default'} = '#';
#$config{'log_trace'} = $config{'log_dmpbef'} = 0;
$config{'log_dmp'} = $config{'log_dbg'} = 1, $db->{'explain'} = 1,
  if $param->{'debug'};
$config{'view'} = 'html';
$db->retry_off();
$db->set_names();
#$config{'query_default'} = { 'LIMIT' => psmisc::check_int( $param->{'on_page'}, 10, 100, 10 ), };
$config{'query_default'}{'LIMIT'} = psmisc::check_int( $param->{'on_page'}, 10, 100, 10 );
print '<a href="?">home</a>';
print ' days ', (
  map {
    qq{<a href="#" onclick="createCookie('time', '$_');window.location.reload(false);">}
      . psmisc::human( 'time_period', $config{'periods'}{$_} ) . '</a> '
    } sort {
    $config{'periods'}{$a} <=> $config{'periods'}{$b}
    } keys %{ $config{'periods'} }
    #3600, map {$_ * 86400}qw(1 7 30 366)
) unless grep { $param->{$_} } qw(string tth);
print ' limit ',
  ( map { qq{<a href="#" onclick="createCookie('on_page', '$_');window.location.reload(false);">$_</a> } } qw(10 20 50 100) ),
  '<br/>';
#);
#print "<pre>";
#for my $days (  qw(1 7 30 365) ) {
#for my $days (  qw(1 ) ) {
#my $days =
#$param->{'time'} = psmisc::check_int($config{'periods'}{$param->{'time'}},3600,10*86400*365,7*86400);
#int( $param->{'time'} ) || 7*86400;
#my $period = ;
#!$param->{'time'} =  ( int( ( time - $days * 86400 ) / 1000 ) * 1000 );
$config{'human'}{'magnet-dl'} = sub {
  my ($row) = @_;
  $row = { 'tth' => $row } unless ref $row eq 'HASH';
  my $tth = ( $row->{'tth_orig'} || $row->{'tth'} );
  #print length $row->{'tth'}, "[$row->{'tth'}]";
  my $string = $row->{'string_orig'} || $row->{'string'};
  $string ||= $tth, $tth = undef,
    unless
    #length $row->{'tth'} == 39 and $row->{'tth'} =~ /^[0-9A-Z]+$/;
    $tth =~ /^[0-9A-Z]{39}$/;
  local $_ = join '&', grep { $_ } ( $tth ? 'xt=urn:tree:tiger:' . $tth : '' ),
    ( $row->{'size'} ? 'xl=' . $row->{'size'} : '' ),
    ( $row->{'filename'} ? 'dn=' . psmisc::encode_url( $row->{'filename'} ) : '' ),
    ( $string ? 'kt=' . psmisc::encode_url($string) : '' ), ( $row->{'hub'} ? 'xs=dchub://' . $row->{'hub'} : '' );
  return '&nbsp;<a class="magnet-darr" href="magnet:?' . $_ . '">&darr;</a>' if $_;
  return '';
};
print '<a>', $param->{'tth'}, '</a>', psmisc::human( 'magnet-dl', $param->{'tth'} ), '<br/>' if $param->{'tth'};
my @ask;
@ask = ('string') if $param->{'string'};
@ask = ('tth')    if $param->{'tth'};
#print Dumper @ask;
for ( @ask ? @ask : sort { $queries{$a}{'order'} <=> $queries{$b}{'order'} } grep { $queries{$_}{'main'} } keys %queries ) {
  #print "for $_;";
  my $q = { %{ $queries{$_} } };
  print "$_ ($q->{'desc'}):<br\n/>";
  #push @{$q->{'WHERE'}} , "time >= ".(int((time-$period)/1000)*1000); #!!! TODO Cut by hour? or 1000 sec
  my $res = make_query( $q, $_, $param->{'time'} );
  print psmisc::human( 'time_period', time - $param->{'time'} ) . "<table>";
  print '<th>', $_, '</th>' for 'n', @{ $q->{'show'} };
  my $n;
  for my $row (@$res) {
    print '<tr><td>', ++$n, '</td>';
    #    $row->{'tth_magnet'} = psmisc::human('tth-dl', $row )      if $row->{'tth'};
    $row->{'tth_orig'}    = $row->{'tth'};
    $row->{'string_orig'} = $row->{'string'};
    $row->{$_}            = (
      $param->{$_}
      ? ''
      : qq{<a class="$_" title="}
        . psmisc::html_chars( $row->{$_} )
        . qq{" href="?$_=}
        . psmisc::encode_url( $row->{$_} )
        . qq{">$row->{$_}</a>}
      )
      . psmisc::human( 'magnet-dl', $row )
      for grep { length $row->{$_} } qw(string tth);   #($param->{'string'} ? () : 'string' ), ($param->{'tth'} ? () : 'tth' );
                                                       #    $row->{'tth'} .= psmisc::human('magnet-dl', $row ) if $row->{'tth'};
    $row->{'time'} = psmisc::human( 'time_period', time - $row->{'time'} ) if int $row->{'time'};
    $row->{'size'} = psmisc::human( 'size',        $row->{'size'} )        if int $row->{'size'};
    print '<td>', $row->{$_}, '</td>' for @{ $q->{'show'} };
    print '</tr>';
  }
  print '</table><hr/>';
  #      print Dumper $res;
  psmisc::flush();
}
print '</body></html>';
#}
#print "<pre>";
#print Dumper $param;
#print Dumper \%ENV;
