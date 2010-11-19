#!/usr/bin/perl
use strict;
use warnings;
no warnings qw(uninitialized);
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
    ok( ( $_ = Net::DirectConnect::TigerHash::tth($str) ) eq $_{$str}, "[" .  ($str =~ /^(.{20})/ ? $1.'...' : $str)  . "]=[$_{$str}] r=[$_]" );
}

ok( !defined Net::DirectConnect::TigerHash::tthfile('___Not_Existen_t_ffiiiillee____') );
ok( !defined Net::DirectConnect::TigerHash::tthfile('./') );
ok( !defined Net::DirectConnect::TigerHash::tthfile('../t') );

1;
