my $Id = '$Id$';

package dcppp::hubcli;

use dcppp;
use strict;

our @ISA = ('dcppp');

  sub init {
    my $self = shift;
    %$self = (%$self,
      @_);

    %{$self->{'parse'}} = (
    );
  
    %{$self->{'cmd'}} = (
    );
  }

1;