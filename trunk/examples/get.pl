#!/usr/bin/perl
#$Id$ $URL$

=head1 NAME

 UNFINISHED!!! get files

=head1 SYNOPSIS

 ./get.pl hub file ...

 file:  topath/name:TTH:size

=head1 CONFIGURE 

 create config.pl:
 $config{dc}{host} = 'myhub.net';

=cut

use 5.10.0;
use strict;
use Data::Dumper;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
use Time::HiRes qw(time sleep);
#use Encode;
use lib '../lib';
#use lib '../TigerHash/lib';
use lib './stat/pslib';
our ( %config, %work );
use psmisc;
#use pssql;
use Net::DirectConnect;
#$config{disconnect_after}     //= 10;
#$config{disconnect_after_inf} //= 0;
$config{'hit_to_ask'}         = 1;
$config{'queue_recalc_every'} = 10;
$config{'get_every'}          = 10;
$config{ 'log_' . $_ } //= 0 for qw (dmp dcdmp dcdbg);
psmisc::config();    #psmisc::lib_init();
printlog("usage: $1 [adc|dchub://]host[:port] [hub..]\n"), exit if !$ARGV[0] and !$config{dc}{host} and !$config{dc}{hosts};
printlog( 'info', 'started:', $^X, $0, join ' ', @ARGV );
#$SIG{INT} = $SIG{KILL} = sub { printlog 'exiting', exit; };
#use Net::DirectConnect::adc;
#my $dc =
my $hub = $config{dc}{host} || shift @ARGV;
Net::DirectConnect->new(
  'host' => $hub,
  #modules  => ['filelist'],
  #SUPAD        => { H => { PING => 1 } },
  #botinfo      => 'devperlpinger',
  #auto_GetINFO => 1,
  auto_connect => 1,
  dev_http     => 1,
  'log'        => sub (@) {
    my $dc = ref $_[0] ? shift : {};
    psmisc::printlog shift(), "[$dc->{'number'}]", @_,;
  },
  'handler' => { (
      map {
        my $msg = $_;
        $msg => sub {
          my $dc = shift;
          say join ' ', $msg, @_;
          },
        } qw(welcome chatline To)
    ),
    'Search_parse_aft' => sub {
      my $dc = shift;
      printlog 'sch', Dumper @_ if $dc->{adc};
      my $who    = shift if $dc->{adc};
      my $search = shift if $dc->{nmdc};
      my $s = $_[0] || {};
      $s = pop if $dc->{adc};
      return if $dc->{nmdc} and $s->{'nick'} eq $dc->{'Nick'};
      $dc->{__work} ||= \%work;    #for dumper
      #my $q = $s->{'tth'} || $s->{'string'} || $s->{'TR'} || $s->{'AN'} || return;
      my $q = $s->{'tth'} || $s->{'TR'} || return;
      ++$work{'ask'}{$q};
      ++$work{'stat'}{'Search'};
    },
    'SR_parse_aft' => sub {
      my $dc = shift;
      my %s = %{ $_[1] || return };
      #printlog 'SRparsed:', Dumper \%s;
      #$db->insert_hash( 'results', \%s );
      ++$work{'filename'}{ $s{tth} }{ $s{filename} };
      $work{'tthfrom'}{ $s{tth} }{ $s{nick} } = \%s;
      ++$work{'stat'}{'SR'};
    },
  },
  auto_work => sub {
    my $dc = shift;
    psmisc::schedule(
      $config{'queue_recalc_every'},
      our $queuerecalc_ ||= sub {
        my $time = int time;
        $work{'toask'} = [ (
            sort { $work{'ask'}{$b} <=> $work{'ask'}{$a} }
            grep { $work{'ask'}{$_} >= $config{'hit_to_ask'} and !exists $work{'asked'}{$_} } keys %{ $work{'ask'} }
          )
        ];
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
          last if ( !exists $work{'asked'}{$q} );
#$work{'ask_db'}{$q} = $work{'asked'}{$q} = $r->{'time'}, next                  if $r and $r->{'time'};    # + $config{'ask_retry'} > time;
#$work{'ask_db'}{$q} = 0;
#last;
        }
        return unless length $q;
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
    psmisc::schedule(
      $config{'get_every'},
      sub {
        for my $tth ( sort { keys %{ $work{'filename'}{$a} } <=> keys %{ $work{'filename'}{$b} } } keys %{ $work{'filename'} } )
        {
          #++$work{'filename'}{$s{tth}}{$s{filename}};
          my ($filename) =
            sort { $work{'filename'}{$tth}{$a} <=> $work{'filename'}{$tth}{$b} } keys %{ $work{'filename'}{$tth} };
          printlog(
            'selected tth', $tth, 'names=', keys %{ $work{'filename'}{$tth} },
            'filename=', $filename, $work{'filename'}{$tth}{$filename},
            'nicks=', keys %{ $work{'tthfrom'}{$tth} }
          );
          my ($from) = grep { $_->{slotsopen} } values %{ $work{'tthfrom'}{$tth} };
          printlog( 'selected from', Dumper $from);
          $dc->get( $from->{nick}, 'TTH/' . $tth, $filename );
          delete $work{'filename'}{$tth};
          #$work{'tthfrom'}{$s{tth}}
          last;
        }
      }
    );
    psmisc::schedule(
      [ 10, 99999999 ],
      #our $dump_sub__ ||=
      sub { $dc->search($_) for @ARGV or 'UU6VHFYNDX7HEKCOIXNPQEVS3HRRQHHPPGN2AVY'; }
    );
    psmisc::schedule(
      [ 20, 100 ],
      our $dump_sub__ ||= sub {
        printlog "Writing dump";
        psmisc::file_rewrite( $0 . '.dump', Dumper $dc);
      }
    ) if $config{debug};
  },
  %{ $config{dc} || {} },
  #( $_ ? ( 'host' => $_ ) : () ),
  #( $ARGV[0] ? ( 'host' => $ARGV[0] ) : () ),
);    # for ( @ARGV, @{ $config{dc}{hosts} || [] } );
