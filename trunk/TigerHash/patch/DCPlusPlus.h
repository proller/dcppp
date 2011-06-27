--- ./eiskaltdcpp/dcpp/DCPlusPlus.h	2011-06-27 23:47:40.000000000 +0400
+++ dcpp/DCPlusPlus.h	2011-06-28 00:46:15.000000000 +0400
@@ -35,6 +35,7 @@
     vprintf(format, args);
     va_end(args);
 }
+*/
 
 #define dcdebug debugTrace
 #ifdef _MSC_VER
@@ -90,11 +91,12 @@
 # define PATH_SEPARATOR_STR "/"
 
 #endif
-
+/*
 namespace dcpp {
 extern void startup(void (*f)(void*, const string&), void* p);
 extern void shutdown();
 
 } // namespace dcpp
+*/
 
 #endif // !defined(DC_PLUS_PLUS_H)
