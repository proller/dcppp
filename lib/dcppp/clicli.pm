
package dcppp::clicli;

#eval { use dcppp; };

our @ISA = ('dcppp');

  sub init {
    my $self = shift;
    %$self = (%$self,
	'Nick'	=> 'dcpppBot', 
	'Key'	=> 'zzz', 
      @_);

    %{$self->{'parse'}} = (
    );
  
    %{$self->{'cmd'}} = (
    );
  }

1;