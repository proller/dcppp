--- ./eiskaltdcpp/dcpp/stdinc.h	2010-11-22 15:13:06.040191400 +0300
+++ dcpp/stdinc.h	2010-11-22 15:37:35.545127200 +0300
@@ -33,14 +33,8 @@
 #define BZ_NO_STDIO 1
 #endif
 
-#ifdef _MSC_VER
-
-//disable the deprecated warnings for the CRT functions.
-#define _CRT_SECURE_NO_DEPRECATE 1
-#define _ATL_SECURE_NO_DEPRECATE 1
-#define _CRT_NON_CONFORMING_SWPRINTFS 1
-
-
+//msc, mingw
+#if defined(_MSC_VER) || ( defined(__WIN32__) && !defined(__CYGWIN__))
 typedef signed __int8 int8_t;
 typedef signed __int16 int16_t;
 typedef signed __int32 int32_t;
@@ -50,6 +44,15 @@
 typedef unsigned __int16 uint16_t;
 typedef unsigned __int32 uint32_t;
 typedef unsigned __int64 uint64_t;
+#endif
+
+
+#ifdef _MSC_VER
+
+//disable the deprecated warnings for the CRT functions.
+#define _CRT_SECURE_NO_DEPRECATE 1
+#define _ATL_SECURE_NO_DEPRECATE 1
+#define _CRT_NON_CONFORMING_SWPRINTFS 1
 
 # ifndef CDECL
 #  define CDECL _cdecl
@@ -64,11 +67,11 @@
 #endif // _MSC_VER
 
 #ifdef _WIN32
-# define _WIN32_WINNT 0x0501
+//# define _WIN32_WINNT 0x0501
 # define _WIN32_IE      0x0501
-# define WINVER 0x501
+//# define WINVER 0x501
 
-#define STRICT
+//#define STRICT
 #define WIN32_LEAN_AND_MEAN
 
 #include <winsock2.h>
@@ -77,7 +80,7 @@
 #include <mmsystem.h>
 
 #include <tchar.h>
-#include <shlobj.h>
+//#include <shlobj.h>
 
 #else
 #include <unistd.h>
@@ -110,11 +113,13 @@
 #include <memory>
 #include <numeric>
 #include <limits>
+/*
 #include <libintl.h>
 
 #include <boost/format.hpp>
 #include <boost/scoped_array.hpp>
 #include <boost/noncopyable.hpp>
+*/
 
 #if defined(_MSC_VER) || defined(_STLPORT_VERSION)
 
