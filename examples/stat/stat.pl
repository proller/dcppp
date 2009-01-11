#!/usr/bin/perl
# $Id: stat.pm 383 2009-01-08 03:47:59Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/examples/stat/stat.pm $
package statpl;
use strict;
no warnings qw(uninitialized);
our ( %config, $param, $db, );    #%queries
use statlib;
use Data::Dumper;                 #dev only
$Data::Dumper::Sortkeys = 1;
use psmisc;
#unless (caller) {
our $root_path;
use lib $root_path. '../../lib';
use lib $root_path. './';
use Net::DirectConnect::clihub;
$config{'queue_recalc_every'} ||= 10;    #30
#print Dumper (\%INC, \@INC);
print(
  "usage:
 stat.pl [--configParam=configValue] [dchub://]host[:port] [more params and hubs]\n
 stat.pl calc [h|d|w|m]|[r]	-- calculate slow stats for all times or hour..day... r=d+w+m\n
"
  ),
  exit
  if !$ARGV[0];
if ( $ARGV[0] eq 'calc' ) {
  #exit unless $config{'use_slow'};
  local $db->{'cp_in'} = 'utf-8';
  #local $config{'log_dmp'}=1;
  for my $query ( sort keys %{ $config{'queries'} } ) {
    #      print "pre:$query ($config{'queries'}{$query}{'FROM'}) { $config{'queries'}{$query}{'GROUP BY'} }\n";
    next if $config{'queries'}{$query}{'disabled'};
    next
      unless statlib::is_slow($query);
    #'time' =  int( time - $config{'periods'}{$_} ) ;
    #
    # if     $config{'queries'}{$query}{'periods'}   ;
    for my $time (
      $config{'queries'}{$query}{'periods'}
      ? ( ( $ARGV[1] ne 'r' ? $ARGV[1] : () )
          or sort { $config{'periods'}{$a} <=> $config{'periods'}{$b} } keys %{ $config{'periods'} } )
      : ('')
      )
    {
      #printlog $query ,$time;
      next if $ARGV[1] eq 'r' and ( !$config{'queries'}{$query}{'periods'} or $time eq 'h' );
      printlog 'info', 'calculating ', $time, $query;
      #(!$time ? () : ('time'$config{'periods'}{$time}))
      local $config{'queries'}{$query}{'WHERE'}[5] =
        $config{'queries'}{$query}{'FROM'} . ".time >= " . int( time - $config{'periods'}{$time} )
        if $time;
      my $res = statlib::make_query( { %{ $config{'queries'}{$query} }, }, $query );
      #        printlog Dumper $res;
      #      local $Data::Dumper::Indent = 0;
      #      local $Data::Dumper::Terse  = 1;
      #$db->do('INSERT INTO slow VALUES ('.$db->quote($query).', '.$db->quote('').','.$db->quote(Dumper $res).' )');
      my $n = 0;
      for my $row (@$res) {
        ++$n;
        my $dmp =
          #Dumper($row);
          Data::Dumper->new( [$row] )->Indent(0)->Terse(1)->Purity(1)->Dump();
        #printlog 'res len=', length $dmp;
        #      $db->insert_hash( 'slow', { 'name' => $query, 'result' => $dmp, 'period' => $time, 'time' => int(time) } );
        $db->insert_hash( 'slow', { 'name' => $query, 'n' => $n, 'result' => $dmp, 'period' => $time, 'time' => int(time) } );
      }
      $db->do( "DELETE FROM slow WHERE name=" . $db->quote($query) . " AND period=" . $db->quote($time) . " AND n>$n " );
      $db->flush_insert('slow');
      sleep 3;
    }
  }

=z
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
=cut
  exit;
}
our %work;
our @dc;

sub close_all {
  #              printlog( 'info', 'CLOSEBYSIG'	      );
  flush_all();
  $db->disconnect();
  $_->destroy() for @dc;
  exit;
}

sub flush_all {
  #              printlog( 'info', 'FLUSHBYSIG'	      );
  $db->flush_insert();
}

sub print_info {
 #              printlog( 'info', "queue len=", scalar @{ $work{'toask'} }, " first hits=", $work{'ask'}{ $work{'toask'}[0] } );
  printlog( 'info', "queue len=", scalar @{ $work{'toask'} || [] }, " first hits=", $work{'ask'}{ $work{'toask'}[0] } );
  local @_ = grep { $_->active() } @dc;
  printlog 'info', 'active hubs:', map {
    $_->{'host'} . ':' . $_->{'status'}
      #.' sock:'.$_->{'socket'}->connected() .' eof='. $_->{'socket'}->eof()
  } @_;
  #printlog 'info', 'hashes:', map {$_.'='. %{$work{$_}}} qw(asked ask_db) ;
  printlog 'info', 'hashes:', map { $_ . '=' . scalar %{ $work{$_} || {} } } qw(ask asked ask_db);
  #  psmisc::file_rewrite(    'dumper',    Dumper [      'work' => \%work,      'db'   => $db,      'dc'   => \@dc,    ]  );
}
$SIG{INT} = $SIG{__DIE__} = \&close_all;
$SIG{HUP} = $^O =~ /win/i
  ?
  #\&close_all
  #sub {flush_all(); print_info();}
  \&print_info
  : \&flush_all;
$SIG{INFO} = \&print_info;
#printlog 'info', 'hashes:', map {$_.'='. %{$work{$_}}} qw(asked ask_db) ;
for (@ARGV) {
  local @_;
  if ( /^-/ and @_ = split '=', $_ ) {
    $config{config_file} = $_[1], psmisc::config() if $_[0] eq '--config';
    psmisc::program_one( 'params_pre_config', @_[ 1, 0 ] );
  } else {
    my $hub = $_;
    #    print "i=$_\n";
    my $dc = Net::DirectConnect::clihub->new(
      'Nick'      => 'dcstat_dev',
      'sharesize' => 40_000_000_000 + int( rand 10_000_000_000 ),
      #   'log'		=>	sub {},	# no logging
      'log' => sub { psmisc::printlog(@_) },
      #   'min_cmd_delay'	=> 0.401,
      'myport'       => 41111,
      'description'  => 'http://dc.proisk.ru/dcstat/',
      'auto_connect' => 0,
      #          'M'           => 'P',
      'reconnects' => 500,
      #    'print_search' => 1,
      'handler' => {
        'Search_parse_aft' => sub {
          my $dc = shift;
          #$dc->log('hndl', 'Search_parse_aft', 'run');
          my $search = shift;
          #        print "Sh=", Dumper(\@_);
          my %s = ( %{ $_[0] }, );
          #        print "s:[$search]\n";
          #my ($who, $cmd)
          #                  printlog('dcdev', "search", $search, '--',%s);
          #printlog('dcdev', "ignoring self search"),
          return if $s{'nick'} eq $dc->{'Nick'};
          #print "search[$nick, $ip, $port, ",join('|', @cmd),"]\n";
          #        for (qw(tth nick string ip)) {          ++$stat{$_}{ $s{$_} } if $s{$_};        }
          #$dc->log('hndl', 'ih');
          $db->insert_hash( 'queries', \%s );
          #and !$work{'askstth'}++
          my $q = $s{'tth'} || $s{'string'} || return;
          ++$work{'ask'}{$q};
          #        printlog('dcdev', "q1", $q, $work{'ask'}{ $q });
##$dc->log('hndl', 'evrf');
##$dc->log('hndl', 'evrr');
          psmisc::schedule(
            $config{'queue_recalc_every'},
            our $queuerecalc_ ||= sub {
##$dc->log('hndl', 'e sub');
              my $time = int time;
              $work{'toask'} = [ (
                  sort { $work{'ask'}{$b} <=> $work{'ask'}{$a} }
                    grep { $work{'ask'}{$_} >= $config{'hit_to_ask'} and !exists $work{'asked'}{$_} } keys %{ $work{'ask'} }
                )
              ];
              printlog( 'warn', "reasking" ), $work{'toask'} = [ (
                  sort { $work{'ask'}{$b} <=> $work{'ask'}{$a} }
                    grep {
                          $work{'ask'}{$_} >= $config{'hit_to_ask'}
                      and $work{'asked'}{$_}
                      and $work{'asked'}{$_} + $config{'ask_retry'} < $time
                    } keys %{ $work{'ask'} }
                )
                ]
                unless @{ $work{'toask'} };
              printlog( 'info', "queue len=", scalar @{ $work{'toask'} }, " first hits=", $work{'ask'}{ $work{'toask'}[0] } );
            }
          );
##$dc->log('hndl', 'q');
          #do
          #my $n = 0;
          #                              printlog( 'info', "ch1",  $q, $dc->{'host'});
          psmisc::schedule(
            $dc->{'search_every'},
            our $queueask_ ||= sub {
              my ($dc) = @_;
              my $q;
              while ( $q = shift @{ $work{'toask'} } or return ) {
                #++$n;
                #          ;
                #$work{''}
                #                              printlog( 'info', "ch2",  $q, $dc->{'host'});
                #local $config{'log_dmp'} = 1;
                my $r;
                $r =
                  $db->line( "SELECT * FROM results WHERE "
                    . ( ( length $q == 39 and $q =~ /^[0-9A-Z]+$/ ) ? 'tth' : 'string' ) . "="
                    . $db->quote($q)
                    . " ORDER BY time DESC LIMIT 1" ),
                  #              printlog( 'info', "checkbase", $q, Dumper($r), exists $work{'ask_db'}{$q})
                  if ( !exists $work{'asked'}{$q} and !exists $work{'ask_db'}{$q} );
                #              printlog( 'info', "already asked", $q, int (time - $r->{'time'})),
                $work{'ask_db'}{$q} = $work{'asked'}{$q} = $r->{'time'}, next
                  if $r and $r->{'time'};    # + $config{'ask_retry'} > time;
                     #              printlog( 'info', "checked ok", $q, ) unless exists $work{'ask_db'}{$q};
                $work{'ask_db'}{$q} = 0;
                last;
              }
              #                  printlog('dev', "q2", $q, $work{'ask'}{ $q }, Dumper $dc->{'search_todo'} );
              #if ($q and ++$work{'ask'}{ $q }  >= $config{'hit_to_ask'}  and !exists $work{'asked'}{ $q }) {
              if (
                !$dc->{'search_todo'}
                #and !@{$work{'toask'}||[]}
                )
              {
                $work{'asked'}{$q} = int time;
                printlog( 'info', "search", $q, 'on', $dc->{'host'} );
                $dc->search($q);
              } else {
                #printlog( 'info', "ups, todo full", $q, Dumper $dc->{'search_todo'}),
                unshift @{ $work{'toask'} }, $q;
              }
            },
            $dc
          );
#      'time'        'hub'         'size'        'users'
#        print Dumper( \%stat );
#every (10, our $dumpf ||= sub {if (open FO, '>', 'obj.log') {printlog("dumping dc");print FO Dumper(\%work, \%stat,);close FO;}});
#$dc
#$dc->log('hndl', 'Search_parse_aft', 'end');
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
          ( $s{nick}, $s{string} ) = $_[0] =~
            #/^<([^>]+)> (.+)$/s;
            /^(?:<|\* )(.+?)>? (.+)$/s;
          if ( $s{nick} and $s{string} ) {
            $db->insert_hash( 'chat', { %s, 'time' => int(time), 'hub' => $dc->{'hub'}, } );
          } else {
            printlog( 'err', 'wtf chat', @_ );
          }
        },
        'welcome' => sub {
          my $dc = shift;
          printlog( 'welcome', @_ );
        },
        'MyINFO' => sub {
          my $dc = shift;
          local ($_) = $_[0] =~ /\S+\s+(\S+)\s+(.*)/;
          #  print "my cool info parser gets info about $1 [$2]\n";
          #      local $Data::Dumper::Indent = 0;
          #      local $Data::Dumper::Terse  = 1;
          $db->insert_hash(
            'users', {
              'time' => int(time),
              'hub'  => $dc->{'hub'},
              'nick' => $_,
              'size' => $dc->{'NickList'}{$_}{'sharesize'},
              'ip'   => $dc->{'NickList'}{$_}{'ip'},
              'port' => $dc->{'NickList'}{$_}{'port'},
              'info' =>    #Dumper($dc->{'NickList'}{$_}),
                Data::Dumper->new( [ $dc->{'NickList'}{$_} ] )->Indent(0)->Terse(1)->Purity(1)->Dump(),
              'online' => int time
            }
          );
          #'time'   'hub'    'nick'   'ip'     'port'   'size' = 'online' 'info' =
        },
        'Quit' => sub {
          my $dc = shift;
          local $_ = $_[0];
          #      local $Data::Dumper::Indent = 0;
          #      local $Data::Dumper::Terse  = 1;
          $db->insert_hash(
            'users', {
              'time' => int(time),
              'hub'  => $dc->{'hub'},
              'nick' => $_,
              'size' => $dc->{'NickList'}{$_}{'sharesize'},
              'ip'   => $dc->{'NickList'}{$_}{'ip'},
              'port' => $dc->{'NickList'}{$_}{'port'},
              'info' => Data::Dumper->new( [ $dc->{'NickList'}{$_} ] )->Indent(0)->Terse(1)->Purity(1)->Dump,
              #Dumper($dc->{'NickList'}{$_}),
              'online' => 0
            }
          );
        },
        #      'To' => sub {        my $dc = shift;printlog('to', @_);},
      },
      %config,
    );
    #my %t = %{$dc->{'sql'}{'table'}{'users'}};
    #   tie %{$dc->{'sql'}{'table'}{'users'}}, 'hashwatch';
    #%{$dc->{'sql'}{'table'}{'users'}} = %t;
    #$dc->{'no_print'}{'SR'} => 1;
    #printlog 'info', "our version", $dc->{'V'};
    $dc->connect($hub);
    push @dc, $dc;
    $_->work() for @dc;
  }
}
#printlog "bots created, starting loop";
while ( my @dca = grep { $_->active() } @dc ) {
  #printlog "inloopb", @_;
  $_->work() for @dca;
  psmisc::schedule(
    [ 20, 60 * 60 ],    #
    our $hubstats_ ||= sub {
      my $time = int time;
      for my $dc (@_) {
        my @users = grep { $dc->{'NickList'}{$_}{'online'} } keys %{ $dc->{'NickList'} };
        my $share;
        #{
        #$dc->cmd( 'GetINFO', $_ ) for grep !$dc->{'NickList'}->{$_}{'info'}, keys %{ $dc->{'NickList'} };
        #$dc->cmd( 'GetINFO', grep {!$dc->{'NickList'}{$_}{'info'}} @users );
        $dc->cmd('GetINFO');
        #}
        for ( 1, 0 .. scalar(@users) / 1000 ) {
          $_->work(1) for @dca;
        }
        $dc->work(1);
        #printlog('us', $_, $dc->{'NickList'}{$_}{'sharesize'}, $share),
        $share += $dc->{'NickList'}{$_}{'sharesize'} for @users;
        printlog 'info', "hubsize $dc->{'hub'}: bytes = $share users=", scalar @users;
        $db->insert_hash( 'hubs', { 'time' => $time, 'hub' => $dc->{'hub'}, 'size' => $share, 'users' => scalar @users } )
          if $share;
        #$db->do()
      }
      $db->flush_insert('hubs');
    },
    ,
    @dc
  );
  psmisc::schedule(
    [ 60, 60 * 40 ],
    our $hubrunhour_ ||= sub {
      psmisc::startme('calc h');
    }
  );
  psmisc::schedule( [ 300, 60 * 60 * 6 ], our $hubrunrare_ ||= sub { psmisc::startme('calc r') } );
  #printlog "inloopa";
}
#printlog "afterloop";
#printlog "st:$_->{'status'}\n" for @dc;
#printlog "exiting";
$_->destroy() for @dc;
#}

=z
package hashwatch;
use Data::Dumper;    #dev only
sub TIEHASH  { bless {}, $_[0] }
sub STORE    { 
#print "store:", Dumper(\@_);
print "CREATING $_[1]=$_[2] from ",caller,"\n"unless exists $_[0]->{$_[1]};
$_[0]->{$_[1]} = $_[2] }
sub FETCH    { 
#print "fetch:", Dumper(\@_); 
print "CREATING $_[1]=$_[2] from ",caller,"\n"unless exists $_[0]->{$_[1]};
$_[0]->{$_[1]} }
sub FIRSTKEY { my $a = scalar keys %{$_[0]}; each %{$_[0]} }
sub NEXTKEY  { each %{$_[0]} }
sub EXISTS   { exists $_[0]->{$_[1]} }
sub DELETE   { delete $_[0]->{$_[1]} }
sub CLEAR    { %{$_[0]} = () }
sub SCALAR   { scalar %{$_[0]} }
=cut
