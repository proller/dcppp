#$Id$ $URL$
package Net::DirectConnect::http;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
use Net::DirectConnect;
#use Net::DirectConnect::hubcli;
use Net::DirectConnect::httpcli;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
#our @ISA = ('Net::DirectConnect');
use base 'Net::DirectConnect';

sub init {
  my $self = shift;
  #$self->log('dev', 'http init');
  %$self = (
    %$self,
    #
    , @_, 'incomingclass' => 'Net::DirectConnect::httpcli', 'auto_connect' => 0, 'auto_listen' => 1,
    #'HubName'       => 'Net::DirectConnect test hub',
    'myport'        => 80,
    'myport_base'   => 8000,
    'myport_random' => 99,
    'myport_tries'  => 5,
    'protocol'      => 'http',
  );
  $self->baseinit();
  #$self->{'parse'} ||= {};
  #$self->{'cmd'}   ||= {};
  #$self->log('dev', 'http inited', Dumper $self);
}
1;
