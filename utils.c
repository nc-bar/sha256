#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>

long unsigned int get_file_size(int fd)
{
	struct stat file_info;
	fstat(fd, &file_info);
	return ((long unsigned int) file_info.st_size - 1);
}

void print_result(unsigned int *H)
{
	printf("%08x%08x%08x%08x%08x%08x%08x%08x\n", H[0], H[1], H[2], H[3], H[4], H[5], H[6], H[7]);
}

void print_result_debug(unsigned int *H)
{
	printf("H[0] = %08x\nH[1] = %08x\nH[2] = %08x\nH[3] = %08x\nH[4] = %08x\nH[5] = %08x\nH[6] = %08x\nH[7] = %08x\n",
						 H[0], H[1], H[2], H[3], H[4], H[5], H[6], H[7]);
}
