#!/usr/bin/perl
# $Id$ $URL$

=copyright
stat bot
=cut

use strict;
eval { use Time::HiRes qw(time sleep); };
our $root_path;
use lib $root_path. '../../lib';
use Net::DirectConnect::clihub;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
#use DBI;
our %config;
use lib $root_path. './pslib';
use pssql;
use psmisc;
psmisc::config( 0, 0, 0, 1 );
#$config{'log_all'}=1;
$config{'log_trace'} = $config{'log_dmpbef'} = 0;
$config{'log_dmp'} = 0;
#$config{'log_dcdev'}=1;
#$config{'log_dcdmp'}=1;
#$config{'log_obj'}='-obj.log';
$config{'hit_to_ask'}         ||= 2;
$config{'queue_recalc_every'} ||= 30;
$config{'ask_retry'}          ||= 3600;
$config{'limit_max'}          ||= 100;
#$config{'use_slow'}           ||= 1;
$config{'row_all'} = { 'not null' => 1, };
$config{'periods'} = {
  'h' => 3600,
  'd' => 86400,
  'w' => 7 * 86400,    #'m'=>31*86400, 'y'=>366*86400
};
$config{'sql'} = {
    'driver'       => 'mysql',    #'sqlite',
#  'driver'       => 'sqlite',
  'dbname'       => 'dcstat',
  'auto_connect' => 1,
  #'insert_by'=>10, # uncomment if you have 0-100 users # !!!TODO make auto !!! TODO max time in insert cache
  'log' => sub { shift; psmisc::printlog(@_) },
  'cp_in' => 'cp1251',
  'table' => {
    'queries' => {
      #111.111.111.111
      'time' => pssql::row( 'time', 'index' => 1, 'purge' => 1, ),
      #      'added' => pssql::row('added'),
      'hub'    => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 64,  'index'   => 1,  'default' => '', ),
      'nick'   => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 32,  'index'   => 1,  'default' => '', ),
      'ip'     => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 15,  'Zindex'  => 1,  'default' => '', ),
      'port'   => pssql::row( undef, 'type' => 'SMALLINT', 'Zindex' => 1 ),
      'tth'    => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 40,  'default' => '', 'index'   => 1 ),
      'string' => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 255, 'default' => '', 'index'   => 1 ),
    },
    'results' => {
      'time' => pssql::row( 'time', 'index' => 1, 'purge' => 1, ),
      'string'   => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 255, 'index'  => 1, 'default' => '', ),
      'hub'      => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 64,  'index'  => 1, 'default' => '', ),
      'nick'     => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 32,  'index'  => 1, 'default' => '', ),
      'ip'       => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 15,  'Zindex' => 1, 'default' => '', ),
      'port'     => pssql::row( undef, 'type' => 'SMALLINT', 'Zindex' => 1 ),
      'tth'      => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 40,  'index'  => 1, 'default' => '', ),
      'file'     => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 255, 'Zindex' => 1, 'default' => '', ),
      'filename' => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 255, 'index'  => 1, 'default' => '', ),
      'ext'      => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 32,  'index'  => 1, 'default' => '', ),
      'size'     => pssql::row( undef, 'type' => 'BIGINT',   'index'  => 1 ),
    },
    'chat' => {
      'time' => pssql::row( 'time', 'index' => 1 ),
      'hub' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 64, 'index' => 1, 'default' => '', ),
      #      'added'  => pssql::row('added'),
      'nick'   => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 32,   'index'  => 1, 'default' => '', ),
      'string' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 3090, 'Zindex' => 1, 'default' => '', ),
    },
    'slow' => {
      'name'   => pssql::row( undef, 'type' => 'VARCHAR', 'length'  => 32, 'index'  => 1, 'primary' => 1 ),
      'period' => pssql::row( undef, 'type' => 'VARCHAR', 'length'  => 8,  'index'  => 1, 'primary' => 1, 'default' => '' ),
      'result' => pssql::row( undef, 'type' => 'VARCHAR', 'Zlength' => 32, 'Zindex' => 1, 'dumper'  => 1, ),
      'time' => pssql::row( 'time', 'index' => 1 ),

    },
  },
  'table_param' => {
    'queries' => { 'big' => 1, },
    'results' => { 'big' => 1, },
  },
};

