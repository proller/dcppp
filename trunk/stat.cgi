#!/usr/bin/perl
# $Id: flood.pl 292 2008-12-07 03:09:42Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/flood.pl $
use strict;
eval { use Time::HiRes qw(time sleep); };
#use lib './lib';
#use dcppp::clihub;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
#use DBI;
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
print "Content-type: text/html\n\n";
#psmisc::config();
#$config{'log_all'} = 0;
do $root_path . 'stat.pl';
#print 'hi';


$config{'query_default'} = {'LIMIT' => 10,};

my %queries = (
  'top searches' => {
    'show' => [qw(cnt string tth time)],
    #'query' => 'SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1',
    'SELECT'   => '*, COUNT(*) as cnt',
    'FROM'     => 'queries',
#    'WHERE'    => '',
    'GROUP BY' => 'tth',
    'HAVING'   => 'cnt > 1',
    'ORDER BY'    => 'cnt',
  },
);
#print "<pre>";
#for my $days (  qw(1 7 30 365) ) {
for my $days (  qw(1 ) ) {
my $period =  $days * 86400 ;
  for ( keys %queries ) {
    my $q   = {%{$queries{$_}}};
push @{$q->{'WHERE'}} , "time >= ".(int((time-$period)/1000)*1000); #!!! TODO Cut by hour? or 1000 sec
$q->{'WHERE'}=join 'AND', @{$q->{'WHERE'}} if ref $q->{'WHERE'} eq 'ARRAY';
    my $sql = join ' ',
      map { my $key = ( $q->{$_} || $config{query_default}{$_} ); length $key ? ( $_ . ' ' . $key ) : '' }
      qw(SELECT FROM WHERE ), 'GROUP BY', qw(HAVING) , 'ORDER BY', qw(LIMIT);
    print "[$sql]<br/>\n";
    my $res = $db->query($sql);

print "<hr/>$days days<table>";

print '<th>', $_, '</th>' for @{$q->{'show'}};

for my $row (@$res) {
print '<tr>';


$row->{'time'} = psmisc::human('time_period', time-$row->{'time'}) if int $row->{'time'};
print '<td>', $row->{$_}, '</td>' for @{$q->{'show'}};

print '</tr>';

}
print '</table>';
#    print Dumper $res;

psmisc::flush();
  }
}

=z
    my $limit = 'LIMIT 10';
    my $where = '';           #'WHERE time >' . ( int( time - 3600 ) );
    $db->query_log(qq{SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1 ORDER BY  cnt DESC $limit});
    $db->query_log(qq{SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY string HAVING cnt > 1 ORDER BY  cnt DESC $limit});
    $db->query_log(qq{SELECT *, COUNT(*) as cnt FROM results $where GROUP BY tth HAVING cnt > 1 ORDER BY  cnt DESC $limit});
    $db->query_log(qq{SELECT *, COUNT(*) as cnt FROM results $where GROUP BY string HAVING cnt > 1 ORDER BY  cnt DESC $limit});
    $db->query_log(qq{SELECT COUNT(*) FROM $_}) for keys %{ $config{'sql'}{'table'} };
=cut
