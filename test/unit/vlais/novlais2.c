#include <stdio.h>
#include <string.h>

extern void printHex(char *buffer, size_t size);

#define VLAIS_STRUCT(structname) size_t next_##structname = 0
#define VLAIS_STRUCT_SIZE(structname) next_##structname

	//size_t pad_##structname##_##name = (~__alignof__(type)) & (next_##structname & (__alignof__(type)-1)); 
#define VLAIS(structname, type, name, n) \
	type * structname##_##name; \
	size_t pad_##structname##_##name = (next_##structname & (__alignof__(type)-1)); \
	size_t offset_##structname##_##name = next_##structname + pad_##structname##_##name; \
	size_t sz_##structname##_##name = n * sizeof(type); \
	next_##structname = next_##structname + pad_##structname##_##name + sz_##structname##_##name; 

#define VLAIS_SET_PTR(ptr,structname,name) structname##_##name = (typeof(structname##_##name))&ptr[offset_##structname##_##name]

long NOVLAIS(int a, int b, int c, int d, int p)
{
	VLAIS_STRUCT(foo);
		VLAIS(foo, char,  vara, a);
		VLAIS(foo, short, varb, b);
		VLAIS(foo, int,   varc, c);
		VLAIS(foo, long,  vard, d);

	size_t total = VLAIS_STRUCT_SIZE(foo);
	char buffer[total];

	VLAIS_SET_PTR(buffer, foo, vara);
	VLAIS_SET_PTR(buffer, foo, varb);
	VLAIS_SET_PTR(buffer, foo, varc);
	VLAIS_SET_PTR(buffer, foo, vard);

	long ret = 0 | offset_foo_varb<<16 | offset_foo_varc<<8 | offset_foo_vard;
	if(p) printf("no-vlais: 0x%08X (%ld:%ld)\n", (int)ret, total, sizeof(buffer));

	memset(buffer, 0, sizeof(buffer));
	memset(foo_vard, 4, d*sizeof(long));
	memset(foo_varc, 3, c*sizeof(int));
	memset(foo_varb, 2, b*sizeof(short));
	memset(foo_vara, 1, a*sizeof(char));
	if(p) printHex(buffer, sizeof(buffer));

	return ret;
}