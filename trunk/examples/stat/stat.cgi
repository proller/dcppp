#!/usr/bin/perl
# $Id$ $URL$
package statcgi;
use strict;
eval { use Time::HiRes qw(time sleep); };
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
our ( %config, $param, $db, );
our $root_path;

BEGIN {
  ( $ENV{'SCRIPT_FILENAME'} || $0 ) =~ m|^(.+)[/\\].+?$|;    #v0w
  $root_path = $1 . '/' if $1;
  $root_path =~ s|\\|/|g;
  eval "use lib '$root_path'" if $root_path;
  eval "use lib '$root_path./pslib'; use psmisc; use pssql;";    # use psweb;
  print( "Content-type: text/html\n\n", " lib load error rp=$root_path o=$0 sf=$ENV{'SCRIPT_FILENAME'}; ", $@ ), exit if $@;
}
$param = get_params();
use statlib;
print "Content-type: text/html; charset=utf-8\n\n" if $ENV{'SERVER_PORT'};
print '<html><head><title>RU DC stat</title><style>
.tth {font-family:monospace, "Courier New";font-size:4px;} 
.magnet-darr {font: bolder larger; text-decoration:none; color:green;}
.magnet-darr:hover { color:lightgreen; background-color:#696;}
.onetable { ZZborder:solid 1px gray; text-align:center; margin:10px; }
.half {   display:inline-block;}
.version {text-align:center; font-size:xx-small;}
tr:nth-child(2n+0) {background-color:GhostWhite;}
tr:nth-child(2n+1) {background-color:WhiteSmoke;}
tr {background-color:WhiteSmoke;}
tr:hover {background-color:Gainsboro;}
table {border:solid 1px Gainsboro; background-color:Gainsboro; margin:auto;}
.main-top-info {text-align:center; background-color:LightSalmon;}
</style></head><body><script type="text/javascript" src="pslib/lib.js"></script>';
$config{'log_all'}     = '0' unless $param->{'debug'};
$config{'log_default'} = '#';
$config{'log_dmp'}     = $config{'log_dbg'} = 1,
  #$db->{'explain'} = 1,
  if $param->{'debug'};
$config{'view'} = 'html';
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

print qq{<div class="main-top-info">Для скачивания файлов по ссылке <a class="magnet-darr">[&darr;]</a> необходим dc клиент, например <a href="http://www.apexdc.net/download/">apexdc</a>.</div>};


$config{'human'}{'magnet-dl'} = sub {
  my ($row) = @_;
  $row = { 'tth' => $row } unless ref $row eq 'HASH';
  my $tth = ( $row->{'tth_orig'} || $row->{'tth'} );
  my $string = $row->{'string_orig'} || $row->{'string'};
  $string ||= $tth, $tth = undef,
    unless $tth =~ /^[0-9A-Z]{39}$/;
  local $_ = join '&', grep { $_ } ( $tth ? 'xt=urn:tree:tiger:' . $tth : '' ),
    ( $row->{'size'} ? 'xl=' . $row->{'size'} : '' ),
    ( $row->{'filename'} ? 'dn=' . psmisc::encode_url( $row->{'filename'} ) : '' ),
    ( $string ? 'kt=' . psmisc::encode_url($string) : '' ), ( $row->{'hub'} ? 'xs=dchub://' . $row->{'hub'} : '' );
  return '&nbsp;<a class="magnet-darr" href="magnet:?' . $_ . '">[&darr;]</a>' if $_;
  return '';
};
$config{'human'}{'dchub-dl'} = sub {
  my ($row) = @_;
  $row = { 'hub' => $row } unless ref $row eq 'HASH';
#print "[$row->{'hub'}; $row->{'nick'}]";
  return '&nbsp;<a class="magnet-darr" href="dchub://' . (join '/', grep{$_}map {$row->{ $_ }}  qw(hub nick)) . '">[&darr;]</a>' if length $row->{'hub'};

};

print '<a>', psmisc::html_chars( $param->{'tth'} ), '</a>', psmisc::human( 'magnet-dl', $param->{'tth'} ), '<br/>'
  if $param->{'tth'};
my @ask;
$config{'queries'}{'string'}{'desc'} = psmisc::html_chars( $param->{'string'} ), @ask = ('string') if $param->{'string'};
@ask = ('tth') if $param->{'tth'};
@ask = ('filename') if $param->{'filename'};
@ask = ( $param->{'query'} )
  if $param->{'query'} and $config{'queries'}{ $param->{'query'} };
$config{'query_default'}{'LIMIT'} = 100 if scalar @ask == 1;
for (
  @ask ? @ask : sort { $config{'queries'}{$a}{'order'} <=> $config{'queries'}{$b}{'order'} }
  grep { $config{'queries'}{$_}{'main'} } keys %{ $config{'queries'} }
  )
{
  my $q = { %{ $config{'queries'}{$_} || next } };
  next if $q->{'disabled'};
  print '<div class="onetable ' . $q->{'class'} . '">', $q->{'no_query_link'}
    ? $_
    : qq{<a href="?query=} . psmisc::encode_url($_) . qq{">$_</a>};
  print " ($q->{'desc'}):" if $q->{'desc'};
  print "<br\n/>";
  my $res = statlib::make_query( $q, $_, $param->{'period'} );
  print psmisc::human( 'time_period', time - $param->{'time'} ) . "<table>";
  print '<th>', $_, '</th>' for 'n', @{ $q->{'show'} };
  my $n;

  for my $row (@$res) {
    print '<tr><td>', ++$n, '</td>';
    $row->{$_} = psmisc::html_chars( $row->{$_} ) for @{ $q->{'show'} };
    $row->{'orig'} = {%$row};
#    $row->{'tth_orig'}    = $row->{'tth'};
#    $row->{'string_orig'} = $row->{'string'};
    $row->{$_}            = (
      $param->{$_}
      ? ''
      : qq{<a class="$_" title="}
        . psmisc::html_chars( $row->{$_} )
        . qq{" href="?$_=}
        . psmisc::encode_url( $row->{$_} )
        . qq{">$row->{$_}</a>}
      )
      . psmisc::human( 'magnet-dl', $row->{'orig'} )
      for grep { length $row->{$_} and !$q->{ 'no_' . $_ . '_link' } } grep {$config{'queries'}{$_}}@{ $q->{'show'} };#qw(string tth);
$row->{'hub'} .= psmisc::human( 'dchub-dl', {'hub' => $row->{'orig'}->{'hub'}} ) if $row->{'hub'};
#$row->{'nick'} .= psmisc::human( 'dchub-dl', $row->{'orig'} ) if $row->{'nick'};
    $row->{'time'} = psmisc::human( 'time_period', time - $row->{'time'} ) if int $row->{'time'};
    $row->{'size'} = psmisc::human( 'size',        $row->{'size'} )        if int $row->{'size'};
    print '<td>', $row->{$_}, '</td>' for @{ $q->{'show'} };
    print '</tr>';
  }
  print '</table></div>';
  print '<br/>'
    if $q->{'group_end'};
  psmisc::flush();
}
print
qq{<div class="version"><a href="http://svn.setun.net/dcppp/trac.cgi/browser/trunk/examples/stat">dcstat</a> from <a href="http://search.cpan.org/dist/Net-DirectConnect/">Net::DirectConnect</a> vr}
  . ( split( ' ', '$Revision$' ) )[1]
  . qq{</div>};
print '<script type="text/javascript" src="http://iekill.proisk.ru/iekill.js"></script>';
print '</body></html>';
#print "<pre>";
#print Dumper $param;
#print Dumper \%ENV;
