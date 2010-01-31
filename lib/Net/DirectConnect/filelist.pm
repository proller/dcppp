#$Id$ $URL$
package    #hide from cpan
  Net::DirectConnect::filelist;
use 5.10.0;
use strict;
use Encode;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
use base 'Net::DirectConnect';
use lib '../../../examples/stat/pslib';    # REMOVE
use lib 'stat/pslib';                      # REMOVE
use psmisc;                                # REMOVE
use pssql;                                 # REMOVE
my ( $tq, $rq, $vq );
sub                                        #init
  new {
  #my $self = ref $_[0] ? shift () : Net::DirectConnect->new(@_);
  my $standalone = !ref $_[0];
  my $self = ref $_[0] ? shift() : bless {}, $_[0];
  shift if $_[0] eq __PACKAGE__;
  #my $self =  shift () ;
  #$self =  Net::DirectConnect->new() unless ref $self;
#print 'params' ,join ', ',@_;
  %$self = ( %$self, @_ );
  $self->log( 'info','standalone, logs off'),
  $self->{log} = sub {}   if $standalone;
  #$self->baseinit();
  #$self->log( 'dev', 'inited:', "SA[$standalone]",Dumper($self, @_));
  #$self->{'parse'} ||= {};
  #$self->{'cmd'}   ||= {};
  #print join ' ', ( 'loading', __FILE__, __PACKAGE__, ref $self, 'caller=', caller );
#  $self->log( 'dev', 'loading', __FILE__, __PACKAGE__, ref $self );
  my ($shareloaded);
  $self->{no_sql}            //= 0;
  $self->{files}             //= 'files.xml';
  $self->{share_full}        //= {};
  $self->{share_tth}         //= {};
  $self->{chrarset_fs}       //= 'cp1251' if $^O ~~ 'MSWin32';
  $self->{chrarset_fs}       //= 'koi8r' if $^O ~~ 'freebsd';
  $self->{tth_cheat}         //= 1_000_000;                      #try find file with same name-size-date
  $self->{tth_cheat_no_date} //= 0;                              #--//-- only name-size
  $self->{file_min}          //= 0;                              #skip files  smaller
  $self->{filelist_scan}     //= 3600;                           #every seconds, 0 to disable
  $self->{filelist_reload}   //= 300;                            #check and load filelist if new, every seconds
  $self->{file_send_by}      //= 1024 * 1024 * 1;
##$config{share_root} //= '';
  tr{\\}{/} for @{ $self->{'share'} || [] };
  $self->{'sql'} //= {
    'driver' => 'sqlite',
    'dbname' => 'files.sqlite',
    #'auto_connect'        => 1,
    'log' => sub { shift if ref $_[0]; $self->log(@_) },
    #'cp_in'               => 'cp1251',
    'connect_tries' => 0, 'connect_chain_tries' => 0, 'error_tries' => 0, 'error_chain_tries' => 0,
    #insert_by => 1000,
    #nav_all => 1,
    'table' => {
      'filelist' => {
        'path' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 255, 'default' => '', 'index' => 1, 'primary' => 1 ),
        'file' => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 255, 'default' => '', 'index' => 1, 'primary' => 1 ),
        'tth'  => pssql::row( undef, 'type' => 'VARCHAR', 'length' => 40,  'default' => '', 'index' => 1 ),
        'size' => pssql::row( undef, 'type' => 'BIGINT',  'index'  => 1, ),
        'time' => pssql::row( 'time', ),    #'index' => 1,
        #'added'  => pssql::row( 'added', ),
        #'exists' => pssql::row( undef, 'type' => 'SMALLINT', 'index' => 1, ),
      },
    }
    },
    $self->{db} ||= pssql->new( %{ $self->{'sql'} || {} }, ), ( $tq, $rq, $vq ) = $self->{db}->quotes()
    unless $self->{no_sql};
  $self->{'cmd'}{filelist_make} //= sub {
    my $notth;
    return unless psmisc::lock( 'sharescan', timeout => 0, old => 86400 );
    $self->log( 'err', "sorry, cant load Net::DirectConnect::TigerHash for hashing" ), $notth = 1,
      unless psmisc::use_try 'Net::DirectConnect::TigerHash';    #( $INC{"Net/DirectConnect/TigerHash.pm"} );
    #$self->log( 'info',"ntth=[$notth]");    exit;
    my $stopscan;
    my $level     = 0;
    my $levelreal = 0;
    my ( $sharesize, $sharefiles );
    my $interrupted;
    my $printinfo = sub () {
      $self->log( 'sharesize', psmisc::human( 'size', $sharesize ), $sharefiles, scalar keys %{ $self->{share_full} } );
    };
    $SIG{INT} = sub { ++$stopscan; ++$interrupted; $self->log('warn',  "INT rec, stopscan") };
    $SIG{INFO} = sub { $printinfo->(); };
    psmisc::file_rewrite $self->{files}, qq{<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<FileListing Version="1" Base="/" Generator="Net::DirectConnect $Net::DirectConnect::VERSION">
};
#<FileListing Version="1" CID="KIWZDBLTOFWIQOT6NWP7UOPJVDE2ABYPZJGN5TZ" Base="/" Generator="Net::DirectConnect $Net::DirectConnect::VERSION">
#};
    my $filelist_line = sub($) {
      for my $f (@_) {
        next if !length $f->{file} or !length $f->{'tth'};
        $sharesize += $f->{size};
        ++$sharefiles if $f->{size};
        #$f->{file} = Encode::encode( 'utf8', Encode::decode( $self->{chrarset_fs}, $f->{file} ) ) if $self->{chrarset_fs};
        psmisc::file_append $self->{files}, "\t" x $level, qq{<File Name="$f->{file}" Size="$f->{size}" TTH="$f->{tth}"/>\n};
        #$self->{share_full}{ $f->{tth} } = $f->{full} if $f->{tth};    $self->{share_full}{ $f->{file} } ||= $f->{full};
        $f->{'full'} ||= $f->{'path'} . '/' . $f->{'file'};

=cu
      $self->{share_full}{ $f->{'tth'} } = $f->{'full_local'}, $self->{share_tth}{ $f->{'full_local'} } = $f->{'tth'},
        $self->{share_tth}{ $f->{'file'} } = $f->{'tth'},
        if $f->{'tth'};
      $self->{share_full}{ $f->{'file'} } ||= $f->{'full_local'};
=cut

  #$self->log 'set share', "[$f->{file}], [$f->{tth}] = [$self->{share_full}{ $f->{tth} }],[$self->{share_full}{ $f->{file} }]";
  #$self->log Dumper $self->{share_full};
      }
    };
    my $scandir;
    $scandir = sub (@) {
      for my $dir (@_) {
        $self->log( 'scandir', $dir, 'charset', $self->{chrarset_fs} );
#$self->log( 'warn', 'stopscan', $stopscan),
        last if $stopscan;
        $dir =~ tr{\\}{/};
        $dir =~ s{/+$}{};
        opendir( my $dh, $dir ) or ($self->log( 'err', "can't opendir $dir: $!\n" ), next);
#$self->log( 'dev','sd', __LINE__,$dh);

        #@dots =
        ( my $dirname = $dir );
        $dirname = Encode::encode 'utf8', Encode::decode $self->{chrarset_fs}, $dirname if $self->{chrarset_fs};
#$self->log( 'dev','sd', __LINE__,$dh);
        unless ($level) {
          for ( split '/', $dirname ) {
            psmisc::file_append( $self->{files}, "\t" x $level, qq{<Directory Name="$_">\n} ), ++$level, if length $_;
          }
        } else {
          $dirname =~
            #W s/^\w://;
            #$dirname =~
            s{.*/}{};
          psmisc::file_append( $self->{files}, "\t" x $level, qq{<Directory Name="$dirname">\n} ), ++$level, ++$levelreal,
            if length $dirname;
        }
#$self->log( 'dev','sd', __LINE__,$dh);
#        Net::DirectConnect::
        psmisc::schedule
        (
         [ 10, 10 ], 
         our $my_every_10sec_sub__ ||= 
         sub {
         $printinfo->() 
         }
          );
#$self->log( 'readdir', );
        for my $file ( readdir($dh) ) {
#          $self->log( 'scanfile', $file, );
#$self->log( 'warn', 'stopscan', $stopscan),
          last if $stopscan;
          next if $file =~ /^\.\.?$/;
          #$file = Encode::encode( 'utf8', Encode::decode( $self->{chrarset_fs}, $file ) ) if $self->{chrarset_fs};
          my $f = { path => $dir, path_local => $dir, file => $file, file_local => $file, full_local => "$dir/$file", };
          #$f->{full_local} = "$f->{path_local}/$f->{file_local}";
          #print("d $f->{full}:\n"),
          $f->{dir} = -d $f->{full_local};
          #filelist_line($f),
          $scandir->( $f->{full_local} ), next if $f->{dir};
          $f->{size} = -s $f->{full_local} if -f $f->{full_local};
          next if $f->{size} < $self->{file_min};
          $f->{file} = Encode::encode 'utf8', Encode::decode $self->{chrarset_fs}, $f->{file} if $self->{chrarset_fs};
          $f->{path} = Encode::encode 'utf8', Encode::decode $self->{chrarset_fs}, $f->{path} if $self->{chrarset_fs};
          $f->{full} = "$f->{path}/$f->{file}";
          $f->{time} = int( $^T - 86400 * -M $f->{full_local} );    #time() -
#$self->log 'timed', $f->{time}, psmisc::human('date_time', $f->{time}), -M $f->{full_local}, int (86400 * -M $f->{full_local}), $^T;
#'res=',
#join "\n",     grep { !/^\.\.?/ and
#/^\./ &&     -f "$dir/$_"     }
#print " ", $file;
#todo - select not all cols
          unless ( $self->{no_sql} ) {
            my $indb =
              $self->{db}->line( "SELECT * FROM ${tq}filelist${tq} WHERE"
                . " ${rq}path${rq}="
                . $self->{db}->quote( $f->{path} )
                . " AND ${rq}file${rq}="
                . $self->{db}->quote( $f->{file} )
                . " AND ${rq}size${rq}="
                . $self->{db}->quote( $f->{size} )
                . " AND ${rq}time${rq}="
                . $self->{db}->quote( $f->{time} )
                . " LIMIT 1" );
            #$self->log ('already scaned', $indb->{size}),
            $filelist_line->( { %$f, %$indb } ), next, if $indb->{size} ~~ $f->{size};
            #$db->select('filelist', {path=>$f->{path},file=>$f->{file}, });
            #$self->log Dumper ;
            #print "\n";
            #my $tth;
            if ( $f->{size} > $self->{tth_cheat} ) {
              my $indb =
                $self->{db}->line( "SELECT * FROM ${tq}filelist${tq} WHERE "
                  . "${rq}file${rq}="
                  . $self->{db}->quote( $f->{file} )
                  . " AND ${rq}size${rq}="
                  . $self->{db}->quote( $f->{size} )
                  . ( $self->{tth_cheat_no_date} ? () : " AND ${rq}time${rq}=" . $self->{db}->quote( $f->{time} ) )
                  . " LIMIT 1" );
              #$self->log 'sel', Dumper $indb;
              if ( $indb->{tth} ) {
                $self->log( 'dev', "already summed", %$f, '     as    ', %$indb );
                $f->{$_} ||= $indb->{$_} for keys %$indb;
                #filelist_line($f);
                #next;
              }
            }
          }
          if ( !$notth and !$f->{tth} ) {
            #$self->log 'calc', $f->{full}, "notth=[$notth]";
            my $time = time();
            $f->{tth} = Net::DirectConnect::TigerHash::tthfile( $f->{full_local} );
            my $per = time - $time;
            $self->log(
              'time', $f->{full}, psmisc::human( 'size', $f->{size} ),
              'per', psmisc::human( 'time_period', $per ),
              'speed ps', psmisc::human( 'size', $f->{size} / ( $per or 1 ) ),
              'total', psmisc::human( 'size', $sharesize )
              )
              if
              #$f->{size} > 100_000 or
              $per > 1;
          }
          #$f->{tth} = $f->{size} > 1_000_000 ? 'bigtth' : tthfile( $f->{full} );    #if -f $full;
          #print Dumper $self->{share_full};
          #next;
          #print ' ', tthfile($full) if -f $full ; #and -s $full < 1_000_000;
          #print ' ', $f->{tth};
          #print ' ', $f->{size};    #if -f $f->{full};
          #print join ':',-M $f->{full}, $^T + 86400 * -M $f->{full},$f->{time};
          #print "\n";
          $filelist_line->($f);
          $self->{db}->insert_hash( 'filelist', $f ) if !$self->{no_sql} and $f->{tth};
        }
        --$level;
        --$levelreal;
        psmisc::file_append $self->{files}, "\t" x $level, qq{</Directory>\n};    #<!-- $levelreal $level -->
        closedir $dh;
      }
      if ( $levelreal < 0 ) {
        #psmisc::file_append $self->{files}, "<!-- backing to root $levelreal $level -->\n";
        psmisc::file_append $self->{files}, "\t" x $level, qq{</Directory>\n} while --$level >= 0;
        $levelreal = $level = 0;
      }
      #$level
    };
    #else {
    $self->log('info', "making filelist $self->{files} from", grep { -d } @_, @{ $self->{'share'} || [] }, );
    $self->{db}->do('ANALYZE') unless $self->{no_sql};
    $scandir->($_) for ( grep { -d } @_, @{ $self->{'share'} || [] }, );
    undef $SIG{INT};
    undef $SIG{INFO};
    psmisc::file_append $self->{files}, qq{</FileListing>};
    psmisc::file_append $self->{files};
    $self->{db}->flush_insert() unless $self->{no_sql};

    if ( psmisc::use_try 'IO::Compress::Bzip2'
      and local $_ = IO::Compress::Bzip2::bzip2( $self->{files} => $self->{files} . '.bz2' )
      or $self->log("bzip2 failed: $IO::Compress::Bzip2::Bzip2Error") and 0 )
    {
      #$self->log 'bzip',$self->{files} => $self->{files} . '.bz2';
    } else {
      $self->log( 'dev', 'using system bzip2', $_, $!, ':', `bzip2 -f "$self->{files}"` );
    }
