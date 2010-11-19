#Before `make install' is performed this script should be runnable with
#`make test'. After `make install' it should work as `perl tiger.t'
#########################
#change 'tests => 1' to 'tests => last_test_to_print';
use Test::More qw(no_plan);
BEGIN { use_ok('Net::DirectConnect::TigerHash') }
#########################
#http://www.open-content.net/specs/draft-jchapweske-thex-02.html
local %_ = (
    ''         => 'GKJ2YYYMCPYCIX4SXOYXM3QWCZ5E4WCJFXPHH4Y',
    "\0"       => 'LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ',
    'A' x 1024 => 'ZXYJSDC4NNVQXXOWHJ262IHC2REL6RHBL7PA35A',
    'A' x 1025 => 'REUSV3QPQKCCVPAIBRL3HKW5TSUE2ZV7BSXHPKQ',
    'Tiger'    => '3UACGB4Z6UAJ73DN5PEDRO3KE7PSXHLPCEGHSNY',
);

for my $str ( sort keys %_ ) {
    ok( ( $_ = Net::DirectConnect::TigerHash::tth($_) ) eq $_{$str}, "[" . substr( $str, 0, 20 ) . "..]=[$_{$str}] r=[$_]" );
}

ok( !defined Net::DirectConnect::TigerHash::tthfile('___Not_Existen_t_ffiiiillee____') );
ok( !defined Net::DirectConnect::TigerHash::tthfile('./') );
ok( !defined Net::DirectConnect::TigerHash::tthfile('../t') );
1;
