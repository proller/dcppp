#$Id$ $URL$
#reserved for future 8)
package    #hide from cpan
  Net::DirectConnect::hubhub;
use Net::DirectConnect;
use strict;
no strict qw(refs);
use warnings "NONFATAL" => "all";
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
use base 'Net::DirectConnect';

sub init {
  my $self = shift;
  %$self = ( %$self, @_ );
  $self->{'parse'} = {};
  $self->{'cmd'}   = {};
}
1;