#unless $interrupted;
#$self->{share_full}{ $self->{files} . '.bz2' } = $self->{files} . '.bz2';  $self->{share_full}{ $self->{files} } = $self->{files};
#}
    psmisc::unlock('sharescan');
    $printinfo->();
    $SIG{INT} = $SIG{KILL} = undef;
    return ( $sharesize, $sharefiles );
  };
  $self->{'cmd'}{filelist_load} //= sub {
    my $self = shift if ref $_[0];

=old
  if ( $config{filelist} and open my $f, '<', $config{filelist} ) {
    $self->log "loading filelist..";
    local $/ = '<';
    while (<$f>) {
      if ( my ( $file, $time, $tiger ) = /^File Name="([^"]+)" TimeStamp="(\d+)" Root="([^"]+)"/i ) {
        #$self->{'share_tth'}{ $params->{TR} }
        $file =~ tr{\\}{/};
        $self->{share_full}{$tiger} = $file;
        $self->{share_tth}{$file}   = $tiger;
      }
      #<File Name="c:\distr\neo\tmp" TimeStamp="1242907656" Root="3OPSFH2JD2UPBV4KIZAPLMP65DSTMNZRTJCYR4A"/>
    }
    close $f;
    $self->log ".done:", ( scalar keys %{ $self->{share_full} } ), "\n";
  }
