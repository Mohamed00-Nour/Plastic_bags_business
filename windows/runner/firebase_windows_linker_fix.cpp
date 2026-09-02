// Firebase C++ SDK 13.1+ Windows binaries can contain a reference to this
// Universal CRT implementation detail without providing its weak fallback.
// Defining it as disabled keeps the CRT on its non-AVX2 wmemchr path and fixes
// the resulting LNK2001 error with affected Firebase Firestore builds.
//
// Upstream: https://github.com/firebase/firebase-cpp-sdk/issues/1798
extern "C" int _Avx2WmemEnabled = 0;
