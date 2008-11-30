#!/usr/bin/perl
# $Id: watch.pl 280 2008-02-28 11:16:37Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/watch.pl $

=copyright
flood tests
Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proler@gmail.com icq#89088275

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA,
or download it from http://www.gnu.org/licenses/gpl.html
=cut

use strict;
eval { use Time::HiRes qw(time sleep); };
use lib './lib';
use dcppp::clihub;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
#use DBI;
our %config;

use lib qw(./pslib ./../pslib ./../../pslib);
use pssql;
use psmisc;


psmisc::config();

#$config{'log_all'}=1;
$config{'log_trace'}=$config{'log_dmpbef'}=0;
$config{'log_dmp'}=0;
#$config{'log_dcdev'}=1;
#$config{'log_dcdmp'}=1;


$config{'hit_to_ask'}||=2;


#print "Arg=",$ARGV[0],"\n";
$ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?$|;
#print "to=[$1]";

$config{'sql'} = {

'driver' => 'sqlite',
    'dbname' => 'stat.sqlite',
'auto_connect'=>1,
'table' => {'queries' => {
#111.111.111.111
      'time' => pssql::row( 'time'),
      'added' => pssql::row( 'added'),

      'hub' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>32,'Zindex'=>1  ),
      'nick' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>32,'Zindex'=>1  ),
      'ip' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>15,'Zindex'=>1  ),
      'port' => pssql::row( undef, 'type'=>'SMALLINT', 'Zindex'=>1  ),
      'tth' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>40,'Zindex'=>1  ),
      'string' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>255,'Zindex'=>1  ),

},
'results' => {
      'time' => pssql::row( 'time'),
      'added' => pssql::row( 'added'),

      'string' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>255,'Zindex'=>1  ),
      'hub' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>32,'Zindex'=>1  ),
      'nick' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>32,'Zindex'=>1  ),
      'ip' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>15,'Zindex'=>1  ),
      'port' => pssql::row( undef, 'type'=>'SMALLINT', 'Zindex'=>1  ),
      'tth' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>40,'Zindex'=>1  ),
      'file' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>255,'Zindex'=>1  ),
      'filename' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>255,'Zindex'=>1  ),
      'ext' => pssql::row( undef, 'type'=>'VARCHAR', 'length'=>32,'Zindex'=>1  ),
      'size' => pssql::row( undef, 'type'=>'BIGINT', 'Zindex'=>1  ),

},

}

};

=z
            'file' => 'MUSIC\\UNSORTED_MUSIC_FROM_UPLOAD\\Музыка от ГаГа\\МуЗика1\\G-Unit - 19 - Porno Star.mp3',
            'filename' => 'G-Unit - 19 - Porno Star.mp3',
            'ip' => '10.131.120.1',
            'nick' => 'ftp.wwwcom.ru',
            'port' => '411',
            'size' => '4980839',
            'tth' => 'OXYCI7EHF3JIHC47QSYQFVQVNHSWOE7N4KWWK7A'
=cut


our $db  = pssql->new(
  # 'driver' => 'pgpp',
  #  'dbname' => 'markers',
  #   'table'    => $config{'table'},
  # 'codepage' => $config{'cp_db'},
#   'log' => sub {     print join( ' ', @_ ), "\n";   },
   'log' => sub {shift; psmisc::printlog(@_)},
#'log' => sub{},
#   'log' => \psmisc::printlog ,
#sub {     &psmisc::printlog   },
  %{ $config{'sql'} or {} },
);

$db->install();
#my $dbh = DBI->connect("dbi:SQLite:dbname=stat.sqlite","","");
#print 'zz:',
#$db->do('CREATE TABLE IF NOT EXIST queries (varchar ())');
#$db->do

if ($ARGV[0] eq 'show') {

#print Dumper  
$db->query_log(q{SELECT *, COUNT(*) as cnt FROM queries  GROUP BY tth HAVING cnt > 1 ORDER BY  cnt DESC LIMIT 10});
$db->query_log(q{SELECT *, COUNT(*) as cnt FROM queries  GROUP BY string HAVING cnt > 1 ORDER BY  cnt DESC LIMIT 10});


$db->query_log(q{SELECT *, COUNT(*) as cnt FROM results  GROUP BY tth HAVING cnt > 1 ORDER BY  cnt DESC LIMIT 10});
$db->query_log(q{SELECT *, COUNT(*) as cnt FROM results  GROUP BY string HAVING cnt > 1 ORDER BY  cnt DESC LIMIT 10});




$db->query_log(qq{SELECT COUNT(*) FROM $_}) for keys %{$config{'sql'}{'table'}};


#WHERE cnt >= '1'

exit;
}


print("usage: stat.pl [dchub://]host[:port] [bot_nick]\n"), exit if !$ARGV[0];

