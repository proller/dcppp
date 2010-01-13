#Before `make install' is performed this script should be runnable with
#`make test'. After `make install' it should work as `perl tiger.t'
#########################
#change 'tests => 1' to 'tests => last_test_to_print';
use Test::More tests => 9;
BEGIN { use_ok('Net::DirectConnect::TigerHash') }
#########################
#http://www.open-content.net/specs/draft-jchapweske-thex-02.html
ok( Net::DirectConnect::TigerHash::tth('')           eq 'GKJ2YYYMCPYCIX4SXOYXM3QWCZ5E4WCJFXPHH4Y' );
ok( Net::DirectConnect::TigerHash::tth("\0")         eq 'LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ' );
ok( Net::DirectConnect::TigerHash::tth( 'A' x 1024 ) eq 'ZXYJSDC4NNVQXXOWHJ262IHC2REL6RHBL7PA35A' );
ok( Net::DirectConnect::TigerHash::tth( 'A' x 1025 ) eq 'REUSV3QPQKCCVPAIBRL3HKW5TSUE2ZV7BSXHPKQ' );
ok( Net::DirectConnect::TigerHash::tth('Tiger')      eq '3UACGB4Z6UAJ73DN5PEDRO3KE7PSXHLPCEGHSNY' );
ok( !defined Net::DirectConnect::TigerHash::tthfile('___Not_Existen_t_ffiiiillee____') );
ok( !defined Net::DirectConnect::TigerHash::tthfile('./') );
ok( !defined Net::DirectConnect::TigerHash::tthfile('../t') );
1;
