my $Id = '$Id: dcppp.pm 110 2006-03-02 22:51:22Z pro $';

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