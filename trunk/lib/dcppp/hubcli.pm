my $Id = '$Id$';

# reserved for future 8)

package dcppp::hubcli;

use dcppp;
use strict;
  no warnings qw(uninitialized);

our @ISA = ('dcppp');

  sub init {
    my $self = shift;
    %$self = (%$self, @_);

    %{$self->{'parse'}} = (
    );
  
    %{$self->{'cmd'}} = (
    );
  }

1;