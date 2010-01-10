#!/usr/bin/perl
#$Id$ $URL$
package statcgi;
use strict;
eval { use Time::HiRes qw(time sleep); };
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
our ( %config, $param, $db, );
our $root_path;
our @colors =
  qw(aqua 		gray		navy		silver	 black		green		olive		teal	 blue		lime		purple		 magenta		maroon		red		yellow	  	);    #white

BEGIN {
  ( $ENV{'SCRIPT_FILENAME'} || $0 ) =~ m|^(.+)[/\\].+?$|;                                                             #v0w
  $root_path = $1 . '/' if $1;
  $root_path =~ s|\\|/|g;
  eval "use lib '$root_path'" if $root_path;
  eval "use lib '$root_path./pslib'; use psmisc; use pssql;";    # use psweb;
  print( "Content-type: text/html\n\n", " lib load error rp=$root_path o=$0 sf=$ENV{'SCRIPT_FILENAME'}; ", $@ ), exit if $@;
}
$param = get_params();
use statlib;
print "Content-type: text/xml; charset=utf-8\n\n" if $ENV{'SERVER_PORT'};
print '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:svg="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
<head><title>RU DC stat</title>
<link href="style.css" rel="stylesheet" type="text/css"/>
<style></style></head><body><script type="text/javascript" src="pslib/lib.js"></script>';
#print '    <svg:svg version="1.1" baseProfile="full" width="300px" height="200px">      <svg:circle cx="150px" cy="100px" r="50px" fill="#ff0000" stroke="#000000" stroke-width="5px"/>    </svg:svg>';
$config{'log_all'}     = '0' unless $param->{'debug'};
$config{'log_default'} = '#';
$config{'log_dmp'}     = $config{'log_dbg'} = 1,
  #$db->{'explain'} = 1,
  if $param->{'debug'};
$config{'view'} = 'html';
$config{'lang'} = 'ru';
$db->retry_off();
$db->set_names();
$config{'query_default'}{'LIMIT'} = psmisc::check_int( $param->{'on_page'}, 10, 100, 10 );
$param->{'period'} ||= $config{'default_period'};
print '<a href="?">home</a>';
print ' days ', (
  map {
    '<a '
      . ( $param->{'period'} eq $_ ? '' : 'href="#"' )
      . qq{ onclick="createCookie('period', '$_');window.location.reload(false);">}
      . psmisc::human( 'time_period', $config{'periods'}{$_} ) . '</a> '
    } sort {
    $config{'periods'}{$a} <=> $config{'periods'}{$b}
    } keys %{ $config{'periods'} }
  )
  unless (
  grep {
    $param->{$_}
  } qw(string tth)
  ) or ( $param->{'query'} and !$config{'queries'}{ $param->{'query'} }{'periods'} );
print '<br/>';
print
qq{<div class="main-top-info">Для скачивания файлов по ссылке <a class="magnet-darr">[&dArr;]</a> необходим dc клиент, например <a href="http://www.apexdc.net/download/">apexdc</a>.</div>};
$config{'human'}{'magnet-dl'} = sub {
  my ($row) = @_;
  $row = { 'tth' => $row } unless ref $row eq 'HASH';
  my $tth = ( $row->{'tth_orig'} || $row->{'tth'} );
  my $string = $row->{'string_orig'} || $row->{'string'};
  $string ||= $tth, $tth = undef, unless $tth =~ /^[0-9A-Z]{39}$/;
  local $_ = join '&amp;', grep { $_ } ( $tth ? 'xt=urn:tree:tiger:' . $tth : '' ),
    ( $row->{'size'} ? 'xl=' . $row->{'size'} : '' ),
    ( $row->{'filename'} ? 'dn=' . psmisc::encode_url( $row->{'filename'} ) : '' ),
    ( $string ? 'kt=' . psmisc::encode_url($string) : '' ), ( $row->{'hub'} ? 'xs=dchub://' . $row->{'hub'} : '' );
  return '&nbsp;<a class="magnet-darr" href="magnet:?' . $_ . '">[&dArr;]</a>' if $_;
  return '';
};
$config{'human'}{'dchub-dl'} = sub {
  my ($row) = @_;
  $row = { 'hub' => $row } unless ref $row eq 'HASH';
  #print "[$row->{'hub'}; $row->{'nick'}]";
  return
      '&nbsp;<a class="magnet-darr" href="dchub://'
    . ( join '/', grep { $_ } map { $row->{$_} } qw(hub nick) )
    . '">[&dArr;]</a>'
    if length $row->{'hub'};
};
print '<a>', psmisc::html_chars( $param->{'tth'} ), '</a>', psmisc::human( 'magnet-dl', $param->{'tth'} ), '<br/>'
  if $param->{'tth'};
