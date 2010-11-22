--- ./eiskaltdcpp/dcpp/DCPlusPlus.h	2010-11-22 15:13:05.850172400 +0300
+++ dcpp/DCPlusPlus.h	2010-11-22 15:18:50.196603600 +0300
@@ -99,8 +99,9 @@
 typedef std::vector<WStringPair> WStringPairList;
 typedef WStringPairList::iterator WStringPairIter;
 
-typedef std::vector<uint8_t> ByteVector;
 
+typedef std::vector<uint8_t> ByteVector;
+/*
 template<typename T>
 boost::basic_format<T> dcpp_fmt(const T* t) {
     boost::basic_format<T> fmt;
@@ -113,6 +114,7 @@
 boost::basic_format<T> dcpp_fmt(const std::basic_string<T>& t) {
     return dcpp_fmt(t.c_str());
 }
+*/
 
 #if defined(_MSC_VER) || defined(__MINGW32__)
 #define _LL(x) x##ll
@@ -178,8 +180,10 @@
 
 #endif
 
+/*
 extern void startup(void (*f)(void*, const string&), void* p);
 extern void shutdown();
+*/
 
 #ifdef BUILDING_DCPP
 #define PACKAGE "libeiskaltdcpp"
