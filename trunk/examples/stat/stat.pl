#!/usr/bin/perl
#$Id$ $URL$
package statpl;
use strict;
no warnings qw(uninitialized);
our ( %config, $param, $db, );
use statlib;
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
use psmisc;
our $root_path;
use lib $root_path. '../../lib';
use lib $root_path. './';
use Net::DirectConnect;
$config{'queue_recalc_every'} ||= 60;
$static{'no_sig_log'} = 1;    #test
print(
  "usage:
 $0 [--configParam=configValue] [adc|dchub://]host[:port] [more params and hubs]\n
 $0 calc[h|d|w|m]|[r]	-- calculate slow stats for all times or hour..day... r=d+w+m\n
"
  ),
  exit
  if !$ARGV[0];
my $n = -1;

my ( $tq, $rq, $vq ) = $db->quotes();

for my $arg (@ARGV) {
  ++$n;
  #print "ar[$arg]";
  if ( ( $a = $arg ) =~ s/^-+// ) {
    my ( $w, $v ) = split /=/, $a;
    #print "arvw[$v, $w]";
    #next unless $w =~ s/^-//;
    #my $where = ( $w =~ s/^-// ? '$config' : '$svc' );
    #$v =~ s/^NUL$//;
    #next unless defined($w) and defined($v);
    $v = 1 unless defined $v;
    local @_ = split( /__/, $w ) or next;
    #print '$config' . join( '', map { '{$_[' . $_ . ']}' } ( 0 .. $#_ ) ) . ' = $v;';
    eval( '$config' . join( '', map { '{$_[' . $_ . ']}' } ( 0 .. $#_ ) ) . ' = $v;' );
  } elsif ( $arg =~ /^calc(\w)?$/i ) {
    my $tim = $1;
    $ARGV[$n] = undef;
    local $db->{'cp_in'} = 'utf-8';
    #local $config{'log_dmp'}=1;
    my $nowtime = int time();
    for my $query ( sort keys %{ $config{'queries'} } ) {
      next if $config{'queries'}{$query}{'disabled'};
      next unless statlib::is_slow($query);
      for my $time (
        $config{'queries'}{$query}{'periods'}
        ? ( ( $tim ne 'r' ? $tim : () )
            or sort { $config{'periods'}{$a} <=> $config{'periods'}{$b} } keys %{ $config{'periods'} } )
        : ('')
        )
      {
        next if $tim eq 'r' and ( !$config{'queries'}{$query}{'periods'} or $time eq 'h' );
        printlog 'info', 'calculating ', $time, $query;
        local $config{'queries'}{$query}{'WHERE'}[5] =
          $config{'queries'}{$query}{'FROM'} . ".time >= " . int( time - $config{'periods'}{$time} )
          if $time;
        my $res = statlib::make_query( { %{ $config{'queries'}{$query} }, }, $query );
        my $n = 0;
        for my $row (@$res) {
          ++$n;
          my $dmp = Data::Dumper->new( [$row] )->Indent(0)->Pair('=>')->Terse(1)->Purity(1)->Dump();
          $db->insert_hash( 'slow', { 'name' => $query, 'n' => $n, 'result' => $dmp, 'period' => $time, 'time' => int(time) } )
            if $config{'use_slow'};
          #if ( $time eq 'd' ) {
          my $table = $query . '_' . $time;
          $table =~ s/\s/_/g;
          $db->insert_hash( $table, { 'n' => $n, 'date' => psmisc::human('date'), %$row, 'time' => $nowtime } );
          #}
        }
        $db->do( "DELETE FROM ${tq}slow${tq} WHERE name=" . $db->quote($query) . " AND period=" . $db->quote($time) . " AND n>$n " )
          if $config{'use_slow'};
        #$db->flush_insert('slow');
        $db->flush_insert();
        #sleep 3;
      }
    }
    #exit;
  } elsif ( $arg eq 'purge' ) {
    $ARGV[$n] = undef;
    for my $table ( sort keys %{ $config{'sql'}{'table'} } ) {
      #print "$table  \n";
      my ($col) = grep { $config{'sql'}{'table'}{$table}{$_}{'purge'} } keys %{ $config{'sql'}{'table'}{$table} };
        #printlog('err', "no col in [$table]", Dumper $config{'sql'}{'table'}{$table}), 
	next unless $col;
	my $purge = $config{'sql'}{'table'}{$table}{$col}{'purge'};
      #print "t $table c$col p$purge \n";
      $purge = $config{'purge'} if $purge and $purge <= 1;
      printlog 'info', "purge $table $col $purge =", $db->do( "DELETE FROM $tq$table$tq WHERE $col < " . int( time - $purge ) );
    }
    $db->optimize() unless $config{'no_auto_optimize'};
  } elsif ( $arg eq 'install' ) {
    $ARGV[$n] = undef;
    local $db->{error_sleep} = 0;
    $db->install();
    $db->create_indexes();
  } elsif ( $arg eq 'upgrade' ) {
    $ARGV[$n] = undef;
    #$db->do( "DROP TABLE $_")       for qw(queries_top_string_daily queries_top_tth_daily results_top_daily);
    local $db->{'auto_install'} = 0;
    local $db->{'error_sleep'}  = 0;
    #my ( $tq, $rq, $vq ) = $db->quotes();

=old 
    $db->do( "DROP TABLE ${_}d")    for qw(queries_top_string_ queries_top_tth_ results_top_);
    $db->do("ALTER TABLE queries_top_string_daily RENAME TO queries_top_string_d");
    $db->do("ALTER TABLE queries_top_tth_daily RENAME TO queries_top_tth_d");
    $db->do("ALTER TABLE results_top_daily RENAME TO results_top_d");

    for my $p ( sort keys %{ $config{'periods'} } ) {
      0,
        #$db->do("ALTER TABLE $_$p CHANGE COLUMN ${rq}date${rq} ${rq}time${rq} VARCHAR(10) DEFAULT $vq$vq")
        #$db->do("ALTER TABLE $_$p CHANGE COLUMN ${rq}time${rq}  ${rq}date${rq} VARCHAR(10) DEFAULT $vq$vq")
        #$db->do("ALTER TABLE $_$p CHANGE COLUMN ${rq}time${rq}  ${rq}date${rq} VARCHAR(10) DEFAULT $vq$vq")
        $db->do("ALTER TABLE $_$p ADD COLUMN  `time` INT  UNSIGNED NOT NULL  DEFAULT '0'")
        for qw(queries_top_string_ queries_top_tth_ results_top_);
    }
=cut

  } elsif ( $arg eq 'stat' ) {
    $ARGV[$n] = undef;
      $db->{'auto_repair'}  = 1;
      $db->{'force_repair'} = 1;
    $db->table_stat();
  } elsif ( $arg eq 'check' ) {
    $ARGV[$n] = undef;
      $db->{'auto_repair'}  = 1;
      $db->{'force_repair'} = 1;
    $db->check();
  }
}
our %work;
our @dc;

sub close_all {
  flush_all();
  $db->disconnect();
  $_->destroy() for @dc;
  psmisc::caller_trace(5);
  printlog "bye close_all";
  exit;
}
sub flush_all { $db->flush_insert(); }

sub print_info {
  printlog( 'info', "queue len=", scalar @{ $work{'toask'} || [] }, " first hits=", $work{'ask'}{ $work{'toask'}[0] } );
  local @_ = grep { $_ and $_->active() } @dc;
  printlog 'info', 'active hubs:', map { $_->{'host'} . ':' . $_->{'status'} } @_;
  printlog 'info', 'hashes:',      map { $_ . '=' . scalar %{ $work{$_} || {} } } qw(ask asked ask_db);
  printlog 'info', 'stat:',        map { $_ . '=' . $work{'stat'}{$_} } keys %{ $work{'stat'} || {} };
  #psmisc::file_rewrite(    'dumper',    Dumper [      'work' => \%work,      'db'   => $db,      'dc'   => \@dc,    ]  );
  if ( $^O =~ /win/i ) {
    our $__hup_time__;
    printlog( 'info', 'doubleclose, bye' ), exit if time - $__hup_time__ < 2;
    $__hup_time__ = time;
  }
}
local $SIG{INT} = $SIG{__DIE__} = \&close_all;
local $SIG{HUP}      = $^O =~ /win/i ? \&print_info : \&flush_all;
local $SIG{INFO}     = \&print_info;
local $SIG{__WARN__} = sub {
  printlog( 'warn', $!, $@, @_ );
  #printlog( 'die', 'caller', $_, caller($_) ) for ( 0 .. 15 );
  psmisc::caller_trace(15);
};
local $SIG{__DIE__} = sub {
  printlog( 'die', $!, $@, @_ );
  #printlog( 'die', 'caller', $_, caller($_) ) for ( 0 .. 15 );
  psmisc::caller_trace(5);
};
for ( grep { length $_ } @ARGV ) {
  local @_;
  if ( /^-/ and @_ = split '=', $_ ) {
    $config{config_file} = $_[1], psmisc::config() if $_[0] eq '--config';
    psmisc::program_one( 'params_pre_config', @_[ 1, 0 ] );
  } else {
    my $hub = $_;
    ++$work{'hubs'}{$hub};
    my $dc = Net::DirectConnect->new(
      'host'      => $hub,
      'Nick'      => 'dcstat',
      'sharesize' => 40_000_000_000 + int( rand 10_000_000_000 ),
      #'log'		=>	sub {},	# no logging
      #'log'          => sub { my $dc = shift; psmisc::printlog( "[$dc->{'number'}]($dc)", @_);
      'log' => sub {
        my $dc = shift if ref $_[0];
        local $_ = shift;
        psmisc::printlog( $_, "[$dc->{'number'}]", @_ );
        #psmisc::caller_trace(5)
      },
      'myport'      => 41111,
      'description' => 'http://dc.proisk.ru/dcstat/',
      #'auto_connect' => 0,
      'reconnects' => 500,
      'handler'    => {
        #'Search_parse_aft' => sub {
		'Search' => sub {
          my $dc = shift;
          printlog 'sch', Dumper @_ if $dc->{adc};
          my $who    = shift if $dc->{adc};
          my $search = shift if $dc->{nmdc};
          my $s = $_[0] || {};
          $s = pop if $dc->{adc};
          return if $dc->{nmdc} and $s->{'nick'} eq $dc->{'Nick'};
          $db->insert_hash(
            'queries', { (
                $dc->{nmdc} ? () : (
                  'time'   => int time,
                  'hub'    => $dc->{'hub_name'},
                  'nick'   => $dc->{peers_sid}{ $who->[1] }{INF}{NI},
                  'ip'     => $dc->{peers_sid}{ $who->[1] }{INF}{I4},
                  'port'   => $dc->{peers_sid}{ $who->[1] }{INF}{U4},
                  'tth'    => $s->{TR},
                  'string' => $s->{AN},                                 #!!!
                )
              ),
              %$s
            }
          );
          my $q = $s->{'tth'} || $s->{'string'} || $s->{'TR'} || $s->{'AN'} || return;
          ++$work{'ask'}{$q};
          ++$work{'stat'}{'Search'};
          psmisc::schedule(
            $config{'queue_recalc_every'},
            our $queuerecalc_ ||= sub {
              my $time = int time;
              $work{'toask'} = [ (
                  sort { $work{'ask'}{$b} <=> $work{'ask'}{$a} }
                  grep { $work{'ask'}{$_} >= $config{'hit_to_ask'} and !exists $work{'asked'}{$_} } keys %{ $work{'ask'} }
                )
              ];
              printlog( 'warn', "reasking" ), $work{'toask'} = [ (
                  sort { $work{'ask'}{$b} <=> $work{'ask'}{$a} } grep {
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
          psmisc::schedule(
            [ 3600, 3600 ],
            our $hashes_cleaner_ ||= sub {
              my $min = scalar keys %{ $work{'hubs'} || {} };
              printlog 'info', "queue clear min[$min] now", scalar %{ $work{'ask'} || {} };
              delete $work{'ask'}{$_} for grep { $work{'ask'}{$_} < $min } keys %{ $work{'ask'} || {} };
              printlog 'info', "queue clear ok now", scalar %{ $work{'ask'} || {} };
            }
          );
          psmisc::schedule(
            $dc->{'search_every'},
            our $queueask_ ||= sub {
              my ($dc) = @_;
              my $q;
              while ( $q = shift @{ $work{'toask'} } or return ) {
                my $r;
                $r =
                  $db->line( "SELECT * FROM results WHERE "
                    . ( ( length $q == 39 and $q =~ /^[0-9A-Z]+$/ ) ? 'tth' : 'string' ) . "="
                    . $db->quote($q)
                    . " ORDER BY time DESC LIMIT 1" ),
                  if ( !exists $work{'asked'}{$q} and !exists $work{'ask_db'}{$q} );
                $work{'ask_db'}{$q} = $work{'asked'}{$q} = $r->{'time'}, next
                  if $r and $r->{'time'};    # + $config{'ask_retry'} > time;
                $work{'ask_db'}{$q} = 0;
                last;
              }
              if ( !$dc->{'search_todo'} ) {
                $work{'asked'}{$q} = int time;
                printlog( 'info', "search", $q, 'on', $dc->{'host'} );
                $dc->search($q);
              } else {
                unshift @{ $work{'toask'} }, $q;
              }
            },
            $dc
          );
        },
        #'SR_parse_aft' => sub {
        'SR' => sub {
          my $dc = shift;
          my %s = %{ $_[1] || return };
          $db->insert_hash( 'results', \%s );
          ++$work{'stat'}{'SR'};
        },
        'chatline' => sub {
          my $dc = shift;
          printlog( 'chatline', @_ );
          my %s;
          ( $s{nick}, $s{string} ) = $_[0] =~
            #/^<([^>]+)> (.+)$/s;
            /^(?:<|\* )(.+?)>? (.+)$/s;
          if ( $s{nick} and $s{string} ) {
            $db->insert_hash( 'chat', { %s, 'time' => int(time), 'hub' => $dc->{'hub_name'}, } );
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
          $db->insert_hash(
            'users', {
              'time'   => int(time),
              'hub'    => $dc->{'hub_name'},
              'nick'   => $_,
              'size'   => $dc->{'NickList'}{$_}{'sharesize'},
              'ip'     => $dc->{'NickList'}{$_}{'ip'},
              'port'   => $dc->{'NickList'}{$_}{'port'},
              'info'   => Data::Dumper->new( [ $dc->{'NickList'}{$_} ] )->Indent(0)->Pair('=>')->Terse(1)->Purity(1)->Dump(),
              'online' => int time
            }
          );
          ++$work{'stat'}{'MyINFO'};
        },
        'Quit' => sub {
          my $dc = shift;
          local $_ = $_[0];
          $db->insert_hash(
            'users', {
              'time'   => int(time),
              'hub'    => $dc->{'hub_name'},
              'nick'   => $_,
              'size'   => $dc->{'NickList'}{$_}{'sharesize'},
              'ip'     => $dc->{'NickList'}{$_}{'ip'},
              'port'   => $dc->{'NickList'}{$_}{'port'},
              'info'   => Data::Dumper->new( [ $dc->{'NickList'}{$_} ] )->Indent(0)->Terse(1)->Purity(1)->Dump,
              'online' => 0
            }
          );
          ++$work{'stat'}{'Quit'};
        },
        #'To' => sub {        my $dc = shift;printlog('to', @_);},
        'INF' => sub {
          my $dc = shift;
          #printlog 'inf', Dumper @_;
          my $params = pop;
          #local ($_) = $_[0] =~ /\S+\s+(\S+)\s+(.*)/;
          #=c
          $db->insert_hash(
            'users', {
              'time' => int(time),
              'hub'  => $dc->{'hub_name'},
              'nick' => $params->{NI},
              'size' => $params->{SS},
              'ip'   => $params->{I4},
              'port' => $params->{U4},
              'info' => Data::Dumper->new( [$params] )->Indent(0)->Pair('=>')->Terse(1)->Purity(1)->Dump(),
              #maybe full from peers ?
              'online' => int time
            }
          );
          #=cut
          ++$work{'stat'}{'INF'};
        },
        'QUI' => sub {
          my $dc = shift;
          local $_ = $_[0];
          printlog 'qui', Dumper @_;

=c
          $db->insert_hash(
            'users', {
              'time'   => int(time),
              'hub'    => $dc->{'hub_name'},
              'nick'   => $_,
              'size'   => $dc->{'NickList'}{$_}{'sharesize'},
              'ip'     => $dc->{'NickList'}{$_}{'ip'},
              'port'   => $dc->{'NickList'}{$_}{'port'},
              'info'   => Data::Dumper->new( [ $dc->{'NickList'}{$_} ] )->Indent(0)->Terse(1)->Purity(1)->Dump,
              'online' => 0
            }
          );
=cut

          ++$work{'stat'}{'QUI'};
        },
        'RES' => sub {
          #$db->insert_hash( 'results', \%s );
          ++$work{'stat'}{'RES'};
        },
      },
      %config,
    );
    #$dc->connect($hub);
    #$dc->{'handler'}{'SCH_parse_aft'} = $dc->{'handler'}{'Search_parse_aft'};
    $dc->{'handler'}{'SCH'} = $dc->{'handler'}{'Search'};

=no    
	$dc->{'clients'}{'listener_http'}{'handler'}{''} = sub {
      my $dc = shift;
      printlog "my cool cansend [$dc->{'geturl'}]";
      $dc->{'socket'}->send( "Content-type: text/html\n\n" . "hi" );
      #$dc->{'socket'}->close();
      $dc->destroy();
    };
=cut	

    push @dc, $dc;
    $_->work() for @dc;
  }
}
while ( my @dca = grep { $_ and $_->active() } @dc ) {
  $_->work() for @dca;
  psmisc::schedule(
    [ 20, 60 * 60 ],
    our $hubstats_ ||= sub {
      my $time = int time;
      for my $dc (@_) {
        my @users =
          $dc->{nmdc}
          ? ( grep { $dc->{'NickList'}{$_}{'online'} } keys %{ $dc->{'NickList'} } )
          : ( keys %{ $dc->{'peers_sid'} } );
        my $share;
        if ( $dc->{'nmdc'} ) {
          $dc->cmd('GetINFO');
          for ( 1, 0 .. scalar(@users) / 1000 ) { $_->work(1) for @dca; }
        }
        $dc->work(1);
        if   ( $dc->{nmdc} ) { $share += $dc->{'NickList'}{$_}{'sharesize'} for @users; }
        else                 { $share += $dc->{'peers_sid'}{$_}{INF}{'SS'}  for @users; }
        printlog 'info', "hubsize $dc->{'hub_name'}: bytes = $share users=", scalar @users;
        $db->insert_hash( 'hubs', { 'time' => $time, 'hub' => $dc->{'hub_name'}, 'size' => $share, 'users' => scalar @users } )
          if $share;
      }
      $db->flush_insert('hubs');
    },
    ,
    @dc
  );
  psmisc::schedule( [ 300, 60 * 40 ], our $hubrunhour_ ||= sub { psmisc::startme('calch'); } ),
    psmisc::schedule( [ 600, 60 * 60 * 6 ], our $hubrunrare_ ||= sub { psmisc::startme('calcr'); } )
    if $config{'use_slow'};
#psmisc::schedule( [ 60 * 3, 60 * 60 * 24 ], our $hubrunoptimize_ ||= sub { psmisc::startme('calcr'); } )    if $config{'auto_optimize'};
  psmisc::schedule( [ 900, 86400 ], $config{'purge'} / 10, our $hubrunpurge_ ||= sub { psmisc::startme('purge'); } );

=z
   psmisc::schedule(
    [ 10, 100 ],
    our $dump_sub__ ||= sub {
      print "Writing dump\n";
      psmisc::file_rewrite( 'dump', Dumper @dc);
    }
  );
=cut

}
printlog 'dev', map { $_->{'host'} . ":" . $_->{'status'} } @dc;
#psmisc::caller_trace(20);
$_->destroy() for @dc;
printlog 'info', 'bye', times;