=z
$config{'sql'}{'table'}{ 'queries' . $_ } = {
  'tth'    => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 40,  'default' => '', 'index' => 1, 'Zprimary' => 1, ),
  'string' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 255, 'default' => '', 'index' => 1, 'Zprimary' => 1, ),
  'cnt'    => pssql::row( undef, 'type' => 'INT',     'index'  => 1 ),
  }
  for keys %{ $config{'periods'} };    #qw(h d w m y);
$config{'sql'}{'table'}{'resultsf'} =
  { %{ $config{'sql'}{'table'}{'results'} }, 'cnt' => pssql::row( undef, 'type' => 'INT', 'index' => 1 ), };
delete $config{'sql'}{'table'}{'resultsf'}{$_} for qw(time nick ip port file);
=cut

=z
            'file' => 'MUSIC\\UNSORTED_MUSIC_FROM_UPLOAD\\ћузыка от √а√а\\ћу«ика1\\G-Unit - 19 - Porno Star.mp3',
            'filename' => 'G-Unit - 19 - Porno Star.mp3',
            'ip' => '10.131.120.1',
            'nick' => 'ftp.wwwcom.ru',
            'port' => '411',
            'size' => '4980839',
            'tth' => 'OXYCI7EHF3JIHC47QSYQFVQVNHSWOE7N4KWWK7A'
=cut
$config{'query_default'}{'LIMIT'} ||= 100;
our %queries;
my $order;

