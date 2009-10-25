
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
    //newSVpv 
//    sv_setpvn    (RETVAL,(const char*)(th.finalize()), (STRLEN)TigerHash::HASH_SIZE);
 //    sv_setpvn    (RETVAL,reinterpret_cast<uint8_t*>((uint8_t*)(th.finalize())), (STRLEN)TigerHash::HASH_SIZE);
//    sv_setpvn    (RETVAL,reinterpret_cast<uint8_t*>(th.finalize()), (STRLEN)TigerHash::HASH_SIZE);
//    sv_setpvn    (RETVAL,"resultttttttttttttttttttttttttttttttttttt", (STRLEN)TigerHash::HASH_SIZE);
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
                                                        
