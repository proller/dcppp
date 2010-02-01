#$Id: adc.pm 594 2010-01-30 23:10:17Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/lib/Net/DirectConnect/adc.pm $
#UNFINISHED
package    #hide from cpan
  Net::DirectConnect::nmdc;
use strict;
#use Time::HiRes qw(time sleep);
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
use Net::DirectConnect;
#use Net::DirectConnect::clicli;
#use Net::DirectConnect::http;
#use Net::DirectConnect::httpcli;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision: 594 $' ) )[1];
use base 'Net::DirectConnect';

sub init {
  my $self = shift;
  #shift if $_[0] eq __PACKAGE__;
  print "nmdcinit SELF=", $self, "REF=", ref $self, "  P=", @_, "package=", __PACKAGE__, "\n\n";
  #$self->SUPER::new();
  #%$self = (
  #%$self,
  local %_ = (
    'Nick'     => 'NetDCBot',
    'port'     => 411,
    'host'     => 'localhost',
    'protocol' => 'nmdc',
    #'Pass' => '',
    #'key'  => 'zzz',
    #'auto_wait'        => 1,
    #'search_every' => 10, 'search_every_min' => 10, 'auto_connect' => 1,
    #ADC
    #'connect_protocol' => 'ADC/0.10', 'message_type' => 'H',
    #@_,
    'incomingclass' => 'Net::DirectConnect::clicli',
    #'incomingclass' => __PACKAGE__,    #'Net::DirectConnect::adc',
    #no_print => { 'INF' => 1, 'QUI' => 1, 'SCH' => 1, },
  );
  $self->{$_} ||= $_{$_} for keys %_;
  #print 'adc init now=',Dumper $self;
  #$self->{'periodic'}{ __FILE__ . __LINE__ } = sub { $self->cmd( 'search_buffer', ) if $self->{'socket'}; };
}
1;
