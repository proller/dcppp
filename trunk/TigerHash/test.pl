use lib ('blib/lib', 'blib/arch');
#use lib ('blib/lib');
use Net::DirectConnect::TigerHash qw(tth);

use Mhash qw( mhash mhash_hex MHASH_TIGER);  
use Digest::Tiger; use
MIME::Base32 qw( RFC );


      sub tiger1 ($) {
              local ($_) = @_;
MIME::Base32::encode                      Digest::Tiger::hash($_);
                            }
      sub tiger2 ($) {
              local ($_) = @_;
              MIME::Base32::encode(Digest::Tiger::hash($_));
#                      Digest::Tiger::hash($_);
                            }
                            
#print tiger::hello();

#print tiger::tthbin('123');
#print tiger::tthbin('');
#print tiger::hello();
#print join ' ', "[",tiger::tth(''),"]\n";
#print join ' ',"[",tiger::tth('Tiger'),"]\n";
#''=>LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ
#'Tiger' => VD5PXIETOFDRL47QTK2K3XPX2A6LG5XTQFAC5OA
print join ' ',$_,"=[",tth($_),tiger1($_), tiger2($_),"]\n"

for '', 'Tiger', (join '', 1..1024);

#1..1024 => 6D3N5DVHCWWWPJRJHWLY4VN2DQX3APKMR4FZLWA