#my $hubname=$1 . ($2 ? ':'.$2:'' );
our %work;
our %stat;
for ( 0 .. 1000 ) {
  #  print "i=$_ $1";
  my $dc = dcppp::clihub->new(
    'host' => $1,
    ( $2 ? ( 'port' => $2 ) : () ),
    'Nick' => ( $ARGV[1] or int( rand(100000000) ) ),
    #   'Nick'		=>	'xxxx',
    'sharesize' => int( rand 1000000000000 ) + int( rand 100000000000 ) * int( rand 100 ),
    #   'log'		=>	sub {},	# no logging
    #   'min_chat_delay'	=> 0.401,
    #   'min_cmd_delay'	=> 0.401,
    'client'      => '++',
    'V'           => '0.698',
    'description' => '',
    'M'           => 'P',
'print_search' => 1,
    'handler'     => {
#      'Search_parse_bef_bef' => sub {
      'Search_parse_aft' => sub {
        my $dc     = shift;
        my $search = shift;
#        print "Sh=", Dumper(\@_);
        my %s = (
'time' => int(time()),
'hub' => $dc->{'hub'},
%{$_[0]},
);
#        print "s:[$search]\n";
        #my ($who, $cmd)

#printlog('dcdev', "ignoring self search"),
return if $s{'nick'} eq  $dc->{'Nick'};

=z
        ( $s{'who'}, $s{'cmds'} ) = split /\s+/, $search;
        #my @cmd =
        $s{'cmd'} = [ split /\?/, $s{'cmds'} ];
        #my ($nick, $ip, $port);
        if ( $s{'who'} =~ /^Hub:(.+)$/i ) {
          $s{'nick'} = $1;
        } else {
          ( $s{'ip'}, $s{'port'} ) = split /:/, $s{'who'};
        }
        #my ($tth, string);
        if ( $s{'cmd'}[4] =~ /^TTH:(.*)$/i ) {
          $s{'tth'} = $1;
        } else {
          $s{'string'} = $s{'cmd'}[4];
          $s{'string'} =~ tr/$/ /;
        }
=cut
        #print "search[$nick, $ip, $port, ",join('|', @cmd),"]\n";
        for (qw(tth nick string ip)) {
          ++$stat{$_}{ $s{$_} } if $s{$_};
        }


$db->insert_hash('queries', \%s);

#and !$work{'askstth'}++
if ($s{'tth'} and ++$work{'ask_tth'}{$s{'tth'}} >= $config{'hit_to_ask'}) { 
printlog("try ask tth[$s{'tth'}]");
$dc->search_tth($s{'tth'});

} elsif ($s{'string'} and ++$work{'ask_string'}{$s{'string'}} >= $config{'hit_to_ask'}) {

printlog("try ask string [$s{'string'}]");
$dc->search_string($s{'string'});

}

#        print Dumper( \%stat );
        },

      'SR_parse_aft' => sub {
        my $dc     = shift;
#        my $search = shift;
my %s = %{$_[1] || return};
printlog('SR=', Dumper(\@_));


$db->insert_hash('results', \%s);






},

'chatline' => sub { my $dc = shift;
my ($nick, $text) = /^<([^>]+)> (.+)$/;

printlog('dev', "[$nick] oper, set interval = $1"), 
$dc->{'search_every'} = $1,
if ($dc->{'NickList'}->{$nick}{'oper'} and $text =~ /^Minimum search interval is:(\d+)s/) or
$nick eq 'Hub-Security' and $text =~ /Search ignored\.  Please leave at least (\d+) seconds between search attempts\./
;

#dcdmp [1] rcv: chatline <Hub-Security> Search ignored.  Please leave at least 5 seconds between search attempts.

# printlog( "[$dc->{'number'}] chatline ", join '|',@_,  ); 

},


    },
  );


#
#dcdmp [1] rcv: chatline <[++T]инок> Minimum search interval is:90s
#printlog('dc=', Dumper($dc));

  #  print("BOT SEND all\n"),
  #    $dc->cmd( 'chatline', 'Доброго времени суток! Пользуясь случаем, хотим сказать вам: ВЫ Э@3Б@ЛИ СПАМИТЬ!' );
  #  print("BOT SEND to $_\n"), $dc->cmd( 'To', $_, ' HUB заражен вирусом срочно покиньте его!' )
  #    for keys %{ $dc->{'NickList'} };
  while ( $dc->{'socket'} ) {
    #print "w1ds\n";
    $dc->wait_sleep();    #sleep(5); $dc->recv();
  }
  $dc->destroy();
  sleep(1);
}

sub finish_report {
  print Dumper( \%stat );
}
$SIG{INT} = $SIG{HUP} = $SIG{__DIE__} = \&finish_report;

END {
  finish_report();
}
