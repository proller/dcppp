
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
#include "getpagesize.c"

#include "stdinc.h"
#include "DCPlusPlus.h"
#include "TigerHash.cpp"
#include "Encoder.cpp"
#include "MerkleTree.h"


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
	printf("opened [%s] %db\n", file, size);
	//int64_t size_left = size;
	int64_t pos = 0;
	//int64_t size_read = 0;
	static const int64_t BUF_SIZE = 0x1000000 - (0x1000000 % getpagesize());
	const int64_t MIN_BLOCK_SIZE = 64*1024;
	uint8_t* buf = NULL;
	buf = new uint8_t[BUF_SIZE];
printf("bufsiz:%lld, = %ld gpage:%ld \n", BUF_SIZE, sizeof(buf),getpagesize());
	size_t n = 0;
	int64_t bs = std::max((unsigned long)dcpp::TigerTree::calcBlockSize(size, 10), (unsigned long)MIN_BLOCK_SIZE);

	dcpp::TigerTree th(bs);

	do {
//		size_t bufSize = BUF_SIZE;
		if ((	n = read(fd, buf, BUF_SIZE))>0) {
			th.update(buf, n);
printf("updated %ld b [.]\n", n, buf);
//printf("updated %d b ", n);
			pos += n;
		}
printf(" readed %ld tot=%ld buf=%ld \n", n, pos, BUF_SIZE);

	} while (n > 0);
	close(fd);

	th.update(buf, 0);
	std::string enc;
	dcpp::Encoder::toBase32(    th.finalize(), dcpp::TigerHash::BYTES, enc);
	delete [] buf;
	RETVAL = newSVpv( enc.data(), enc.length());

    OUTPUT:
		RETVAL  
  

SV * 
toBase32(s)
    SV *s
    PROTOTYPE: $
    CODE:
        STRLEN len;
        char * ptr = SvPV(s, len);
	std::string enc;
	dcpp::Encoder::toBase32((const uint8_t*)ptr, len, enc);
	RETVAL = newSVpv( enc.data(), enc.length());
    OUTPUT:
        RETVAL

  
SV * 
fromBase32(s)
    SV *s
    PROTOTYPE: $
    CODE:
        STRLEN len;
        char * ptr = SvPV(s, len);
	len = len * 5 / 8;
	uint8_t* dst = new uint8_t [len];
	dcpp::Encoder::fromBase32(ptr, dst, len);
	RETVAL = newSVpv((const char*) dst, len);
    OUTPUT:
        RETVAL