=z
$queries{'queries top string'} = {
  #  %{ $queries{'queries top tth'} },
#!  'main'   => 1,
  'show'   => [qw(cnt string)],                                                                  #time
  'desc'   => 'Most searched',
  'SELECT' => 'string, cnt',
  'FROM'   => 'queries' . ( $config{'periods'}{ $param->{'time'} } ? $param->{'time'} : 'd' ),
  #  'GROUP BY' => 'string',
  'WHERE'    => ['string != ""'],
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};
$queries{'results top'} = {
  #  %{ $queries{'queries top tth raw'} },
#!  'main'   => 1,
  'show'   => [qw(cnt string filename size tth)],    #time
  'desc'   => 'Most stored',
  'SELECT' => '*',
  'FROM'   => 'resultsf',
  'WHERE'  => ['tth != ""'],
  #  'GROUP BY' => 'tth',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};

my $queriesfast = 'queries' . ( $config{'periods'}{ $param->{'time'} } ? $param->{'time'} : 'd' );
$queries{'queries top tth'} = {
#!  'main' => 1,
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
  'order'    => ++$order,
};
=cut
$queries{'queries top string raw'} = {
  #  %{ $queries{'queries top tth raw'} },
  'main'     => 1,
  'periods'  => 1,
  'show'     => [qw(cnt string)],            #time
  'desc'     => 'Most searched',
  'SELECT'   => 'string, COUNT(*) as cnt',
  'FROM'     => 'queries',
  'GROUP BY' => 'string',
  'WHERE'    => ['string != ""'],
  'GROUP BY' => 'tth',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};
$queries{'results top raw'} = {
  #  %{ $queries{'queries top tth raw'} },
  'main'     => 1,
  'periods'  => 1,
  'show'     => [qw(cnt string filename size tth)],    #time
  'desc'     => 'Most stored',
  'SELECT'   => '*, COUNT(*) as cnt',
  'FROM'     => 'results',
  'WHERE'    => ['tth != ""'],
  'GROUP BY' => 'tth',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};
$queries{'queries top tth raw'} = {
  'main'     => 1,
  'periods'  => 1,
  'desc'     => 'Most downloaded',
  'show'     => [qw(cnt tth)],          #time
                                        #'query' => 'SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1',
  'SELECT'   => 'tth, COUNT(*) as cnt',
  'FROM'     => 'queries',
  'WHERE'    => ['tth != ""'],
  'GROUP BY' => 'tth',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};
#
$queries{'queries string last'} = {
  'main' => 1,
  'desc' => 'last searches',
  #  'show'     => [qw(time hub nick string filename size tth)],          #time
  #  'SELECT'   => 'results.*,queries.*',
  'FROM'   => 'queries',
  'show'   => [qw(time hub nick string filename size tth)],    #time
                                                               #'SELECT'   => 'queries.*, results.*',
                                                               #    'SELECT'   => 'results.*,queries.*',
  'SELECT' => '*',
  #    'SELECT'   => '*, (SELECT filename FROM results WHERE queries.string=results.string LIMIT 1) AS filename',
  #no  'FROM'     => 'queries INNER JOIN results ON queries.string=results.string',
  #  'FROM'     => 'queries NATURAL LEFT JOIN results ', #ON queries.string=results.string
  #  'FROM'     => 'queries LEFT OUTER JOIN results ON queries.string=results.string', #ON queries.string=results.string
  #  'LEFT JOIN' => 'results USING (string)',
  'WHERE' => ['queries.string != ""'],
  #  'GROUP BY' => 'queries.string',
  'ORDER BY' => 'queries.time DESC',
  'order'    => ++$order,
};
$queries{'queries tth last'} = {
  %{ $queries{'queries string last'} },
  'desc' => 'last downloads',
#  'LEFT JOIN' => 'results USING (tth)',
#    'SELECT'   => '*, (SELECT string FROM results WHERE queries.tth=results.tth LIMIT 1) AS string',
#    'SELECT'   => '*, (SELECT * FROM results WHERE queries.tth=results.tth LIMIT 1) AS r',
#    'SELECT'   => ' (SELECT * FROM results WHERE queries.tth=results.tth LIMIT 1) AS r, *',
#    'SELECT'   => ' (SELECT string,size FROM results WHERE queries.tth=results.tth LIMIT 1) AS r, queries.*',
#    'SELECT'   => 'queries.* ,(SELECT string,size FROM results WHERE queries.tth=results.tth LIMIT 1) as r  ', # Operand should contain 1 column(s)
#works but ugly
  'SELECT' =>
'*, (SELECT string FROM results WHERE queries.tth=results.tth LIMIT 1) AS string, (SELECT filename FROM results WHERE queries.tth=results.tth LIMIT 1) AS filename, (SELECT size FROM results WHERE queries.tth=results.tth LIMIT 1) AS size',
  'WHERE'    => ['tth != ""'],
  'ORDER BY' => 'queries.time DESC',
#select q.*, r.* from queries as q join (select tth, string, filename, size from results limit 1) as r where q.tth = r.tth limit 10
#  'SELECT'   => 'q.*, r.*',
#  'FROM'     => 'queries as q',
#  'LEFT JOIN' => '(select tth, string, filename, size from results limit 1) as r ON (r.tth=q.tth)',
#  'WHERE'    => ['q.tth = r.tth','q.tth != ""'],
#  'ORDER BY' => 'q.time DESC',
#SELECT q.*, r.* FROM queries AS q, (SELECT string, filename, size FROM results LIMIT 1) AS r LIMIT 10
#  'SELECT'   => 'q.*, r.*',
#  'FROM'     => 'queries as q , (SELECT string, filename, size FROM results WHERE tth=queries.tth LIMIT 1) AS r',
#  'WHERE'    => ['q.tth != ""'], #'q.tth = r.tth',
#  'ORDER BY' => 'q.time DESC',
#too slow
#  'SELECT'   => 'q.*, r.*',
#  'FROM'     => 'queries as q  LEFT JOIN (SELECT tth, string, filename, size FROM results WHERE queries.tth=results.tth) AS r ON (q.tth = r.tth) ', #GROUP BY tth, string, filename, size
#  'WHERE'    => ['q.tth != ""'], #'q.tth = r.tth',
#  'ORDER BY' => 'q.time DESC',
#  'SELECT'   => 'queries.*, r.*',
#  'FROM'     => 'queries LEFT JOIN (SELECT tth, string, filename, size FROM results WHERE queries.tth=results.tth) AS r ON (queries.tth = r.tth) ', #GROUP BY tth, string, filename, size
#  'WHERE'    => ['queries.tth != ""'], #'q.tth = r.tth',
#  'ORDER BY' => 'queries.time DESC',
#  'ORDER BY' => 'queries.time DESC',
  'order' => ++$order,
};
$queries{'results ext'} = {
  #  %{ $queries{'queries top tth raw'} },
  'main'     => 1,
  'show'     => [qw(cnt ext )],         #time
  'desc'     => 'by extention',
  'SELECT'   => '*, COUNT(*) as cnt',
  'FROM'     => 'results',
  'WHERE'    => ['ext != ""'],
  'GROUP BY' => 'ext',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
  'LIMIT'    => 10,
  'order'    => ++$order,
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
our $db = pssql->new( %{ $config{'sql'} or {} }, );
#$db->{'dbh'}->{'unicode'} = 1;
my %every;

sub every {
  my ( $sec, $func ) = ( shift, shift );
  #printlog('dev','every', $sec, $every{$func}, time, $func ),
  $func->(@_), $every{$func} = time if $every{$func} + $sec < time and ref $func eq 'CODE';
}

sub make_query {
  my ( $q, $query, $period ) = @_;
  #print Dumper $q;
  #print "is_slow($query)"
  my $sql;
  if ( is_slow($query) and $ENV{'SERVER_PORT'} and $config{'use_slow'}) {
    #print "SLOWASK";
    $sql = "SELECT result FROM slow WHERE name = " . $db->quote($query) . (
      #!$period ?'': ' AND period='. $db->quote($period)
      ' AND period=' . $db->quote($period)
    );
    my $res = eval $db->query($sql)->[0]{'result'};
    #print Dumper $res;
    return [ grep { $_ } @$res[ 0 .. $config{'query_default'}{'LIMIT'} - 1 ] ];
  }
  $q->{'WHERE'} = join ' AND ', grep { $_ } @{ $q->{'WHERE'}, } if ref $q->{'WHERE'} eq 'ARRAY';
  $q->{'WHERE'} = join ' AND ', grep { $_ } $q->{'WHERE'},
    #( $param->{'time'} ? "time >= " . int( (time - $param->{'time'})/1000)*1000 : '' ),
    map { $_ . '=' . $db->quote( $param->{$_} ) } grep { length $param->{$_} } qw(string tth);
  $sql = join ' ',
    map { my $key = ( $q->{$_} || $config{query_default}{$_} ); length $key ? ( $_ . ' ' . $key ) : '' } 'SELECT', 'FROM',
    #'NATURAL LEFT JOIN',
    'LEFT JOIN',
    #    'STRAIGHT_JOIN',
    #    'LEFT OUTER JOIN',
    'USING', 'WHERE', 'GROUP BY', 'HAVING', 'ORDER BY', 'LIMIT';
  #  print "[$sql]<br/>\n";
  return $db->query($sql);
}

sub is_slow {
  my ($query) = @_;
  return ( (
            $config{'sql'}{'table_param'}{ $queries{$query}{'FROM'} }{'big'}
        and $queries{$query}{'GROUP BY'}
        and $queries{$query}{'main'}
    )
      or $queries{$query}{'slow'}
    )
    # $queries{$query}{'GROUP BY'} =~ /\bcnt\b/i
    ;
  #      print "slow:$query ($queries{$query}{'FROM'})\n";
}
unless (caller) {
  print("usage: stat.pl [--configParam=configValue] [dchub://]host[:port] [more params and hubs]\n"), exit if !$ARGV[0];
  if ( $ARGV[0] eq 'calc' and $config{'use_slow'} ) {
local  $db->{ 'cp_in'} = 'utf-8';


    #local $config{'log_dmp'}=1;
    for my $query ( keys %queries ) {
      #      print "pre:$query ($queries{$query}{'FROM'}) { $queries{$query}{'GROUP BY'} }\n";
      next
        unless is_slow($query);
      #'time' =  int( time - $config{'periods'}{$_} ) ;
      #
      # if     $queries{$query}{'periods'}   ;
      for my $time ( $queries{$query}{'periods'}
        ? ( sort { $config{'periods'}{$a} <=> $config{'periods'}{$b} } keys %{ $config{'periods'} } )
        : () )
      {
        printlog 'tim', $time, $config{'periods'}{$time};
        #(!$time ? () : ('time'$config{'periods'}{$time}))
        local $queries{$query}{'WHERE'}[5] = "time >= " . int( time - $config{'periods'}{$time} )
          if $time;
        my $res = make_query( { %{ $queries{$query} }, }, $query );
        printlog Dumper $res;
        local $Data::Dumper::Indent = 0;
        local $Data::Dumper::Terse  = 1;
        #$db->do('INSERT INTO slow VALUES ('.$db->quote($query).', '.$db->quote('').','.$db->quote(Dumper $res).' )');
        $db->insert_hash( 'slow', { 'name' => $query, 'result' => Dumper($res), 'period' => $time, 'time'=>int(time)} );
      }
    }
    exit;
    $db->do(
      'CREATE TABLE IF NOT EXISTS resultsftmp LIKE resultsf',
#      'REPLACE LOW_PRIORITY resultsftmp (string,hub,tth,filename,ext,size, cnt) SELECT string,hub,tth,filename,ext,size, COUNT(*) as cnt FROM results WHERE string != ""  GROUP BY string HAVING cnt > 1 ORDER BY cnt DESC LIMIT '        . $config{'limit_max'} . '',
'REPLACE LOW_PRIORITY resultsftmp (string,hub,tth,filename,ext,size, cnt) SELECT string,hub,tth,filename,ext,size, COUNT(*) as cnt FROM results WHERE tth != ""  GROUP BY tth HAVING cnt > 1 ORDER BY  cnt DESC LIMIT '
        . $config{'limit_max'} . '',
      'DROP TABLE resultsf',
      'RENAME TABLE resultsftmp TO resultsf',
    );
    $db->do(
      'CREATE TABLE IF NOT EXISTS queries' . $_ . 'tmp LIKE queries' . $_,
      'REPLACE LOW_PRIORITY queries' 
        . $_
        . 'tmp (string, cnt) SELECT string, COUNT(*) as cnt FROM queries WHERE string != "" AND time >= '
        . ( int( time - $config{'periods'}{$_} ) )
        . ' GROUP BY string HAVING cnt > 1 ORDER BY cnt DESC LIMIT '
        . $config{'limit_max'} . '',
      'REPLACE LOW_PRIORITY queries' 
        . $_
        . 'tmp (tth, cnt) SELECT tth, COUNT(*) as cnt FROM queries WHERE tth != "" AND time >= '
        . ( int( time - $config{'periods'}{$_} ) )
        . ' GROUP BY tth HAVING cnt > 1 ORDER BY  cnt DESC LIMIT '
        . $config{'limit_max'} . '',
      'DROP TABLE queries' . $_,
      'RENAME TABLE queries' . $_ . 'tmp TO queries' . $_,
      )
      for $ARGV[1]
      or sort { $config{'periods'}{$a} <=> $config{'periods'}{$b} } keys %{ $config{'periods'} };
    exit;
  }
  our %work;
  our @dc;

  sub close_all {
    flush_all();
    $db->disconnect();
    $_->destroy() for @dc;
    exit;
  }

  sub flush_all {
    $db->flush_insert();
  }
  $SIG{INT} = $SIG{__DIE__} = \&close_all;
  $SIG{HUP} = $^O =~ /win/i ? \&close_all : \&flush_all;
  for (@ARGV) {
    local @_;
    if ( /^-/ and @_ = split '=', $_ ) {
      $config{config_file} = $_[1], psmisc::config() if $_[0] eq '--config';
      psmisc::program_one( 'params_pre_config', @_[ 1, 0 ] );
    } else {
      my $hub = $_;
      #    print "i=$_\n";
      my $dc = Net::DirectConnect::clihub->new(
        'Nick'      => 'dcstat',
        'sharesize' => 40_000_000_000 + int( rand 10_000_000_000 ),
        #   'log'		=>	sub {},	# no logging
        'log' => sub { shift; psmisc::printlog(@_) },
        #   'min_cmd_delay'	=> 0.401,
        'myport'       => 41111,
        'description'  => 'http://dc.proisk.ru/dcstat/',
        'auto_connect' => 0,
        #          'M'           => 'P',
        'reconnects' => 500,
        #    'print_search' => 1,
        'handler' => {
          'Search_parse_aft' => sub {
            my $dc     = shift;
            my $search = shift;
            #        print "Sh=", Dumper(\@_);
            my %s = ( %{ $_[0] }, );
            #        print "s:[$search]\n";
            #my ($who, $cmd)
            #        printlog('dcdev', "search", $search);
            #printlog('dcdev', "ignoring self search"),
            return if $s{'nick'} eq $dc->{'Nick'};
            #print "search[$nick, $ip, $port, ",join('|', @cmd),"]\n";
            #        for (qw(tth nick string ip)) {          ++$stat{$_}{ $s{$_} } if $s{$_};        }
            $db->insert_hash( 'queries', \%s );
            #and !$work{'askstth'}++
            my $q = $s{'tth'} || $s{'string'} || return;
            ++$work{'ask'}{$q};
            #        printlog('dcdev', "q1", $q, $work{'ask'}{ $q });
            every(
              $config{'queue_recalc_every'},
              our $queuerecalc ||= sub {
                my $time = int time;
                $work{'toask'} = [ (
                    sort { $work{'ask'}{$b} <=> $work{'ask'}{$a} }
                      grep { $work{'ask'}{$_} >= $config{'hit_to_ask'} and !exists $work{'asked'}{$_} } keys %{ $work{'ask'} }
                  ), (
                    sort { $work{'ask'}{$b} <=> $work{'ask'}{$a} }
                      grep {
                            $work{'ask'}{$_} >= $config{'hit_to_ask'}
                        and $work{'asked'}{$_}
                        and $work{'asked'}{$_} + $config{'ask_retry'} < $time
                      } keys %{ $work{'ask'} }
                  )
                ];
                printlog( 'info', "queue len=", scalar @{ $work{'toask'} }, " first hits=", $work{'ask'}{ $work{'toask'}[0] } );
              }
            );
            $q = shift @{ $work{'toask'} } or return;
            #        printlog('dcdev', "q2", $q, $work{'ask'}{ $q }, Dumper $dc->{'search_todo'} );
            #if ($q and ++$work{'ask'}{ $q }  >= $config{'hit_to_ask'}  and !exists $work{'asked'}{ $q }) {
            if (
              !$dc->{'search_todo'}
              #and !@{$work{'toask'}||[]}
              )
            {
              $work{'asked'}{$q} = int time;
              $dc->search($q);
            }
#}
#        print Dumper( \%stat );
#every (10, our $dumpf ||= sub {if (open FO, '>', 'obj.log') {printlog("dumping dc");print FO Dumper(\%work, \%stat,);close FO;}});
#$dc
          },
          'SR_parse_aft' => sub {
            my $dc = shift;
            #        my $search = shift;
            my %s = %{ $_[1] || return };
            #        printlog( 'SR=', Dumper( \@_ ) );
            $db->insert_hash( 'results', \%s );
          },
          'chatline' => sub {
            my $dc = shift;
            #        printlog( 'chatline', join '!',@_ );
            my %s;
            ( $s{nick}, $s{string} ) = $_[0] =~ /^<([^>]+)> (.+)$/;
            $db->insert_hash( 'chat', { %s, 'time' => int(time), 'hub' => $dc->{'hub'}, } );
          },
          'welcome' => sub {
            my $dc = shift;
            printlog( 'welcome', @_ );
          },
          #      'To' => sub {        my $dc = shift;printlog('to', @_);},
        },
        %config,
      );
      #$dc->{'no_print'}{'SR'} => 1;
      $dc->connect($hub);
      push @dc, $dc;
      $_->work() for @dc;
    }
  }
  while ( local @_ = grep { $_->active() } @dc ) {
    $_->work() for @_;
  }
  $_->destroy() for @dc;
}
