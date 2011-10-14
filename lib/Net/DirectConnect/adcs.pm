#$Id: adc.pm 858 2011-10-10 22:56:04Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/lib/Net/DirectConnect/adc.pm $
=CERTS

mkdir certs

add to certs/cfg:
------------------------
[ req ]
default_bits	       = 1024
default_keyfile	       = server-key.pem
distinguished_name     = req_distinguished_name

[ req_distinguished_name ]
countryName		       = Country Name (2 letter code)
countryName_default	       = RU
countryName_min		       = 2
countryName_max		       = 2

localityName		       = Locality Name (eg, city)
organizationName               = Organization Name(eg, org)
organizationalUnitName	       = Organizational Unit Name (eg, section)

commonName		       = Common Name (eg, YOUR name)
commonName_max		       = 64

emailAddress		       = Email Address
emailAddress_max	       = 40
-------------------------
openssl genrsa -out certs/server-key.pem
openssl req -new -x509 -key server-key.pem -out certs/server-cert.pem -config cfg
=cut

package    #hide from cpan
  Net::DirectConnect::adcs;
use strict;
#use IO::Socket::SSL;
use IO::Socket::SSL qw(debug3);
use Data::Dumper;    #dev only
#$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
sub init {
  my $self = shift if ref $_[0];
  $self->module_load('adc');
  $self->{'protocol_supported'}{'ADCS/0.10'} = 'adcs'; 
    $self->log( 'dev',  'sslinit', $self->{'protocol'} ),
  
  $self->{'socket_class'} = 'IO::Socket::SSL' if 
  #!$self->{hub} and 
  $self->{'protocol'} eq 'adcs'
   #and !$self->{'auto_listen'}
   ;
  local %_ = (
  'recv' => 'read',
  'send' => 'syswrite',
  );
    $self->{$_} = $_{$_} for keys %_;


  #warn Dumper $self;
#    $self->{'socket_options'}{SSL_cert_file} = 'certs\server-cert.pem';
$self->{'socket_options'}{SSL_version}  = 'TLSv1';

$self->{'socket_options'}{SSL_server}=1 if $self->{'auto_listen'} ;
  #$self->{'adcs'}

    #$self->log( 'dev',  'ssltry'),
    IO::Socket::SSL->start_SSL($self->{'socket'}, %{$self->{'socket_options'}||{}}) if $self->{'socket'} and $self->{'protocol'} eq 'adcs';


      if ( !$self->{'no_listen'} #) {
#$self->log( 'dev', 'nyportgen',"$self->{'M'} eq 'A' or !$self->{'M'} ) and !$self->{'auto_listen'} and !$self->{'incoming'}" );
#    if (
and
      #( $self->{'M'} eq 'A' or !$self->{'M'} )  and
      !$self->{'incoming'} and !$self->{'auto_listen'}
      )
    {

            $self->log( 'dev', "making listeners: tls", "h=$self->{'hub'}" );
        $self->{'clients'}{'listener_tls'} = $self->{'incomingclass'}->new(
          'parent'      => $self,
          #'Proto'       => 'sctp',
          'protocol' => 'adcs',
          'auto_listen' => 1,
        );
        $self->{'myport_tls'} = $self->{'clients'}{'listener_tls'}{'myport'};
        #$self->log( 'dev', 'nyportgen', $self->{'myport_sctp'} );
        $self->log( 'err', "cant listen tls" ) unless $self->{'myport_tls'};
  }

}
6;
