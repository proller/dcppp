--- ./eiskaltdcpp/dcpp/HashValue.h	2011-02-28 18:00:41.000000000 +0300
+++ dcpp/HashValue.h	2011-06-27 23:50:55.000000000 +0400
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
 
