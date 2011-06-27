--- ./eiskaltdcpp/dcpp/stdinc.h	2011-06-27 23:47:40.000000000 +0400
+++ dcpp/stdinc.h	2011-06-27 23:54:52.000000000 +0400
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
@@ -87,7 +90,7 @@
 #include <mmsystem.h>
 
 #include <tchar.h>
-#include <shlobj.h>
+//#include <shlobj.h>
 
 #else
 #include <unistd.h>
@@ -122,11 +125,13 @@
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
 
