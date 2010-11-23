#$Id$ $URL$
package Net::DirectConnect::TigerHash;
our $VERSION = '0.03';# . '_' . ( split( ' ', '$Revision$' ) )[1];
use 5.006001;
use strict;
use warnings;
require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( 'all' => [ qw( tthbin tth tthfile ) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT    = qw( );
require XSLoader;
XSLoader::load( 'Net::DirectConnect::TigerHash', $VERSION );
1;
__END__

=head1 NAME

Net::DirectConnect::TigerHash - Perl extension for calculating tiger hashes from files or strings

=head1 SYNOPSIS

  use Net::DirectConnect::TigerHash qw(tthbin tth tthfile);
  print tthbin('somestring'); #24 bytes
  print tth('somestring'); #base32 encoded, 39 chars
  print tthfile('/etc/passwd'); #base32 encoded
  print tthfile('__NOT_eXisted_file___'); #undef

=head1 DESCRIPTION

 ported from eiskaltdc

=head2 EXPORT

None by default.

=head2 Exportable functions

 tthbin
 tth
 tthfile

=head1 SEE ALSO

 http://code.google.com/p/eiskaltdc/

=head1 BUGS

=head1 AUTHOR

Oleg Alexeenkov, E<lt>pro@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009-2010 Oleg Alexeenkov, eiskaltdc authors

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
