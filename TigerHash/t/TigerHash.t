# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl tiger.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 1;
BEGIN { use_ok('TigerHash') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.


#  print tiger::tthbin(''), "\n";
#  print tiger::tthbin('test'), "\n";
  
#  ok(tiger::hello()==42);
  
# ok(TigerHash::tth('')eq'LWPNACQDBZRYXW3VHJVCJ64QBZNGHOHHHZWCLNQ') ;
# ok(TigerHash::tth(join '', 1..1024)eq'6D3N5DVHCWWWPJRJHWLY4VN2DQX3APKMR4FZLWA') ;
# ok(TigerHash::tth('Tiger') eq 'VD5PXIETOFDRL47QTK2K3XPX2A6LG5XTQFAC5OA') ;
  