--- ./eiskaltdcpp/dcpp/HashValue.h	2010-11-22 15:13:05.895176900 +0300
+++ dcpp/HashValue.h	2010-11-22 15:19:57.960379300 +0300
@@ -19,13 +19,13 @@
 #ifndef DCPLUSPLUS_DCPP_HASH_VALUE_H
 #define DCPLUSPLUS_DCPP_HASH_VALUE_H
 
-#include "FastAlloc.h"
+//#include "FastAlloc.h"
 #include "Encoder.h"
 
 namespace dcpp {
 
 template<class Hasher>
-struct HashValue : FastAlloc<HashValue<Hasher> >{
+struct HashValue /*: FastAlloc<HashValue<Hasher> > HashValue<Hasher> */ {
     static const size_t BITS = Hasher::BITS;
     static const size_t BYTES = Hasher::BYTES;
 
