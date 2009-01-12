#!/usr/bin/perl
# $Id: stat.pm 383 2009-01-08 03:47:59Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/examples/stat/stat.pm $
package statpl;
use strict;
no warnings qw(uninitialized);
our ( %config, $param, $db, );
use statlib;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
use psmisc;
our $root_path;
use lib $root_path. '../../lib';
use lib $root_path. './';
use Net::DirectConnect::clihub;
$config{'queue_recalc_every'} ||= 60;
print(
  "usage:
 stat.pl [--configParam=configValue] [dchub://]host[:port] [more params and hubs]\n
 stat.pl calc [h|d|w|m]|[r]	-- calculate slow stats for all times or hour..day... r=d+w+m\n
"
  ),
  exit
  if !$ARGV[0];

if ( $ARGV[0] eq 'calc' ) {
  local $db->{'cp_in'} = 'utf-8';
  #local $config{'log_dmp'}=1;
  for my $query ( sort keys %{ $config{'queries'} } ) {
    next if $config{'queries'}{$query}{'disabled'};
    next
      unless statlib::is_slow($query);
    for my $time (
      $config{'queries'}{$query}{'periods'}
      ? ( ( $ARGV[1] ne 'r' ? $ARGV[1] : () )
          or sort { $config{'periods'}{$a} <=> $config{'periods'}{$b} } keys %{ $config{'periods'} } )
      : ('')
      )
    {
      next if $ARGV[1] eq 'r' and ( !$config{'queries'}{$query}{'periods'} or $time eq 'h' );
      printlog 'info', 'calculating ', $time, $query;
      local $config{'queries'}{$query}{'WHERE'}[5] =
        $config{'queries'}{$query}{'FROM'} . ".time >= " . int( time - $config{'periods'}{$time} )
        if $time;
      my $res = statlib::make_query( { %{ $config{'queries'}{$query} }, }, $query );
      my $n = 0;
      for my $row (@$res) {
        ++$n;
        my $dmp = Data::Dumper->new( [$row] )->Indent(0)->Terse(1)->Purity(1)->Dump();
        $db->insert_hash( 'slow', { 'name' => $query, 'n' => $n, 'result' => $dmp, 'period' => $time, 'time' => int(time) } );
      }
      $db->do( "DELETE FROM slow WHERE name=" . $db->quote($query) . " AND period=" . $db->quote($time) . " AND n>$n " );
      $db->flush_insert('slow');
      sleep 3;
    }
  }
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

sub print_info {
  printlog( 'info', "queue len=", scalar @{ $work{'toask'} || [] }, " first hits=", $work{'ask'}{ $work{'toask'}[0] } );
  local @_ = grep { $_->active() } @dc;
  printlog 'info', 'active hubs:', map { $_->{'host'} . ':' . $_->{'status'} } @_;
  printlog 'info', 'hashes:', map { $_ . '=' . scalar %{ $work{$_} || {} } } qw(ask asked ask_db);
  #  psmisc::file_rewrite(    'dumper',    Dumper [      'work' => \%work,      'db'   => $db,      'dc'   => \@dc,    ]  );
}
$SIG{INT} = $SIG{__DIE__} = \&close_all;
$SIG{HUP} =
  $^O =~ /win/i
  ? \&print_info
  : \&flush_all;
$SIG{INFO} = \&print_info;
for (@ARGV) {
  local @_;
  if ( /^-/ and @_ = split '=', $_ ) {
    $config{config_file} = $_[1], psmisc::config() if $_[0] eq '--config';
    psmisc::program_one( 'params_pre_config', @_[ 1, 0 ] );
  } else {
    my $hub = $_;
    my $dc  = Net::DirectConnect::clihub->new(
      'Nick'      => 'dcstat_dev',
      'sharesize' => 40_000_000_000 + int( rand 10_000_000_000 ),
      #   'log'		=>	sub {},	# no logging
      'log'          => sub { psmisc::printlog(@_) },
      'myport'       => 41111,
      'description'  => 'http://dc.proisk.ru/dcstat/',
      'auto_connect' => 0,
      'reconnects'   => 500,
      'handler'      => {
        'Search_parse_aft' => sub {
          my $dc     = shift;
          my $search = shift;
          my %s      = ( %{ $_[0] }, );
          return if $s{'nick'} eq $dc->{'Nick'};
          $db->insert_hash( 'queries', \%s );
          my $q = $s{'tth'} || $s{'string'} || return;
          ++$work{'ask'}{$q};
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
        'SR_parse_aft' => sub {
          my $dc = shift;
          my %s = %{ $_[1] || return };
          $db->insert_hash( 'results', \%s );
        },
        'chatline' => sub {
          my $dc = shift;
          printlog( 'chatline', @_ );
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
          $db->insert_hash(
            'users', {
              'time'   => int(time),
              'hub'    => $dc->{'hub'},
              'nick'   => $_,
              'size'   => $dc->{'NickList'}{$_}{'sharesize'},
              'ip'     => $dc->{'NickList'}{$_}{'ip'},
              'port'   => $dc->{'NickList'}{$_}{'port'},
              'info'   => Data::Dumper->new( [ $dc->{'NickList'}{$_} ] )->Indent(0)->Terse(1)->Purity(1)->Dump(),
              'online' => int time
            }
          );
        },
        'Quit' => sub {
          my $dc = shift;
          local $_ = $_[0];
          $db->insert_hash(
            'users', {
              'time'   => int(time),
              'hub'    => $dc->{'hub'},
              'nick'   => $_,
              'size'   => $dc->{'NickList'}{$_}{'sharesize'},
              'ip'     => $dc->{'NickList'}{$_}{'ip'},
              'port'   => $dc->{'NickList'}{$_}{'port'},
              'info'   => Data::Dumper->new( [ $dc->{'NickList'}{$_} ] )->Indent(0)->Terse(1)->Purity(1)->Dump,
              'online' => 0
            }
          );
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
while ( my @dca = grep { $_->active() } @dc ) {
  $_->work() for @dca;
  psmisc::schedule(
    [ 20, 60 * 60 ],
    our $hubstats_ ||= sub {
      my $time = int time;
      for my $dc (@_) {
        my @users = grep { $dc->{'NickList'}{$_}{'online'} } keys %{ $dc->{'NickList'} };
        my $share;
        $dc->cmd('GetINFO');
        for ( 1, 0 .. scalar(@users) / 1000 ) {
          $_->work(1) for @dca;
        }
        $dc->work(1);
        $share += $dc->{'NickList'}{$_}{'sharesize'} for @users;
        printlog 'info', "hubsize $dc->{'hub'}: bytes = $share users=", scalar @users;
        $db->insert_hash( 'hubs', { 'time' => $time, 'hub' => $dc->{'hub'}, 'size' => $share, 'users' => scalar @users } )
          if $share;
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
    ),
    psmisc::schedule(
    [ 300, 60 * 60 * 6 ],
    our $hubrunrare_ ||= sub {
      psmisc::startme('calc r');
    }
    ) if $config{'use_slow'};
}
$_->destroy() for @dc;
