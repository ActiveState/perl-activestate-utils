#include <stdlib.h>
#include <string.h>

char *
atomic_strdup(char *s)
{
    size_t l = strlen(s);
    char *dup = malloc(l + 1);
    if (dup)
	memcpy(dup, s, l + 1);
    return dup;
}
