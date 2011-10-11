#$Id: adc.pm 858 2011-10-10 22:56:04Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/lib/Net/DirectConnect/adc.pm $
package    #hide from cpan
  Net::DirectConnect::adcs;
use strict;
use IO::Socket::SSL;
use Data::Dumper;    #dev only
#$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;

sub init {
  my $self = shift if ref $_[0];
    
   $self->{'protocol_supported'}{$_} = $_ for qw(ADCS/0.10), 

   $self->{'socket_class'} = 'IO::Socket::SSL';

}


6;