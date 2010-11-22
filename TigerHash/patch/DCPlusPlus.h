--- ./eiskaltdcpp/dcpp/DCPlusPlus.h	2010-11-22 01:55:37.221669000 +0300
+++ dcpp/DCPlusPlus.h	2010-11-22 15:07:45.715297000 +0300
@@ -99,8 +99,19 @@
 typedef std::vector<WStringPair> WStringPairList;
 typedef WStringPairList::iterator WStringPairIter;
 
-typedef std::vector<uint8_t> ByteVector;
+/*typedef unsigned char uint8_t;
+typedef signed char int8_t             ;
+typedef unsigned char uint8_t          ;
+typedef signed int int16_t             ;
+typedef unsigned int uint16_t          ;
+typedef signed long int int32_t        ;
+typedef unsigned long int uint32_t     ;
+typedef signed long long int int64_t   ;
+typedef unsigned long long int uint64_t;
+*/
 
+typedef std::vector<uint8_t> ByteVector;
+/*
 template<typename T>
 boost::basic_format<T> dcpp_fmt(const T* t) {
     boost::basic_format<T> fmt;
@@ -113,6 +124,7 @@
 boost::basic_format<T> dcpp_fmt(const std::basic_string<T>& t) {
     return dcpp_fmt(t.c_str());
 }
+*/
 
 #if defined(_MSC_VER) || defined(__MINGW32__)
 #define _LL(x) x##ll
@@ -178,8 +190,10 @@
 
 #endif
 
+/*
 extern void startup(void (*f)(void*, const string&), void* p);
 extern void shutdown();
+*/
 
 #ifdef BUILDING_DCPP
 #define PACKAGE "libeiskaltdcpp"
