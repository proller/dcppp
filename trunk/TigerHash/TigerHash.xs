
#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#undef do_open
#undef do_close

#ifdef __cplusplus
}
#endif

#include "os.h"

// files from linuxdcpp-1.0.3/client
// bzr branch lp:linuxdcpp
#include "stdinc.h"
//#include "config.h"
#include "DCPlusPlus.h"
#include "TigerHash.cpp"
#include "Encoder.cpp"
#include "MerkleTree.h"

#include "getpagesize.c"

MODULE = Net::DirectConnect::TigerHash		PACKAGE = Net::DirectConnect::TigerHash		


SV * 
tthbin(s)
    SV *s
    PROTOTYPE: $
    CODE:
        STRLEN len;
        char *  ptr = SvPV(s, len);
        dcpp::TigerHash th;
        th.update(ptr, len);
        RETVAL = newSVpv((const char*)(th.finalize()), (STRLEN)dcpp::TigerHash::BYTES);
    OUTPUT:
        RETVAL
    

SV *
tth(s)
    SV *s
    PROTOTYPE: $
    CODE:
        STRLEN len;
        char *  ptr = SvPV(s, len);
        dcpp::TigerHash th;
        th.update(ptr, len);
	std::string enc ;
	dcpp::Encoder::toBase32(    th.finalize(), dcpp::TigerHash::BYTES, enc);
    RETVAL = newSVpv( enc.data(), enc.length());
    OUTPUT:
		RETVAL
  
SV *
tthfile(s)
    SV *s
    PROTOTYPE: $
    CODE:
	
	STRLEN len;
	char *  file = SvPV(s, len);
	//int
	long
		fd = open(file, O_RDONLY);
	if(fd <=0 )	{
		XSRETURN_UNDEF;
	} 
	STAT buffer;
	int         status;
	 //status; 
	status = fstat(fd, &buffer);

	if (!(S_ISREG(buffer.st_mode) || S_ISLNK(buffer.st_mode))) {
		close(fd);
		XSRETURN_UNDEF;
	}

	int64_t size = buffer.st_size; 
	int64_t size_left = size;
	int64_t pos = 0;
	int64_t size_read = 0;
	static const int64_t BUF_SIZE = 0x1000000 - (0x1000000 % getpagesize());
	const int64_t MIN_BLOCK_SIZE = 64*1024;
	uint8_t* buf = NULL;
	buf = new uint8_t[BUF_SIZE];
	size_t n = 0;
	int64_t bs = std::max((unsigned long)dcpp::TigerTree::calcBlockSize(size, 10), (unsigned long)MIN_BLOCK_SIZE);

	dcpp::TigerTree th(bs);

	do {
		size_t bufSize = BUF_SIZE;
		if ((	n = read(fd, buf, BUF_SIZE))>=0) {
			th.update(buf, n);
			pos += n;
		}
	} while (n > 0);
	close(fd);

	th.update(buf, 0);
	std::string enc ;
	dcpp::Encoder::toBase32(    th.finalize(), dcpp::TigerHash::BYTES, enc);
	delete [] buf;
	RETVAL = newSVpv( enc.data(), enc.length());

    OUTPUT:
		RETVAL  
  
  