my @ask;
$config{'queries'}{'string'}{'desc'} = psmisc::html_chars( $param->{'string'} ), @ask = ('string') if $param->{'string'};
@ask = ('tth')      if $param->{'tth'};
@ask = ('filename') if $param->{'filename'};
@ask = ( $param->{'query'} ) if $param->{'query'} and $config{'queries'}{ $param->{'query'} };
$config{'query_default'}{'LIMIT'} = 100 if scalar @ask == 1;
my %makegraph;
my %graphcolors;

for my $query ( @ask ? @ask : sort { $config{'queries'}{$a}{'order'} <=> $config{'queries'}{$b}{'order'} }
  grep { $config{'queries'}{$_}{'main'} } keys %{ $config{'queries'} } )
{
  my $q = { %{ $config{'queries'}{$query} || next } };
  next if $q->{'disabled'};
  $q->{'desc'} = $q->{'desc'}->{ $config{'lang'} } if ref $q->{'desc'} eq 'HASH';
  print '<div class="onetable ' . $q->{'class'} . '">',
    $q->{'no_query_link'}
    ? $query
    : '<a href="?query=' . ( psmisc::encode_url($query) ) . '">' . ( $q->{'desc'} || $query ) . '</a>';
  #print " ($q->{'desc'}):" if $q->{'desc'};
  print "<br\n/>";
  my $res = statlib::make_query( $q, $query, $param->{'period'} );
  print psmisc::human( 'time_period', time - $param->{'time'} ) . "<table>";
  print '<th>', $query, '</th>' for 'n', @{ $q->{'show'} };
  my $n;

  for my $row (@$res) {
    print '<tr><td>', ++$n, '</td>';
    $row->{$_} = psmisc::html_chars( $row->{$_} ) for @{ $q->{'show'} };
    $row->{'orig'} = {%$row};
    #$row->{'tth_orig'}    = $row->{'tth'};
    #$row->{'string_orig'} = $row->{'string'};
my $graphcolor;
        if ( $q->{'graph'} ) {
      my $by = $q->{'GROUP BY'};
      #print "m=$main ";
      $by =~ s/.*\.//;
      #print "M==$main ";
      my ($v) = map { $row->{'orig'}{$_} } grep { $by eq $_ } @{ $q->{'show'} };
      $makegraph{$query}{$v} = $by;
      $graphcolor = $graphcolors{$v} = $colors [$n-1];
      #my $id = $query;
      #$id =~ tr/ /_/;
}

    $row->{$_} =
      ( $param->{$_}
      ? ''
      : qq{<a class="$_" title="}
        . psmisc::html_chars( $row->{$_} )
        . qq{" href="?$_=}
        . psmisc::encode_url( $row->{$_} )
        . qq{">$row->{$_}</a>} )
      . psmisc::human( 'magnet-dl', $row->{'orig'} )
      for grep { length $row->{$_} and !$q->{ 'no_' . $_ . '_link' } }
      grep { $config{'queries'}{$_} } @{ $q->{'show'} };    #qw(string tth);
    $row->{'hub'} .= psmisc::human( 'dchub-dl', { 'hub' => $row->{'orig'}->{'hub'} } ) if $row->{'hub'};
    #$row->{'nick'} .= psmisc::human( 'dchub-dl', $row->{'orig'} ) if $row->{'nick'};
    $row->{$_} = psmisc::human( 'time_period', time - $row->{$_} ) for grep { int $row->{$_} } qw(time online);
    $row->{$_} = psmisc::human( 'size',        $row->{$_} )        for grep { int $row->{$_} } qw(size share);
    print '<td>', $row->{$_}, '</td>' for @{ $q->{'show'} };
    print qq{<td style="background-color:$graphcolor">&nbsp;</td>};
        if ( $q->{'graph'} ) {
      print qq{<td class='graph' id='$query' rowspan='100'></td>} if $n == 1;
    }
    print '</tr>';
  }
  print '</table></div>';
  print '<br/>' if $q->{'group_end'};
  psmisc::flush();
}
#print Dumper \%makegraph;
my $graphtime = time;
for my $query ( sort keys %makegraph ) {
  my $q = { %{ $config{'queries'}{$query} || next } };
  my $table = $query;
  my %graph;
  my %dates;
  $table =~ s/\s/_/g;
  $table .= '_daily';
  for my $row ( $db->query("SELECT * FROM $table") ) {
    #print $row;
    my $by = $makegraph{$query}{ $row->{tth} } || $makegraph{$query}{ $row->{string} };
#print " $row->{date}, $row->{n}, $row->{cnt} <br/>" if $makegraph{$query}{$row->{tth}} eq 'tth' or $makegraph{$query}{$row->{string}} eq 'string';
    ++$dates{ $row->{date} };
    $graph
      #{$query}
      { $row->{$by} }{ $row->{date} } = $row->{n};
  }
  #my $id  = $query;
  #$id =~ tr/ /_/;
  my $xl = 1000;
  my $yl = 600;
  my $xs = $xl / ( scalar keys(%dates) - 1 or 1 );
  my $ys = 10;
  print qq{<script type="text/javascript" language="JavaScript"><![CDATA[}, qq{
      
      gid('$query').innerHTML='  <svg:svg version="1.1" baseProfile="full" xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0 0 $xl $yl">},
#qq{<svg:circle cx="150px" cy="100px" r="50px" fill="#ff0000" stroke="#000000" stroke-width="5px"/>},
#qq{<g fill="none" stroke="red" stroke-width="3">},
#qq{<path d="M100,100 Q200,400,300,100"/>},
#qq{ <rect x="1" y="1" width="1198" height="398"         fill="none" stroke="blue" stroke-width="2" />},
#qq{ <polyline fill="none" stroke="blue" stroke-width="10"              points="50,375                     150,375 150,325 250,325 250,375                     350,375 350,250 450,250 450,375                     550,375 550,175 650,175 650,375                     750,375 750,100 850,100 850,375                     950,375 950,25 1050,25 1050,375                     1150,375" />},
    ;
  my $color = 0;
  for my $line ( keys %graph ) {
    my $n;
    #$colors[$color]
    print qq{ <polyline fill="none" stroke="$graphcolors{$line}" stroke-width="3" points="},
      ( join ' ', map { ( $n++ * $xs ) . ',' . ( $yl - $graph{$line}{$_} ) } sort keys %dates ), qq{" />};
       ++$color;
  }
  print
    #qq{</g>},
    qq{</svg:svg>';}, "]]></script>";
  printlog 'dev', Dumper \%graph, \%dates;
}
printlog 'dev', '<div>graph per ', psmisc::human( 'time_period', time - $graphtime ), '</div>';
print
qq{<div class="version"><a href="http://svn.setun.net/dcppp/trac.cgi/browser/trunk/examples/stat">dcstat</a> from <a href="http://search.cpan.org/dist/Net-DirectConnect/">Net::DirectConnect</a> vr}
  . ( split( ' ', '$Revision$' ) )[1]
  . qq{</div>};
print '<script type="text/javascript" src="http://iekill.proisk.ru/iekill.js"></script>';
print '</body></html>';
#print "<pre>";
#print Dumper $param;
#print Dumper \%ENV;