=cut

    $self->log( "filelist_load try", $shareloaded, -s $self->{files}, );    #ref $_[0]
    return
      if !$self->{files}
        or $shareloaded == -s $self->{files}
        or ( $shareloaded and !psmisc::lock( 'sharescan', readonly => 1, timeout => 0, old => 86400 ) )
        or !open my $f, '<', $self->{files};
    my ( $sharesize, $sharefiles );
    $self->log( "loading filelist", -s $f );
    $shareloaded = -s $f;
    local $/ = '<';
    %{ $self->{share_full} } = %{ $self->{share_tth} } = ();
    my $dir;

    while (<$f>) {
      #<Directory Name="distr">
      #<File Name="3470_2.x.rar" Size="18824575" TTH="CL3SVS5UWWSAFGKCQZTMGDD355WUV2QVLNNADIA"/>
      if ( my ( $file, $size, $tth ) = m{^File Name="([^"]+)" Size="(\d+)" TTH="([^"]+)"}i ) {
        my $full_local = ( my $full = "$dir/$file" );
        #$self->log 'loaded', $dir, $file  , $full;
        #$full_local = Encode::encode $self->{chrarset_fs}, $full if $self->{chrarset_fs};
        $full_local = Encode::encode $self->{chrarset_fs}, Encode::decode 'utf8', $full if $self->{chrarset_fs};
        $self->{share_full}{$tth} = $full_local, $self->{share_tth}{$full_local} = $tth, $self->{share_tth}{$file} = $tth,
          if $tth;
        $self->{share_full}{$file} ||= $full_local;
        ++$sharefiles;
        $sharesize += $size;
        #$self->{'share_tth'}{ $params->{TR} }
        #$file =~ tr{\\}{/};
      } elsif ( my ($curdir) = m{^Directory Name="([^"]+)">}i ) {
        $dir .= ( ( !length $dir and $^O ~~ [ 'MSWin32', 'cygwin' ] ) ? () : '/' ) . $curdir;
        #$self->log 'now in', $dir;
        #$self->{files}
      } elsif (m{^/Directory>}i) {
        $dir =~ s{(?:^|/)[^/]+$}{};
        #$self->log 'now ba', $dir;
      }
    }
    $self->{share_full}{ $self->{files} . '.bz2' } = $self->{files} . '.bz2';
    $self->{share_full}{ $self->{files} } = $self->{files};
    $self->log(
      "loaded filelist size",
      $shareloaded, ' : files=', $sharefiles, 'bytes=',
      psmisc::human( 'size', $sharesize ),
      scalar keys %{ $self->{share_full} }
    );
    psmisc::unlock('sharescan');
    #$_[0]->( $sharesize, $sharefiles ) if ref $_[0] ~~ 'CODE';
    #( $self->{share_size} , $self->{share_files} ) = ( $sharesize, $sharefiles );
    $self->{sharefiles} = $self->{INF}{SF} = $sharefiles, $self->{INF}{SS} = $self->{sharesize} = $sharesize, if $sharesize;
    return ( $sharesize, $sharefiles );
  };
  #($self->{share_size} = $self->{share_files} )=
  #print "\n pre fl load:", (caller)[0], '<>',  __PACKAGE__;
  $self->{'periodic'}{ __FILE__ . __LINE__ } = sub {
    #$self->log (  'periodic in filelist', $self->{filelist_scan});
    Net::DirectConnect::schedule(
      #[10, $self->{filelist_scan}],
      $self->{filelist_scan},
      our $sharescan_sub__ ||= sub {
        $self->log( 'filelist actual', -M $self->{files}, ( time - $^T + 86400 * -M $self->{files} ), $self->{filelist_scan} );
        return if -e $self->{files} and $self->{filelist_scan} > time - $^T + 86400 * -M $self->{files};
#        $self->log( 'starter==', $INC{'Net/DirectConnect/filelist.pm'}, $^X, 'share=', @{ $self->{'share'} } );
$0 ne 'share.pl' ?        psmisc::start $^X, $INC{'Net/DirectConnect/filelist.pm'}, @{ $self->{'share'} } :
        psmisc::startme( 'filelist', grep { -d } @ARGV );
      }
    ) if $self->{filelist_scan};
    #Net::DirectConnect::
    psmisc::schedule(
      #10,    #dev! 300!
      $self->{filelist_reload},
      #our $filelist_load_sub__ ||=
      sub {
        #psmisc::startme( 'filelist', grep { -d } @ARGV );
        #my($sharesize,$sharefiles) =
        $self->filelist_load(
          #sub {
          #my ( $sharesize, $sharefiles ) = @_;
          #$dc->{INF}{SS} = $sharesize, $dc->{INF}{SF} = $sharefiles, $dc->{sharesize} = $sharesize, if $sharesize;
##todo! change INF cmd or myinfo
          #}
        );
      }
    ) if $self->{filelist_scan};
    },
    #psmisc::startme( 'filelist', grep { -d } @ARGV )  if  !-e $config{files} or !-e $config{files}.'.bz2';
    $self->filelist_load() unless $standalone;    # (caller)[0] ~~ __PACKAGE__;
  $self->log('initok');
  return $self;
}
eval q{ #do
  use lib '../..';
  use Net::DirectConnect;
  #print "making\n";
  __PACKAGE__->new(@ARGV)->filelist_make(@ARGV),;
} unless caller;
1;
