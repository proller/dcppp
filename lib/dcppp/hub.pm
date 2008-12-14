#Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proler@gmail.com icq#89088275
my $Id = '$Id: hubcli.pm 246 2007-10-04 21:35:54Z pro $';
# reserved for future 8)
package dcppp::hub;
use dcppp;
use dcppp::hubcli;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision: 246 $' ) )[1];
#our @ISA = ('dcppp');
use base 'dcppp';

sub init {
  my $self = shift;
  %$self = (
    %$self,
    #
    'incomingclass' => 'dcppp::hubcli',
    'auto_connect'  => 0,
    'auto_listen'   => 1,
    'myport'        => 411,
    'myport_base'   => 0,
    'myport_random' => 0,
    'myport_tries'  => 1,
    'HubName'       => 'dcppp test hub',
    , @_
  );
  $self->baseinit();
  $self->{'parse'} ||= {};
  $self->{'cmd'}   ||= {};
}
1;
