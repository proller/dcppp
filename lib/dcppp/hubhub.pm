my $Id = '$Id$';

# reserved for future 8)

package dcppp::hubhub;

  use dcppp;
  use strict;
  no warnings qw(uninitialized);
  our $VERSION = (split(' ', '$Revision$'))[1];
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