#ifndef __SHA256__
#define __SHA256__

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define BLOCK_SIZE 64 // en bytes
#define BIT_BLOCK_SIZE 512
#define TRUE 1
#define FALSE 0

#define one_block "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

typedef unsigned char uchar;
typedef unsigned int uint;
typedef long long unsigned int luint;
typedef int bool;
		
luint sha256(const char *file, const char *algoritmo, bool mostrar_resultado);

extern void process_block_simd(uchar *M, uint *H);
extern void process_block_simd_stitch(uchar *M, uint *H);
extern void process_block_asm(uchar *M, uint *H);
extern void process_block_c(uchar *M, uint *H);

extern luint get_file_size();
extern void print_result(unsigned int *H);
extern void print_result_debug(unsigned int *H);
extern int fileno( FILE *flujo);
extern int posix_memalign(void **memptr, size_t alignment, size_t size);
#endif
