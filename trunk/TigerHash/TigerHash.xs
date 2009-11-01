
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

//#include <tth.h>
// files from linuxdcpp-1.0.3/client
// bzr branch lp:linuxdcpp
#include "stdinc.h"
#include "config.h"
#include "DCPlusPlus.h"
#include "TigerHash.cpp"
#include "Encoder.cpp"
#include "MerkleTree.h"

//#include "Util.cpp"
//#include "File.cpp"

//#ifndef _WIN32
//#include <sys/mman.h> // mmap, munmap, madvise
//#endif


MODULE = Net::DirectConnect::TigerHash		PACKAGE = Net::DirectConnect::TigerHash		


SV * 
tthbin(s)
    SV *s
    PROTOTYPE: $
    CODE:
        STRLEN len;
        char *  ptr = SvPV(s, len);
        TigerHash th;
        th.update(ptr, len);
        RETVAL = newSVpv((const char*)(th.finalize()), (STRLEN)TigerHash::HASH_SIZE);
    OUTPUT:
        RETVAL
    

SV *
tth(s)
    SV *s
    PROTOTYPE: $
    CODE:
        STRLEN len;
        char *  ptr = SvPV(s, len);
//printf("calc for[%s]\n", ptr);
        TigerHash th;
        th.update(ptr, len);
	string enc ;
	Encoder::toBase32(    th.finalize(), TigerHash::HASH_SIZE, enc);
//printf("calc for[%s]=[%s]\n", ptr,  enc.c_str());
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
    int fd = open(file, O_RDONLY);
    if//(fd == -1)
    (fd <=0 )
    {
      //return false;
    } else {
      struct stat buffer;
      int         status;
      status = fstat(fd, &buffer);
      int64_t size = buffer.st_size; //File::getSize(file);
      //printf("file[%s] size[%d]\n",file, size);
      int64_t size_left = size;
      int64_t pos = 0;
      int64_t size_read = 0;
      static const int64_t BUF_SIZE = 0x1000000 - (0x1000000 % getpagesize());
      const int64_t MIN_BLOCK_SIZE = 64*1024;
      uint8_t* buf = NULL;
      //void *buf = 0;
      //		if(buf == NULL) {
      //				virtualBuf = false;
      buf = new uint8_t[BUF_SIZE];
      //			}
      size_t n = 0;
      int64_t bs = max(TigerTree::calcBlockSize(size, 10), MIN_BLOCK_SIZE);
      //TigerHash th;
      TigerTree th(bs);
      //while(pos < size) {
      do {
        size_t bufSize = BUF_SIZE;
        //if(size_left > 0) {
        //size_read = std::min(size_left, BUF_SIZE);
        /*
      buf = mmap(0, size_read, PROT_READ, MAP_SHARED, fd, pos);
      if(buf == MAP_FAILED) {
        close(fd);
        return;// false;
      }
    //	madvise(buf, size_read, MADV_SEQUENTIAL | MADV_WILLNEED);
   */		
        if ((	n = read(fd, buf, BUF_SIZE))>=0) {
          //} else {	size_read = 0;		}
          //if (n)
          //  printf("up[%s] size[%d]\n",buf, n);
          th.update(buf, n);
          pos += n;
        }
        //if(size_left <= 0) {			break;		}
        //	munmap(buf, size_read);
        //pos += size_read;
        //size_left -= size_read;
        //}
      } while (n > 0);
      close(fd);
      // if (!pos)   
      th.update(buf, 0);
      //printf("calc for[%s]\n", ptr);
      //   th.update(ptr, len);
      string enc ;
      Encoder::toBase32(    th.finalize(), TigerHash::HASH_SIZE, enc);
      delete [] buf;
      //buf = NULL;
      //printf("calc for[%s]=[%s]\n", ptr,  enc.c_str());
      RETVAL = newSVpv( enc.data(), enc.length());
    }
    OUTPUT:
	RETVAL  
  
  
