#!/usr/bin/perl
# $Id$ $URL$

=copyright
stat bot
=cut

use strict;
eval { use Time::HiRes qw(time sleep); };
our $root_path;
use lib $root_path. './lib';
use Net::DC::clihub;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
#use DBI;
our %config;
use lib $root_path. './pslib';    #, $root_path.'./../pslib', $root_path. './../../pslib';
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
#print "Arg=",$ARGV[0],"\n";
#print "to=[$1]";
$config{'limit_max'} ||= 100;
$config{'row_all'} = { 'not null' => 1, };
$config{'periods'} = {
  'h' => 3600,
  'd' => 86400,
  'w' => 7 * 86400,    #'m'=>31*86400, 'y'=>366*86400
};
$config{'sql'} = {
  'driver'       => 'mysql',    #'sqlite',
  'dbname'       => 'dcstat',
  'auto_connect' => 1,
  'table'        => {
    'queries' => {
      #111.111.111.111
      'time' => pssql::row( 'time', 'index' => 1 ),
      #      'added' => pssql::row('added'),
      'hub'  => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 64, 'index'  => 1 ),
      'nick' => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 32, 'index'  => 1 ),
      'ip'   => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 15, 'Zindex' => 1 ),
      'port' => pssql::row( undef, 'type' => 'SMALLINT', 'Zindex' => 1 ),
      'tth'    => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 40,  'default' => '', 'index' => 1 ),
      'string' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 255, 'default' => '', 'index' => 1 ),
    },
    'results' => {
      'time' => pssql::row( 'time', 'index' => 1 ),
      #      'added'  => pssql::row('added'),
      'string'   => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 255, 'index'  => 1 ),
      'hub'      => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 64,  'index'  => 1 ),
      'nick'     => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 32,  'index'  => 1 ),
      'ip'       => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 15,  'Zindex' => 1 ),
      'port'     => pssql::row( undef, 'type' => 'SMALLINT', 'Zindex' => 1 ),
      'tth'      => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 40,  'index'  => 1 ),
      'file'     => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 255, 'Zindex' => 1 ),
      'filename' => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 255, 'index'  => 1 ),
      'ext'      => pssql::row( undef, 'type' => 'VARCHAR',  'length' => 32,  'index'  => 1 ),
      'size'     => pssql::row( undef, 'type' => 'BIGINT',   'index'  => 1 ),
    },
    'chat' => {
      'time' => pssql::row( 'time', 'index' => 1 ),
      'hub' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 64, 'index' => 1 ),
      #      'added'  => pssql::row('added'),
      'nick'   => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 32,   'index'  => 1 ),
      'string' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 3090, 'Zindex' => 1 ),
    },
  }
};
$config{'sql'}{'table'}{ 'queries' . $_ } = {
  'tth'    => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 40,  'default' => '', 'index' => 1, 'Zprimary' => 1, ),
  'string' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 255, 'default' => '', 'index' => 1, 'Zprimary' => 1, ),
  'cnt'    => pssql::row( undef, 'type' => 'INT',     'index'  => 1 ),
  }
  for keys %{ $config{'periods'} };    #qw(h d w m y);

=z
            'file' => 'MUSIC\\UNSORTED_MUSIC_FROM_UPLOAD\\ћузыка от √а√а\\ћу«ика1\\G-Unit - 19 - Porno Star.mp3',
            'filename' => 'G-Unit - 19 - Porno Star.mp3',
            'ip' => '10.131.120.1',
            'nick' => 'ftp.wwwcom.ru',
            'port' => '411',
            'size' => '4980839',
            'tth' => 'OXYCI7EHF3JIHC47QSYQFVQVNHSWOE7N4KWWK7A'
=cut

our $db = pssql->new(
  # 'driver' => 'pgpp',
  #  'dbname' => 'markers',
  #   'table'    => $config{'table'},
  # 'codepage' => $config{'cp_db'},
  #   'log' => sub {     print join( ' ', @_ ), "\n";   },
  'log' => sub { shift; psmisc::printlog(@_) },
  #'log' => sub{},
  #   'log' => \psmisc::printlog ,
  #sub {     &psmisc::printlog   },
  'cp_in' => 'cp1251',
  #'insert_by' => 1,
  %{ $config{'sql'} or {} },
);
#$db->install() unless $ENV{'SERVER_PORT'};
#my $dbh = DBI->connect("dbi:SQLite:dbname=stat.sqlite","","");
#print 'zz:',
#$db->do('CREATE TABLE IF NOT EXIST queries (varchar ())');
#$db->do
my %every;

sub every {
  my ( $sec, $func ) = ( shift, shift );
  #printlog('dev','every', $sec, $every{$func}, time, $func ),
  $func->(@_), $every{$func} = time if $every{$func} + $sec < time and ref $func eq 'CODE';
}
unless (caller) {
  print("usage: stat.pl [--configParam=configValue] [dchub://]host[:port] [more params and hubs]\n"), exit if !$ARGV[0];
  if ( $ARGV[0] eq 'calc' ) {
    #local $config{'log_dmp'}=1;
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
  #my $hubname=$1 . ($2 ? ':'.$2:'' );
  our %work;
  #our %stat;
  #for ( 0 .. 1000 ) {
  # $ARGV[0] =~ m|^(?:dchub\://)?(.+?)(?:\:(\d+))?$|;
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
      my $dc = Net::DC::clihub->new(
        #    'host' => $1,
        #    ( $2 ? ( 'port' => $2 ) : () ),
        #      'Nick' => ( $ARGV[1] or int( rand(100000000) ) ),
        'Nick' => 'dcstat',
        #    'sharesize' => int( rand 1000000000000 ) + int( rand 100000000000 ) * int( rand 100 ),
        'sharesize' => 40_000_000_000 + int( rand 10_000_000_000 ),
        #   'log'		=>	sub {},	# no logging
        'log' => sub { shift; psmisc::printlog(@_) },
        #   'min_chat_delay'	=> 0.401,
        #   'min_cmd_delay'	=> 0.401,
        'myport'       => 41111,
        'description'  => 'http://dc.proisk.ru/dcstat/',
        'auto_connect' => 0,
        #          'M'           => 'P',
        #    'print_search' => 1,
        'reconnects' => 500,
        'handler'    => {
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
            #
            # todo: move  to lib
            #

=z
        printlog( 'dev', "[$nick] oper, set interval = $1" ), $dc->{'search_every'} = $1,
          if ( $dc->{'NickList'}->{$nick}{'oper'} and $text =~ /^Minimum search interval is:(\d+)s/ )
          or $nick eq 'Hub-Security'
          and $text =~ /Search ignored\.  Please leave at least (\d+) seconds between search attempts\./;
          $dc->search_retry(  );
=cut

            #dcdmp [1] rcv: chatline <Hub-Security> Search ignored.  Please leave at least 5 seconds between search attempts.
            # printlog( "[$dc->{'number'}] chatline ", join '|',@_,  );
          },
          'welcome' => sub {
            my $dc = shift;
            printlog( 'welcome', @_ );
          },
          #      'To' => sub {        my $dc = shift;printlog('to', @_);},
        },
        %config,
      );
      $dc->connect($hub);
      push @dc, $dc;
      $_->work() for @dc;
    }
  }
  while ( grep { $_->active() } @dc ) {
    $_->work() for @dc;
  }
  $_->destroy() for @dc;
}
