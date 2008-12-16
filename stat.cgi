#!/usr/bin/perl
# $Id$ $URL$

=todo

users-share per hub -per hour
chat stats

main page: only by 10 res , make pages for every req by 100



=cut
use strict;
eval { use Time::HiRes qw(time sleep); };
#use lib './lib';
#use Net::DC::clihub;
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
print "Content-type: text/html; charset=utf-8\n\n";
print
'<html><head><title>RU DC stat</title><style>.tth {font-family:monospace, "Courier New";font-size:4px;} .magnet-darr {font: bolder larger; text-decoration:none; color:green;}</style></head><body><script type="text/javascript" src="pslib/lib.js"></script>';
#print "[$root_path]";
#psmisc::config();
#$config{'log_all'} = 0;
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
$config{'query_default'} = { 'LIMIT' => psmisc::check_int( $param->{'on_page'}, 10, 100, 10 ), };
my %queries;
my $order;

$queries{'queries top string'} = {
  #  %{ $queries{'queries top tth'} },
  'main'   => 1,
  'show'   => [qw(cnt string)],                                                                  #time
  'desc'   => 'Most searched',
  'SELECT' => 'string, cnt',
  'FROM'   => 'queries' . ( $config{'periods'}{ $param->{'time'} } ? $param->{'time'} : 'd' ),
  #  'GROUP BY' => 'string',
  'WHERE'    => ['string != ""'],
  'ORDER BY' => 'cnt DESC',
'order' => ++$order,
};


$queries{'results top raw'} = {
  #  %{ $queries{'queries top tth raw'} },
#  'main'     => 1,
  'show'     => [qw(cnt string filename size tth)],                                              #time
  'desc'     => 'Most stored',
  'SELECT'   => '*, COUNT(*) as cnt',
  'FROM'     => 'results',
  'WHERE'    => ['tth != ""'],
  'GROUP BY' => 'tth',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
'order' => ++$order,
};

$queries{'results top'} = {
  #  %{ $queries{'queries top tth raw'} },
  'main'     => 1,
  'show'     => [qw(cnt string filename size tth)],                                              #time
  'desc'     => 'Most stored',
  'SELECT'   => '*',
  'FROM'     => 'resultsf',
  'WHERE'    => ['tth != ""'],
#  'GROUP BY' => 'tth',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
'order' => ++$order,
};


$queries{'queries top tth raw'} = {
  #  'main'     => 1,
  'desc'     => 'Most downloaded',
  'show'     => [qw(cnt tth)],          #time
                                        #'query' => 'SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1',
  'SELECT'   => 'tth, COUNT(*) as cnt',
  'FROM'     => 'queries',
  'WHERE'    => ['tth != ""'],
  'GROUP BY' => 'tth',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
'order' => ++$order,
};
$queries{'queries top string raw'} = {
  %{ $queries{'queries top tth raw'} },
  'show'     => [qw(cnt string)],            #time
  'desc'     => 'Most searched',
  'SELECT'   => 'string, COUNT(*) as cnt',
  'GROUP BY' => 'string',
  'WHERE'    => ['string != ""'],
'order' => ++$order,
};
my $queriesfast = 'queries' . ( $config{'periods'}{ $param->{'time'} } ? $param->{'time'} : 'd' );
$queries{'queries top tth'} = {
  'main' => 1,
  'desc' => 'Most downloaded',
  'show' => [qw(cnt string filename size tth )],    #time
       #'query' => 'SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1',
  'SELECT'    => '*',                               #cnt,filename,size,tth
  'FROM'      => $queriesfast,
  'LEFT JOIN' => 'results USING (tth)',
  'WHERE'     => [ $queriesfast . '.tth != ""' ],
  'GROUP BY'  => $queriesfast . '.tth',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
'order' => ++$order,
};
#



$queries{'queries string last'} = {
    'main'     => 1,
  'desc'     => 'last searches',
#  'show'     => [qw(time hub nick string filename size tth)],          #time
#  'SELECT'   => 'results.*,queries.*',
  'FROM'     => 'queries',
  'show'     => [qw(time hub nick string filename size tth)],          #time
  #'SELECT'   => 'queries.*, results.*',
#    'SELECT'   => 'results.*,queries.*',
    'SELECT'   => '*',
#    'SELECT'   => '*, (SELECT filename FROM results WHERE queries.string=results.string LIMIT 1) AS filename',

#no  'FROM'     => 'queries INNER JOIN results ON queries.string=results.string',
#  'FROM'     => 'queries NATURAL LEFT JOIN results ', #ON queries.string=results.string
#  'FROM'     => 'queries LEFT OUTER JOIN results ON queries.string=results.string', #ON queries.string=results.string
#  'LEFT JOIN' => 'results USING (string)',
  'WHERE'    => ['queries.string != ""'],
#  'GROUP BY' => 'queries.string',
  'ORDER BY' => 'queries.time DESC',
'order' => ++$order,
};


