
package dcppp::hubhub;

#use dcppp;

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