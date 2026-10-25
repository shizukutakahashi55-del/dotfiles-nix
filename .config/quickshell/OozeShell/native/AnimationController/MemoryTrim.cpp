#include "MemoryTrim.h"

#ifdef __GLIBC__
#include <malloc.h>
#endif

bool MemoryTrim::trim() const
{
#ifdef __GLIBC__
    return malloc_trim(0) != 0;
#else
    return false;
#endif
}
