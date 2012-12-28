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
#openssl genrsa -out certs/server-key.pem
openssl req -new -x509 -key certs/server-key.pem -out certs/server-cert.pem -config certs/cfg
openssl genrsa -out certs/client-key.pem
openssl req -new -x509 -key certs/server-key.pem -out certs/client-cert.pem -config certs/cfg

debug:
openssl s_server -accept 413 -cert certs/server-cert.pem -key certs/server-key.pem
openssl s_client -debug -connect 127.0.0.1:413

=cut

package    #hide from cpan
  Net::DirectConnect::adcs;
use strict;
no strict qw(refs);
use warnings "NONFATAL" => "all";
no warnings qw(uninitialized);

#use IO::Socket::SSL;
use IO::Socket::SSL qw(debug4);
#$Net::SSLeay::trace = 4;
#$ENV{HTTPS_VERSION} = 10;
#$Net::SSLeay::ssl_version = 3;

use Data::Dumper;    #dev only
#$Data::Dumper::Sortkeys = $Data::Dumper::Useqq = $Data::Dumper::Indent = 1;
sub init {
  my $self = shift if ref $_[0];
  $self->module_load('adc');
#$self->log('s', $self->{'protocol'});
  $self->{'protocol_supported'}{'ADCS/0.10'} = 'adcs';
  #$self->log( 'dev', 'sslinit', $self->{'protocol'} ), 
  $self->{'socket_class'} = 'IO::Socket::SSL'
    if
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
  #$self->{'socket_options'}{SSL_version} = 'TLSv1';
  #$self->{'socket_options'}{SSL_server} = 1 if $self->{'auto_listen'};
  #$self->{'socket_options'}{SSL_verify_mode} = SSL_VERIFY_NONE;
#$self->log( 'sslv', Net::SSLeay::DEFAULT_VERSION);
local %_ = (

	    #SSL_startHandshake => !!$self->{'incoming'},
	    SSL_server => !!$self->{'auto_listen'},
	    #SSL_verify_mode => 0x00,
($self->{'incoming'} || $self->{'auto_listen'} ? 
	    (
	SSL_version => 'TLSv1',
	#SSL_cipher_list => 'HIGH',
	SSL_verify_mode => 0,

        #SSL_ca_file => "certs/server-cert.pem",
        #SSL_key_file  => "certs/server-key.pem",
($Net::SSLeay::VERSION>=1.16 ?
	(
	    #SSL_key_file => "certs/server-key.enc", 
	    SSL_passwd_cb => sub { return "qwer" },
#	    SSL_verify_callback => \&verify_sub
	) : (
	    SSL_key_file => "certs/server-key.pem"
	))
) :
(
        SSL_ca_file => "certs/client-cert.pem",
        SSL_key_file  => "certs/client-key.pem",
)),
	    #SSL_use_cert => 1,
	    #SSL_cert_file => "certs/client-cert.pem",


                 #SSL_server => $is_server,
                 #SSL_use_cert => !!$self->{'auto_listen'},
                 #SSL_check_crl => 0,
                 #SSL_version     => DEFAULT_VERSION,
                 #SSL_version     => 'TLSv1',
                 #SSL_version     => 'SSLv3',
                 #SSL_verify_mode => SSL_VERIFY_NONE,
                 #SSL_verify_callback => undef,
                 #SSL_verifycn_scheme => undef,  # don't verify cn
                 #SSL_verifycn_name => undef,    # use from PeerAddr/PeerHost
                 #SSL_npn_protocols => undef,    # meaning depends whether on server or client side
                 #SSL_honor_cipher_order => 0,   # client order gets preference
);
$self->{'socket_options'}{$_} = $_{$_} for keys %_;

 $self->log( 'dev',  'sockopt',      %{$self->{'socket_options'}},);


#	ReuseAddr => 1,
#	SSL_server => 1,


  #$self->{'adcs'}
  #$self->log( 'dev',  'ssltrystart', $self->{'incoming'}),
  #IO::Socket::SSL->start_SSL( SSL_server => 1, $self->{'socket'}, %{ $self->{'socket_options'} || {} } )    if $self->{'socket'} and $self->{'protocol'} eq 'adcs' and $self->{'incoming'};
  #$self->log( 'dev',  'ssl started', $self->{'socket'});
  if (
    !$self->{'no_listen'}    #) {
#$self->log( 'dev', 'nyportgen',"$self->{'M'} eq 'A' or !$self->{'M'} ) and !$self->{'auto_listen'} and !$self->{'incoming'}" );
#    if (
    and
    #( $self->{'M'} eq 'A' or !$self->{'M'} )  and
    !$self->{'incoming'} and !$self->{'auto_listen'}
    )
  {
    $self->log( 'dev', "making listeners: tls", "h=$self->{'hub'}" );
    $self->{'clients'}{'listener_tls'} = $self->{'incomingclass'}->new(
      'parent' => $self,
      'protocol'    => 'adcs',
      'auto_listen' => 1,
    );
    $self->{'myport_tls'} = $self->{'clients'}{'listener_tls'}{'myport'};
    #$self->log( 'dev', 'nyportgen', $self->{'myport_sctp'} );
    $self->log( 'err', "cant listen tls" ) unless $self->{'myport_tls'};

      if (
        $self->{'dev_sctp'}
        )
      {
        $self->log( 'dev', "making listeners: tls sctp", "h=$self->{'hub'}" );
        $self->{'clients'}{'listener_tls_sctp'} = $self->{'incomingclass'}->new(
          'parent'      => $self,
          'Proto'       => 'sctp',
          'protocol'    => 'adcs',
          'auto_listen' => 1,
        );
        $self->{'myport_tls_sctp'} = $self->{'clients'}{'listener_tls_sctp'}{'myport'};
        #$self->log( 'dev', 'nyportgen', $self->{'myport_sctp'} );
        $self->log( 'err', "cant listen tls sctp" ) unless $self->{'myport_tls_sctp'};
      }

  }
}
6;