$queries{'queries tth last'} = {
%{$queries{'queries string last'}},
  'desc'     => 'last downloads',
#  'LEFT JOIN' => 'results USING (tth)',
#    'SELECT'   => '*, (SELECT string FROM results WHERE queries.tth=results.tth LIMIT 1) AS string',
#    'SELECT'   => '*, (SELECT * FROM results WHERE queries.tth=results.tth LIMIT 1) AS r',
#    'SELECT'   => ' (SELECT * FROM results WHERE queries.tth=results.tth LIMIT 1) AS r, *',
#    'SELECT'   => ' (SELECT string,size FROM results WHERE queries.tth=results.tth LIMIT 1) AS r, queries.*',
#    'SELECT'   => 'queries.* ,(SELECT string,size FROM results WHERE queries.tth=results.tth LIMIT 1) as r  ', # Operand should contain 1 column(s) 
#w    'SELECT'   => '*, (SELECT string FROM results WHERE queries.tth=results.tth LIMIT 1) AS string, (SELECT filename FROM results WHERE queries.tth=results.tth LIMIT 1) AS filename, (SELECT size FROM results WHERE queries.tth=results.tth LIMIT 1) AS size',
#w  'WHERE'    => ['tth != ""'],

#select q.*, r.* from queries as q join (select tth, string, filename, size from results limit 1) as r where q.tth = r.tth limit 10
#  'SELECT'   => 'q.*, r.*',
#  'FROM'     => 'queries as q',
#  'LEFT JOIN' => '(select tth, string, filename, size from results limit 1) as r ON (r.tth=q.tth)',
#  'WHERE'    => ['q.tth = r.tth','q.tth != ""'],
#  'ORDER BY' => 'q.time DESC',

#SELECT q.*, r.* FROM queries AS q, (SELECT string, filename, size FROM results LIMIT 1) AS r LIMIT 10
  'SELECT'   => 'q.*, r.*',
  'FROM'     => 'queries as q , (SELECT string, filename, size FROM results LIMIT 1) AS r',
  'WHERE'    => ['q.tth != ""'], #'q.tth = r.tth',
  'ORDER BY' => 'q.time DESC',


#  'ORDER BY' => 'queries.time DESC',
'order' => ++$order,
};



$queries{'results ext'} = {
  #  %{ $queries{'queries top tth raw'} },
  'main'     => 1,
  'show'     => [qw(cnt ext )],                                                                  #time
  'desc'     => 'by extention',
  'SELECT'   => '*, COUNT(*) as cnt',
  'FROM'     => 'results',
  'WHERE'    => ['ext != ""'],
  'GROUP BY' => 'ext',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
  'LIMIT'    => 10,
'order' => ++$order,
};


#$queries{'results top string'} = {
#  %{ $queries{'queries top string'} },
#  'show' => [qw(cnt string tth filename size )],    #time
#  'FROM' => 'results',
#};
$queries{'string'} = {
  'show' => [qw(cnt string  filename size tth)],    #time
       #'query' => 'SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1',
  'SELECT' => '*, COUNT(*) as cnt',
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
  %{ $queries{'string'} },
  'desc'     => 'various filenames',
  'show'     => [qw(cnt string filename size tth)],    #time
                                                       #'WHERE'    => ['tth != ""'],
  'GROUP BY' => 'filename',
};
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
  local $_ = join '&', grep { $_ } ( $tth ? 'xt=urn:tree:tiger:' . $tth : '' ), ( $row->{'size'} ? 'xl=' . $row->{'size'} : '' ),
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
for ( @ask ? @ask : sort {$queries{$a}{'order'} <=> $queries{$b}{'order'}} grep { $queries{$_}{'main'} } keys %queries ) {
  #print "for $_;";
  my $q = { %{ $queries{$_} } };
  print "$_ ($q->{'desc'}):<br\n/>";
  #push @{$q->{'WHERE'}} , "time >= ".(int((time-$period)/1000)*1000); #!!! TODO Cut by hour? or 1000 sec
  $q->{'WHERE'} = join ' AND ', grep { $_ } @{ $q->{'WHERE'}, } if ref $q->{'WHERE'} eq 'ARRAY';
  $q->{'WHERE'} = join ' AND ', grep { $_ } $q->{'WHERE'},
    #( $param->{'time'} ? "time >= " . int( (time - $param->{'time'})/1000)*1000 : '' ),
    map { "$_=" . $db->quote( $param->{$_} ) } grep { length $param->{$_} } qw(string tth);
  my $sql = join ' ',
    map { my $key = ( $q->{$_} || $config{query_default}{$_} ); length $key ? ( $_ . ' ' . $key ) : '' } 'SELECT', 'FROM',
    #'NATURAL LEFT JOIN',
    'LEFT JOIN',
    #    'STRAIGHT_JOIN',
    #    'LEFT OUTER JOIN',
    'USING', 'WHERE', 'GROUP BY', 'HAVING', 'ORDER BY', 'LIMIT';
  #  print "[$sql]<br/>\n";
  my $res = $db->query($sql);
  print psmisc::human( 'time_period', time - $param->{'time'} ) . "<table>";
  print '<th>', $_, '</th>' for 'n', @{ $q->{'show'} };
  my $n;
  for my $row (@$res) {
    print '<tr><td>', ++$n, '</td>';
    #    $row->{'tth_magnet'} = psmisc::human('tth-dl', $row )      if $row->{'tth'};
    $row->{'tth_orig'}    = $row->{'tth'};
    $row->{'string_orig'} = $row->{'string'};
    $row->{$_} =
      ( $param->{$_}
      ? ''
      : qq{<a class="$_" title="}
        . psmisc::html_chars( $row->{$_} )
        . qq{" href="?$_=}
        . psmisc::encode_url( $row->{$_} )
        . qq{">$row->{$_}</a>} )
      . psmisc::human( 'magnet-dl', $row )
      for grep { length $row->{$_} } qw(string tth);    #($param->{'string'} ? () : 'string' ), ($param->{'tth'} ? () : 'tth' );
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
print '</body>';
#}
#print Dumper $param;
