#!/usr/bin/perl
use lib ( 'blib/lib', 'blib/arch' );
#use lib ('blib/lib');
use Net::DirectConnect::TigerHash qw(tth tthbin tthfile);
use Mhash qw( mhash mhash_hex MHASH_TIGER);
use Digest::Tiger;
use MIME::Base32 qw( RFC );
sub tiger1 ($) { local ($_) = @_; MIME::Base32::encode Digest::Tiger::hash($_); }

sub tiger2 ($) {
  local ($_) = @_;
  MIME::Base32::encode( Digest::Tiger::hash($_) );
  #Digest::Tiger::hash($_);
}
#print tiger::hello();
#print tiger::tthbin('123');
#print tiger::tthbin('');
#print tiger::hello();
#print join ' ', "[",tiger::tth(''),"]\n";
#print join ' ',"[",tiger::tth('Tiger'),"]\n";
#''=>LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ
#'Tiger' => VD5PXIETOFDRL47QTK2K3XPX2A6LG5XTQFAC5OA
print join ' ', $_, "=[", tth($_), tiger1($_), tiger2($_), "]\n\n" for '', 'Tiger', "\0", "\0\0",
  #(join '', 1..1024),
  #(
  ( join '', ( 'A' x 1024 ) ), ( join '', ( 'A' x 1025 ) ),
  #),
  ;
print "===file\n";
print tthfile('README'), "\n";
print tthfile 'pm_to_blib', "\n";    #LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ
print tthfile '0',          "\n";    #VK54ZIEEVTWNAUI5D5RDFIL37LX2IQNSTAXFKSA
print tthfile '00',         "\n";    #P55IZ2KYAB36W36VHPULWPTQMUHC7XMNXNCPLRY
#print tthfile 'C:\pub\chillout\Nebra_Skydisk_-_mixed_by_Cardamar.mp3';
#print tthfile 'Makefile.old', "\n";
print tthfile 'uuuuuuuneeexistent', "\n";
#1..1024 => 6D3N5DVHCWWWPJRJHWLY4VN2DQX3APKMR4FZLWA
