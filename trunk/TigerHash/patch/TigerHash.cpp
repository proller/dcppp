--- ./eiskaltdcpp/dcpp/TigerHash.cpp	2010-11-22 01:55:38.018748700 +0300
+++ dcpp/TigerHash.cpp	2010-11-22 15:07:46.560297000 +0300
@@ -16,7 +16,7 @@
  * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
  */
 
-#include "stdinc.h"
+//#include "stdinc.h"
 #include "DCPlusPlus.h"
 
 #include "TigerHash.h"
@@ -34,7 +34,7 @@
 #if defined(__x86_64__) || defined(__alpha)
 #define TIGER_ARCH64
 #endif
-#if !(defined(__i386__) || defined(__x86_64__) || defined(__alpha)  || defined(__arm__))
+#if !(defined(__i386__) || defined(__x86_64__) || defined(__alpha) || defined(__arm__))
 #define TIGER_BIG_ENDIAN
 #endif
 #endif // _WIN32
