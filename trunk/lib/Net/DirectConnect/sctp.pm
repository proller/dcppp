#$Id: adc.pm 858 2011-10-10 22:56:04Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/lib/Net/DirectConnect/adc.pm $
package    #hide from cpan
  Net::DirectConnect::sctp;
use strict;
use Socket;
#use Socket6;
#use IO::Socket::INET6;
use Data::Dumper;    #dev only
#$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;

sub init {
  my $self = shift if ref $_[0];
    $self->{'Proto'} = 'sctp';
  $self->{'socket_options'}{Type} = Socket::SOCK_STREAM;
}

6;