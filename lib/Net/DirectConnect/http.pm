#$Id$ $URL$
package    #hide from cpan
  Net::DirectConnect::http;
use Data::Dumper;    #dev only
#$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
use Net::DirectConnect;
#use Net::DirectConnect::hubcli;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
#our @ISA = ('Net::DirectConnect');
use base 'Net::DirectConnect';

sub init {
  my $self = shift;
  $self->log( 'dev', 'httpcli init' );
  %$self = (
    %$self,
    #
    #'incomingclass' => 'Net:DirectConnect::httpcli',
    'auto_connect' => 0, 'auto_listen' => 0, 'protocol' => 'http',
    #'myport'        => 80,
    #'myport_base'   => 8000,
    #'myport_random' => 99,
    #'myport_tries'  => 5,
    #'HubName'       => 'Net::DirectConnect test hub',
    @_
  );
  #$self->baseinit();
  #$self->{'parse'} ||= $self->{'parent'}{'parse'};
  #$self->{'cmd'}   ||= $self->{'parent'}{'cmd'};
  $self->{'handler_int'}{'unknown'} ||= sub {
    my $self = shift if ref $_[0];
    $self->log( 'dev', "unknown1", @_ );
    #};
  };
  #$self->{'handler'}{  'unknown'}||=sub {
  #my $self = shift if ref $_[0];
  #$self->log( 'dev', "unknown2", @_ );
  #};
  #};
  #'GET' => sub {
  $self->{'parse'} ||= {
    'GET' => sub {
      my $self = shift if ref $_[0];
      my ( $url, $prot ) = split /\s/, $_[0];
      $self->log( 'dev', "get $url : $prot" );
      $self->{'http_geturl'} = $url;
    },
    #"\x0D" => sub {$self->log('dev', 'can send');    },
    '' => sub {
      my $self = shift if ref $_[0];
      $self->log( 'dev', 'can send2', Dumper $self->{'handler_int'} );
      $self->send( "Content-Type: text/html; charset=utf-8\n\n<html><pre>" . Dumper($self) . "</html>" )
        if $self->{'http_geturl'} eq '/';
      $self->destroy();
    },
  };
  #$self->{'parser'} = sub {   my $self = shift;$self->log('dev', 'myparser', Dumper @_); };
  $self->log( 'dev', 'httpcli inited' );
}
1;
