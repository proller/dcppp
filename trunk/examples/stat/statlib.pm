#!/usr/bin/perl
# $Id$ $URL$

=copyright
stat bot
=cut

package statlib;
use strict;
#eval {
use Time::HiRes qw(time sleep);
#};
our $root_path;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
#use DBI;
use lib $root_path. './pslib';
use pssql;
use psmisc;
use Exporter 'import';
our @EXPORT = qw(%config  $param   $db );    #%queries
our ( %config, $param, $db, );               #%queries
#$config{'log_all'}=1;
$config{'log_trace'} ||= $config{'log_dmpbef'} = 0;
$config{'log_dmp'} ||= 0;
#$config{'log_dcdev'}=1;
$config{'log_dcdmp'} ||= 0;
#$config{'log_obj'}='-obj.log';
$config{'hit_to_ask'} ||= 2;
$config{'ask_retry'}  ||= 3600;
$config{'limit_max'}  ||= 100;
$config{'use_slow'}   ||= 1;
$config{'row_all'} ||= { 'not null' => 1, };
$config{'periods'} ||= {
  'h' => 3600,
  'd' => 86400,
  'w' => 7 * 86400,    #'m'=>31*86400, 'y'=>366*86400
};
$config{'sql'} ||= {
  'driver'       => 'mysql',    #'sqlite',
                                #    'driver'       => 'sqlite',
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
      'port'   => pssql::row( undef, 'type' => 'SMALLINT', 'Zindex' => 1,   'default' => 0, ),
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
      'name'   => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 32, 'index' => 1, 'primary' => 1 ),
      'period' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 8,  'index' => 1, 'primary' => 1, 'default' => '' ),
      'n' => pssql::row( undef, 'type' => 'INT', 'index' => 1, 'primary' => 1, ),
      'result' => pssql::row( undef,  'type'  => 'VARCHAR', 'Zlength' => 32, 'Zindex' => 1, 'dumper' => 1, ),
      'time'   => pssql::row( 'time', 'index' => 1 ),
    },

    'hubs' => {
      'time'   => pssql::row( 'time', 'index' => 1 ),
      'hub'      => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 64,  'index'  => 1, 'default' => '', ),
      'size' => pssql::row( undef, 'type' => 'BIGINT', 'index' => 1,  ),
      'users' => pssql::row( undef, 'type' => 'INT', 'index' => 1, ),

    },

    'users' => {
      'time'   => pssql::row( 'time', 'index' => 1 ),
      'hub'      => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 64,  'index'  => 1, 'default' => '', 'primary' => 1),
      'nick'   => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 32,  'index'   => 1,  'default' => '', 'primary' => 1),
      'ip'     => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 15,  'Zindex'  => 1,  'default' => '', ),
      'port'   => pssql::row( undef, 'type' => 'SMALLINT', 'Zindex' => 1,   'default' => 0, ),
      'size' => pssql::row( undef, 'type' => 'BIGINT', 'index' => 1, 'default' => 0, ),
      'online' => pssql::row( 'time', 'index' => 1 , 'default' => 0,),
      'info' => pssql::row( undef,  'type'  => 'VARCHAR', 'Zlength' => 32, 'Zindex' => 1, 'dumper' => 1, ),

    },



  },
  'table_param' => {
    'queries' => { 'big'       => 1, },
    'results' => { 'big'       => 1, },
    'slow'    => { 'no_counts' => 1, },
    'hubs'    => { 'no_counts' => 1, },
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
my $order;

=z
$config{'queries'}{'queries top string'} = {
  #  %{ $config{'queries'}{'queries top tth'} },
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
$config{'queries'}{'results top'} = {
  #  %{ $config{'queries'}{'queries top tth raw'} },
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
$config{'queries'}{'queries top tth'} = {
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
$config{'queries'}{'queries top string'} ||= {
  #  %{ $config{'queries'}{'queries top tth raw'} },
  'main'    => 1,
  'periods' => 1,
  'class'   => 'half',
  'show'    => [qw(cnt string)],            #time
  'desc'    => 'Most searched',
  'SELECT'  => 'string, COUNT(*) as cnt',
  'FROM'    => 'queries',
  'WHERE'   => ['string != ""'],
  #  'GROUP BY' => 'tth',
  'GROUP BY' => 'string',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};
$config{'queries'}{'queries string last'} ||= {
  'main' => 1,
  #'class'=>  'right'    ,
  'class' => 'half',
  'group_end' => 1,
  'desc'  => 'last searches',
  #  'show'     => [qw(time hub nick string filename size tth)],          #time
  #  'SELECT'   => 'results.*,queries.*',
  'FROM'   => 'queries',
  'show'   => [qw(time hub nick string )],    #time  filename size tth
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
$config{'queries'}{'results top'} ||= {
  #  %{ $config{'queries'}{'queries top tth raw'} },
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
$config{'queries'}{'queries top tth'} ||= {
  'main'    => 1,
  'periods' => 1,
  'class'   => 'half',
  'desc'    => 'Most downloaded',
  #  'show'     => [qw(cnt tth)],          #time
  'show' => [qw(cnt string filename size tth )],    #time
       #'query' => 'SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1',
       #  'SELECT'   => 'tth, COUNT(*) as cnt',
  'SELECT'    => '*, COUNT(*) as cnt',
  'FROM'      => 'queries',
  'LEFT JOIN' => 'results USING (tth)',
  'WHERE'     => ['tth != ""'],
  'GROUP BY'  => 'tth',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};
#
$config{'queries'}{'queries tth last'} ||= {
  %{ $config{'queries'}{'queries string last'} },
  'desc'  => 'last downloads',
  'class' => 'half',
  'group_end' => 1,
'show'   => [qw(time hub nick filename size tth)],    #time  filename size tth string

#  'class' => '',
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



#'time'   'hub'    'nick'   'ip'     'port'   'size' = 'online' 'info' =

$config{'queries'}{'users top'} ||= {

  'main'     => 1,
  'class'  => 'half',
#  'group_end' => 1,
  'show'     => [qw(time hub nick size online )],         #time ## info 

#  'SELECT'         => '*, hub as h', #DISTINCT DISTINCT hub,size,time
 'SELECT'         => '*',
  'FROM'     => 'users',
#  'WHERE'    => ['time = (SELECT time FROM hubs WHERE hub=h ORDER BY size DESC LIMIT 1)'],
#  'GROUP BY' => 'hub',
  'ORDER BY' => 'size DESC',

#      'time'        'hub'         'size'        'users'
  'order' => ++$order,
};
$config{'queries'}{'users online'} ||= {

  'main'     => 1,
  'class'  => 'half',
  'group_end' => 1,
  'show'     => [qw(time hub nick size online )],         #time ## info 

#  'SELECT'         => '*, hub as h', #DISTINCT DISTINCT hub,size,time
 'SELECT'         => '*',
  'FROM'     => 'users',
'WHERE'    => ['online > 0'],
#  'WHERE'    => ['time = (SELECT time FROM hubs WHERE hub=h ORDER BY size DESC LIMIT 1)'],
#  'GROUP BY' => 'hub',
  'ORDER BY' => 'size DESC',

#      'time'        'hub'         'size'        'users'
  'order' => ++$order,
};



$config{'queries'}{'results top users'} ||= {
  #  %{ $config{'queries'}{'queries top tth raw'} },
  'main'    => 1,
  'periods' => 1,
  'class'   => 'half',
  'show'    => [qw(cnt hub nick )],            #time
  'desc'    => 'they have anything',
  'SELECT'  => '*, COUNT(*) as cnt',
  'FROM'    => 'results',
  'WHERE'   => ['string != ""', 'nick != ""'],
  #  'GROUP BY' => 'tth',
  'GROUP BY' => 'nick',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};

$config{'queries'}{'results top users tth'} ||= {
  #  %{ $config{'queries'}{'queries top tth raw'} },
  'main'    => 1,
  'periods' => 1,
  'class'   => 'half',
  'show'    => [qw(cnt hub  nick)],            #time
  'desc'    => 'they know 42',
  'SELECT'  => '*, COUNT(*) as cnt',
  'FROM'    => 'results',
  'WHERE'   => ['tth != ""', 'nick != ""'],
  #  'GROUP BY' => 'tth',
  'GROUP BY' => 'nick',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};


$config{'queries'}{'queries top users'} ||= {
  #  %{ $config{'queries'}{'queries top tth raw'} },
  'main'    => 1,
  'periods' => 1,
  'class'   => 'half',
  'show'    => [qw(cnt hub nick)],            #time
  'desc'    => 'they search "42"',
  'SELECT'  => '*, COUNT(*) as cnt',
  'FROM'    => 'queries',
  'WHERE'   => ['string != ""', 'nick != ""'],
  #  'GROUP BY' => 'tth',
  'GROUP BY' => 'nick',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};
$config{'queries'}{'queries top users tth'} ||= {
  #  %{ $config{'queries'}{'queries top tth raw'} },
  'main'    => 1,
  'periods' => 1,
  'class'   => 'half',
  'group_end' => 1,
  'show'    => [qw(cnt hub nick)],            #time
  'desc'    => 'they have unlimited hdds',
  'SELECT'  => '*, COUNT(*) as cnt',
  'FROM'    => 'queries',
  'WHERE'   => ['tth != ""', 'nick != ""'],
  #  'GROUP BY' => 'tth',
  'GROUP BY' => 'nick',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};




$config{'queries'}{'hubs top'} ||= {

  'main'     => 1,
  'class'  => 'half',
  'show'     => [qw(hub users size time)],         #time



#  'SELECT'         => '*, hub as h', #DISTINCT DISTINCT hub,size,time
#  'FROM'     => 'hubs',
#  'WHERE'    => ['time = (SELECT time FROM hubs WHERE hub=h ORDER BY size DESC LIMIT 1)'],

#  'SELECT'         => '*',  'FROM'     => 'hubs',  'GROUP BY' => 'hub',  'ORDER BY' => 'size DESC',


  'SELECT'         => 'h2.time,h2.users, hub, max(size) as size',  
'FROM'     => 'hubs',  
'LEFT JOIN' => 'hubs AS h2' ,
'USING' => '(hub, size)',
'GROUP BY' => 'hubs.hub',  
'ORDER BY' => 'size DESC',
#select    from hubs left join hubs as h2 using (hub, size) group by hubs.hub order by size desc limit 10


#      'time'        'hub'         'size'        'users'
  'order' => ++$order,
};


$config{'queries'}{'hubs now'} ||= {

  'main'     => 1,
#  'group_end' => 1,
  'group_end' => 1,
  'class'  => 'half',
  'show'     => [qw(time hub users size)],         #time

  'FROM'     => 'hubs',


  'SELECT'         => '*', #DISTINCT
  'WHERE'    => ['time = (SELECT time FROM hubs ORDER BY time DESC LIMIT 1)'],

#  'SELECT'         => 'hub, time, users, max(time)', 
#select hub, time, max(size) from hubs group by hub limit 10
#  'GROUP BY' => 'hub',
#'WHERE' => [],


  'ORDER BY' => 'size DESC',

#      'time'        'hub'         'size'        'users'
  'order' => ++$order,
};







$config{'queries'}{'results ext'} ||= {
  #  %{ $config{'queries'}{'queries top tth raw'} },
  'main'     => 1,
  'class'  => 'half',
  'show'     => [qw(cnt ext size)],         #time
  'desc'     => 'by extention',
  'SELECT'   => '*, SUM(size) as size , COUNT(*) as cnt',
  'FROM'     => 'results',
  'WHERE'    => ['ext != ""'],
  'GROUP BY' => 'ext',
  #!  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
  #  'LIMIT'    => 10,
  'order' => ++$order,
};
#$config{'queries'}{'results top string'} = {
#  %{ $config{'queries'}{'queries top string'} },
#  'show' => [qw(cnt string tth filename size )],    #time
#  'FROM' => 'results',
#};
$config{'queries'}{'counts'} ||= {
  'main' => 1,
  'show' => [qw(tbl cnt )],                            #time
  'class'  => 'half',
  'group_end' => 1,
  'sql'  => (
    join ' UNION ',
    map         { qq{SELECT '$_' as tbl, COUNT(*) as cnt FROM $_ } }
      sort grep { !$config{'sql'}{'table_param'}{$_}{'no_counts'} } keys %{ $config{'sql'}{'table'} }
  ),
  'order' => ++$order,
};
$config{'queries'}{'chat top'} ||= {
  #  %{ $config{'queries'}{'queries top tth raw'} },
  'main' => 1,
  #  'periods' => 1,
  'class'  => 'half',
  'show'   => [qw(cnt hub nick)],     #time
  'desc'   => 'top flooders',
  'SELECT' => '*, COUNT(*) as cnt',
  'FROM'   => 'chat',
  #  'WHERE'   => ['nick != ""'],
  #  'GROUP BY' => 'tth',
  'GROUP BY' => 'nick',
  'ORDER BY' => 'cnt DESC',
  'order'    => ++$order,
};
$config{'queries'}{'chat last'} ||= {
  #  %{ $config{'queries'}{'queries top tth raw'} },
  'main' => 1,
  #  'periods' => 1,
  'class'          => 'half',
  'group_end' => 1,
  'no_string_link' => 1,
  'show'           => [qw(time hub nick string)],    #time
                                                     #  'desc'    => 'top flooders',
  'SELECT'         => '*',
  'FROM'           => 'chat',
  #  'WHERE'   => ['nick != ""'],
  #  'GROUP BY' => 'tth',
  #  'GROUP BY' => 'nick',
  'ORDER BY' => 'time DESC',
  'order'    => ++$order,
};




$config{'queries'}{'string'} ||= {
  #'desc' => $param->{'string'}, #!!! dehtml
  'show' => [qw(cnt string  filename size tth)],    #time
       #'query' => 'SELECT *, COUNT(*) as cnt FROM queries $where GROUP BY tth HAVING cnt > 1',
  'no_query_link' => 1,
  'SELECT'        => '*, COUNT(*) as cnt',
  #  'FROM'     => 'queries',
  'WHERE'    => ['tth != ""'],
  'GROUP BY' => 'tth',
  #  'HAVING'   => 'cnt > 1',
  'ORDER BY' => 'cnt DESC',
  #  %{ $config{'queries'}{'queries top string'} },
  #  'show' => [qw(cnt string filename size )],    #time
  'FROM' => 'results',
};
$config{'queries'}{'tth'} ||= {
  %{ $config{'queries'}{'string'} },
  'desc'     => 'various filenames',
  'show'     => [qw(cnt string filename size tth)],    #time
                                                       #'WHERE'    => ['tth != ""'],
  'GROUP BY' => 'filename',
};


psmisc::config( 0, 0, 0, 1 );

sub is_slow {
  my ($query) = @_;
  return ( (
            $config{'sql'}{'table_param'}{ $config{'queries'}{$query}{'FROM'} }{'big'}
        and $config{'queries'}{$query}{'GROUP BY'}
        and $config{'queries'}{$query}{'main'}
    )
      or $config{'queries'}{$query}{'slow'}
    )
    # $config{'queries'}{$query}{'GROUP BY'} =~ /\bcnt\b/i
    ;
  #      print "slow:$query ($config{'queries'}{$query}{'FROM'})\n";
}

sub make_query {
  my ( $q, $query, $period ) = @_;
  #print Dumper $q;
  #print "is_slow($query)"
  my $sql;
  if ( is_slow($query) and $ENV{'SERVER_PORT'} and $config{'use_slow'} ) {
    #print "SLOWASK";
    $sql = "SELECT * FROM slow WHERE name = " . $db->quote($query) . (
      #!$period ?'': ' AND period='. $db->quote($period)
      ( $config{'queries'}{$query}{'periods'} ? ' AND period=' . $db->quote($period) : '' )
      . " LIMIT $config{'query_default'}{'LIMIT'}"
    );
    my $res = $db->query($sql);
    my @ret;
    for my $row (@$res) {
      #    printlog 'preeval',$row->{'result'};
      push @ret, eval $row->{'result'};
    }
    return \@ret;

=z
    my $res =  $db->query($sql)->[0]{'result'};
    printlog 'preeval',Dumper $res;
    $res = eval $res;
    printlog 'evaled',Dumper $res;
    return [ grep { $_ } @$res[ 0 .. $config{'query_default'}{'LIMIT'} - 1 ] ];
=cut
  }
  #printlog 'mkparams:', Dumper $param;
  $q->{'WHERE'} = join ' AND ', grep { $_ } @{ $q->{'WHERE'}, } if ref $q->{'WHERE'} eq 'ARRAY';
  $q->{'WHERE'} = join ' AND ', grep { $_ } $q->{'WHERE'},
    #( $param->{'time'} ? "time >= " . int( (time - $param->{'time'})/1000)*1000 : '' ),
    map { $_ . '=' . $db->quote( $param->{$_} ) } grep { length $param->{$_} } qw(string tth);
  $sql = join ' ', $q->{'sql'},
    map { my $key = ( $q->{$_} || $config{query_default}{$_} ); length $key ? ( $_ . ' ' . $key ) : '' } 'SELECT', 'FROM',
    #'NATURAL LEFT JOIN',
    'LEFT JOIN',
    #    'STRAIGHT_JOIN',
    #    'LEFT OUTER JOIN',
    'USING', 'WHERE', 'GROUP BY', 'HAVING', 'ORDER BY', 'LIMIT', 'UNION';
  #  print "[$sql]<br/>\n";
  return $db->query($sql);
}
$db ||= pssql->new( %{ $config{'sql'} or {} }, );
#$db->{'dbh'}->{'unicode'} = 1;
#print 'db init';
1;
