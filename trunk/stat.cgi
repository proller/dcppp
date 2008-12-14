#!/usr/bin/perl
# $Id: flood.pl 292 2008-12-07 03:09:42Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/flood.pl $
=todo
    # periods: 1h 1d 7d 30d 1y
    # stats: top file, top query,
    #
    #





=cut

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
my $param = get_params();
print "Content-type: text/html\n\n";
#print "[$root_path]";
#psmisc::config();
#$config{'log_all'} = 0;
do $root_path . 'stat.pl';
#print 'hi';

#$config{'log_all'} = '#';
#$config{'log_default'} = '#';
#$config{'log_trace'} = $config{'log_dmpbef'} = 0;
#$config{'log_dmp'} = 1;
$config{'view'} = 'html';


$db->set_names();
$config{'query_default'} = { 'LIMIT' => 10, };
my %queries;
$queries{'queries top tth'} = {
'main' => 1,
'desc' => 'Most downloaded',
  'show'     => [qw(cnt tth)],          #time
                                        #'query' => 'SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1',
  'SELECT'   => '*, COUNT(*) as cnt',
  'FROM'     => 'queries',
  'WHERE'    => ['tth != ""'],
  'GROUP BY' => 'tth',
  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
};
$queries{'queries top string'} = {
  %{ $queries{'queries top tth'} },
  'show'     => [qw(cnt string)],       #time
'desc' => 'Most searched',

  'GROUP BY' => 'string',
  'WHERE'    => ['string != ""'],
};
$queries{'results top tth'} = {
  %{ $queries{'queries top tth'} },
  'show' => [qw(cnt string tth filename size )],    #time
  'desc' => 'Most stored',
  'FROM' => 'results',
'WHERE'    => ['tth != ""'],
};
#$queries{'results top string'} = {
#  %{ $queries{'queries top string'} },
#  'show' => [qw(cnt string tth filename size )],    #time
#  'FROM' => 'results',
#};

$queries{'string'} = {

  'show'     => [qw(cnt tth filename size)],          #time
                                        #'query' => 'SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1',
  'SELECT'   => '*, COUNT(*) as cnt',
#  'FROM'     => 'queries',
  'WHERE'    => ['tth != ""'],
  'GROUP BY' => 'tth',
#  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',


#  %{ $queries{'queries top string'} },
#  'show' => [qw(cnt string filename size )],    #time
  'FROM' => 'results',
};

$queries{'tth'} = {
%{$queries{'string'}},
  'show'     => [qw(cnt string filename size)],          #time
#'WHERE'    => ['tth != ""'],

  'GROUP BY' => 'filename',

};


print '<a href="?">home</a> days ', ( map { qq{<a href="?days=$_">$_</a> } } qw(1 7 30 365) ), '<br/>';
#);
#print "<pre>";
#for my $days (  qw(1 7 30 365) ) {
#for my $days (  qw(1 ) ) {
my $days = int( $param->{'days'} ) || 7;
#my $period = ;
#!$param->{'time'} =  ( int( ( time - $days * 86400 ) / 1000 ) * 1000 );

my @ask; 

@ask = ('string') if $param->{'string'};
@ask = ('tth') if $param->{'tth'};

#print Dumper @ask;

for (@ask ? @ask : sort grep{$queries{$_}{'main'}}keys %queries ) {
#print "for $_;";
  my $q = { %{ $queries{$_} } };
  print "$_ ($q->{'desc'}):<br\n/>";
  #push @{$q->{'WHERE'}} , "time >= ".(int((time-$period)/1000)*1000); #!!! TODO Cut by hour? or 1000 sec
  $q->{'WHERE'} = join ' AND ', grep{$_}@{ $q->{'WHERE'}, } if ref $q->{'WHERE'} eq 'ARRAY';
  $q->{'WHERE'} = join ' AND ', grep{$_}$q->{'WHERE'}, ($param->{'time'} ? "time >= " . $param->{'time'} : '') ,
    map { "$_=" . $db->quote( $param->{$_} ) } grep { length $param->{$_} } qw(string tth);
  my $sql = join ' ',
    map { my $key = ( $q->{$_} || $config{query_default}{$_} ); length $key ? ( $_ . ' ' . $key ) : '' } qw(SELECT FROM WHERE),
    'GROUP BY', 'HAVING', 'ORDER BY', 'LIMIT';
#  print "[$sql]<br/>\n";
  my $res = $db->query($sql);
  print psmisc::human( 'time_period', time - $param->{'time'}). "<table>";
  print '<th>', $_, '</th>' for 'n', @{ $q->{'show'} };

my $n;
  for my $row (@$res) {
    print '<tr><td>', ++$n, '</td>';

    $row->{'time'} = psmisc::human( 'time_period', time - $row->{'time'} ) if int $row->{'time'};
    $row->{'size'} = psmisc::human( 'size',        $row->{'size'} )        if int $row->{'size'};
    $row->{$_} = qq{<a href="?$_=} . psmisc::encode_url( $row->{$_} ) . qq{">$row->{$_}</a>}
      for grep { length $row->{$_} } qw(string tth );

#magnet:?xt=urn:tree:tiger:LYCXEVB43DNEM5KNOYC2PV27VDLHZRGRPWBMYZY&xl=33995128&dn=%D0%9B%D0%B8%D0%BD%D0%B8%D1%8F+%D0%BE%D1%81%D1%82%D0%B0%D0%B2%D0%B0%D0%B9%D1%81%D1%8F+[mtv]_[divx]+(dvr).avi

    print '<td>', $row->{$_}, '</td>' for @{ $q->{'show'} };
    print '</tr>';
  }
  print '</table><hr/>';
#      print Dumper $res;
  psmisc::flush();
}
#}

=z
    my $limit = 'LIMIT 10';
    my $where = '';           #'WHERE time >' . ( int( time - 3600 ) );
    $db->query_log(qq{SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1 ORDER BY  cnt DESC $limit});
    $db->query_log(qq{SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY string HAVING cnt > 1 ORDER BY  cnt DESC $limit});
    $db->query_log(qq{SELECT *, COUNT(*) as cnt FROM results $where GROUP BY tth HAVING cnt > 1 ORDER BY  cnt DESC $limit});
    $db->query_log(qq{SELECT *, COUNT(*) as cnt FROM results $where GROUP BY string HAVING cnt > 1 ORDER BY  cnt DESC $limit});
    $db->query_log(qq{SELECT COUNT(*) FROM $_}) for keys %{ $config{'sql'}{'table'} };
=cut
#print Dumper $param;
