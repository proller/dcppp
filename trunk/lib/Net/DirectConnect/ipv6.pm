#$Id: adc.pm 858 2011-10-10 22:56:04Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/lib/Net/DirectConnect/adc.pm $
# DEPRECATED, moving to IO::Socket::IP but it dont work v6 in windows
package    #hide from cpan
  Net::DirectConnect::ipv6;
use strict;
#use Time::HiRes qw(time sleep);
#use Socket;
#Net::DirectConnect::use_try 'Socket6' if $] < 5.014;
 # if $] < 5.014;
#require IO::Socket::IP    if $] >= 5.014
use Data::Dumper;    #dev only
#$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
sub init {
  my $self = shift if ref $_[0];
  $self->{'socket_class'} = 'IO::Socket::INET6' if Net::DirectConnect::use_try 'IO::Socket::INET6'; # if $] < 5.014;
  #$self->{'socket_options'}{Domain} = AF_INET6;
}
6;
