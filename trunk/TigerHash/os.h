#if !defined(TH_OS_H)
#define TH_OS_H
#include <sys/types.h>
#include <sys/stat.h>

	//#if (defined(_WIN32) || defined(__WIN32__)) && ( !defined(__CYGWIN__) && !defined(__CYGWIN64__) && !defined(__CYGWIN32__) )
	#if ( defined(__WIN32__)) && ( !defined(__CYGWIN__) && !defined(__CYGWIN64__) && !defined(__CYGWIN32__) )
		typedef signed __int64 int64_t;
		typedef unsigned __int8 uint8_t;
	#endif

	#if ( defined(__WIN64__) && !defined(__CYGWIN64__))
		typedef struct stat64 STAT;
		//#define stat64 STAT
	#else
		typedef struct stat STAT;
		//#define stat STAT
	#endif

#endif
