#Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proler@gmail.com icq#89088275
#my $Id = '$Id$';
# reserved for future 8)
package Net::DirectConnect::hubhub;
use Net::DirectConnect;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
#our @ISA = ('Net::DirectConnect');
use base 'Net::DirectConnect';

sub init {
  my $self = shift;
  %$self = ( %$self, @_ );
  $self->{'parse'} = {};
  $self->{'cmd'}   = {};
}
1;
