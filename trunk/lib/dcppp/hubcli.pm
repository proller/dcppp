my $Id = '$Id$';

# reserved for future 8)

package dcppp::hubcli;

use dcppp;
use strict;

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