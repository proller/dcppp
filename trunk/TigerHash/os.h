#if !defined(TH_OS_H)
#define TH_OS_H
#include <sys/types.h>
#include <sys/stat.h>

	#if ( (defined(__WIN32__) || defined(__WIN64__) ) && !defined(__CYGWIN64__))
		typedef struct _stati64 STAT; // your bunny microsoft
	#else
		typedef struct stat STAT;
	#endif


#endif
         