
package dcppp::hubhub;

#use dcppp;

our @ISA = ('dcppp');

  sub init {
    my $self = shift;
    %$self = (%$self,
      @_);

    %{$self->{'parse'}} = (
      'MyNick' => sub { print 'Peer nick is [', ($self->{'peernick'} = @_[0]), "]\n";},
    );
  
    %{$self->{'cmd'}} = (
    );
  }

1;