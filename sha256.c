#include <stdio.h>
#include <string.h>
#include "sha256.h"
#include "tiempo.h"

#define TIMES 100000

/* Esta funcion no se debe compilar con -O3, por el macro para medir tiempo */
luint sha256(const char *file, const char *algoritmo, bool mostrar_resultado)
{
	luint start, end, t = 0;
	luint i, j, h = 0, rounds, bytes_sobrantes, l, lb;
	uchar M2[BLOCK_SIZE];	
	void *M_aux;
	uchar *M;
	
	FILE *fp = fopen(file, "r");
	if(!fp)
	{
		perror("Error abriendo archivo");
		exit(-1);
	}
	l = get_file_size(fileno(fp));
		
	/* Uso posix_memalign en vez de malloc para asegurarme que *M esta alineada a 16 bytes,
		lo que mejora la performance al leer y escribir dato usando registros xmm*/
	posix_memalign(&M_aux, 16, l + BLOCK_SIZE);
	M = M_aux;
	fread(M, l, 1, fp);
	
	/* Asigno la implementacion del algoritmo correcto */
	void (* process_block)(uchar *M, uint *H);
	if (!strcmp(algoritmo, "c"))
		process_block = process_block_c;
	else if (!strcmp(algoritmo, "asm"))
		process_block = process_block_asm;
	else if (!strcmp(algoritmo, "simd"))
		process_block = process_block_simd;
	else
		process_block = process_block_simd_stitch;
		

	rounds = l / BLOCK_SIZE;
	bytes_sobrantes = l % BLOCK_SIZE;
	lb = l*8; // lb = longitud en bits del mensaje en el archivo

	// inicializando H con los valores dados en el standard
	uint H[8];
	H[0] = 0x6a09e667;
	H[1] = 0xbb67ae85;
	H[2] = 0x3c6ef372;
	H[3] = 0xa54ff53a;
   	H[4] = 0x510e527f;
 	H[5] = 0x9b05688c;
  	H[6] = 0x1f83d9ab;
	H[7] = 0x5be0cd19;
	
	for (j = 0; j < rounds; j++, h+=64)
	{
		MEDIR_TIEMPO_START(start)
		process_block(M + h, H);
		MEDIR_TIEMPO_STOP(end)
		t += end - start;
	}

	// si queda algún bloque con menos de 64 bytes para procesar
	if (bytes_sobrantes > 0)
	{		
		// hago padding siguiendo el metodo definido en el standard
		M[h + bytes_sobrantes] = 0x80; // agrego un bit en 1
	
		// si quedan menos de 448 bits, agregar un bit en uno y ceros hasta el bit 448 (byte 56)
		if (bytes_sobrantes < 56) 
		{
			for (i = bytes_sobrantes+1; i < 56; i++)
				M[h + i] = 0x00;
			
			/* guardar en los ultimos 64 bits la longitud del mensaje en bits */
			M[h + 63] = lb;
			M[h + 62] = lb >> 8;
			M[h + 61] = lb >> 16;
			M[h + 60] = lb >> 24;
			M[h + 59] = lb >> 32;
			M[h + 58] = lb >> 40;
			M[h + 57] = lb >> 48;
			M[h + 56] = lb >> 56;
			
			// aplico el algoritmo
			MEDIR_TIEMPO_START(start)
			process_block(M + h, H);
			MEDIR_TIEMPO_STOP(end)
			t += end - start;
		}
		/* Si el mensaje es mayor a 448 bits hay que crear otro bloque */		
		else
		{		
			for (i = bytes_sobrantes+1; i < 64; i++) 
				M[h + i] = 0x00;
						
			for (i = 0; i < 56; i++)
				M2[i] = 0x00;
		
			/* guardar en los ultimos 64 bits la longitud del mensaje en bits */
			M2[63] = lb;
			M2[62] = lb >> 8;
			M2[61] = lb >> 16;
			M2[60] = lb >> 24;
			M2[59] = lb >> 32;
			M2[58] = lb >> 40;
			M2[57] = lb >> 48;
			M2[56] = lb >> 56;

			// aplico algoritmo a ambos bloques
			MEDIR_TIEMPO_START(start)
			process_block(M + h, H);
			process_block(M2, H);
			MEDIR_TIEMPO_STOP(end)
			t += end - start;
		}
	} else {
		M2[0] = 0x80;
		for (i = 1; i < 56; i++)
			M2[i] = 0x00;
	
		M2[63] = lb;
		M2[62] = lb >> 8;
		M2[61] = lb >> 16;
		M2[60] = lb >> 24;
		M2[59] = lb >> 32;
		M2[58] = lb >> 40;
		M2[57] = lb >> 48;
		M2[56] = lb >> 56;
		
		MEDIR_TIEMPO_START(start)
		process_block(M2, H);
		MEDIR_TIEMPO_STOP(end)
		t += end - start;
	}
	// muestro el resultado por pantalla
	if (mostrar_resultado)
		print_result(H);
	
	free(M);
	fclose(fp);
	return t;
}

void print_help_sha256()
{
    printf("Parametros incorrectos\n");
    printf("Las posibles llamadas a este programa son:\n");
    printf("./sha256 t (ejecuta el test de performance, devuelve la cantidad de ciclos/byte)\n");
    printf("./sha256 file c (calcula sha256 del archivo file usando la implementacion en C)\n");
    printf("./sha256 file asm (calcula sha256 del archivo file usando la implementacion en asm)\n");
    printf("./sha256 file simd (calcula sha256 del archivo file usando la implementacion en asm-simd)\n");
    printf("./sha256 file simd_stitch (calcula sha256 del archivo file usando la implementacion en simd y stitching)\n");
    printf("./sha256 file ts (calcula sha256 del archivo file en todas las implementaciones pero devuelve la cantidad de ciclos usados por cada una. Las mediciones devueltas no son muy confiables por la varianza alta de los resultados)\n");
    printf("En el caso de los parámetros t y ts se devuelven los tiempos en el orden C asm simd simd_stitch");
}

int main(int argc, char** argv)
{
	if ( (argc == 2 && strcmp(argv[1], "t"))
		|| ((argc == 3) && strcmp(argv[2], "c") 
						&& strcmp(argv[2], "asm") 
						&& strcmp(argv[2], "simd") 
						&& strcmp(argv[2], "simd_stitch")
						&& strcmp(argv[2], "ts")) 
		|| argc == 1 )
	{
		//printf("Error en los parametros\n");
		print_help_sha256();
		exit(-1);
	}

	int i;
	if (argc == 2 && !strcmp(argv[1], "t"))
	{
		luint start, end, tc=0, tasm=0, tsimd=0, tsimds=0;
		uchar M[64] = one_block;
		
		for (i = 0; i < TIMES; i++)
		{
			uint H[8];
			H[0] = 0x6a09e667;
			H[1] = 0xbb67ae85;
			H[2] = 0x3c6ef372;
			H[3] = 0xa54ff53a;
		   	H[4] = 0x510e527f;
		 	H[5] = 0x9b05688c;
		  	H[6] = 0x1f83d9ab;
			H[7] = 0x5be0cd19;
			memset(M, 'a', BLOCK_SIZE);

			MEDIR_TIEMPO_START(start)
			process_block_c(M, H);
			MEDIR_TIEMPO_STOP(end)
			tc += end - start; 
			
			MEDIR_TIEMPO_START(start)
			process_block_asm(M, H);
			MEDIR_TIEMPO_STOP(end)
			tasm += end - start;
			
			MEDIR_TIEMPO_START(start)
			process_block_simd(M, H);
			MEDIR_TIEMPO_STOP(end)
			tsimd += end - start;
			
			MEDIR_TIEMPO_START(start)
			process_block_simd_stitch(M, H);
			MEDIR_TIEMPO_STOP(end)
			tsimds += end - start;			
		}
		
		printf("Cantidad de ciclos/bytes:\n");
		printf("%f", ((double) tc) / ((double) 6400000));
		printf("\t%f", ((double) tasm) / ((double) 6400000));
		printf("\t%f", ((double) tsimd) / ((double) 6400000));
		printf("\t%f\n", ((double) tsimds) / ((double) 6400000));
		
		printf("\nCantidad de ciclos:\n");
		printf("%lld", tc );
		printf("\t%lld", tasm);
		printf("\t%lld", tsimd);
		printf("\t%lld\n", tsimds);
		
	}
	else if (argc == 3 && !strcmp(argv[2], "ts"))
	{
		printf("%lld", sha256(argv[1], "C", FALSE));
		printf("\t%lld", sha256(argv[1], "asm", FALSE));
		printf("\t%lld", sha256(argv[1], "simd", FALSE));
		printf("\t%lld\n", sha256(argv[1], "simd_stitch", FALSE));
	}
	else if (argc >= 3)
		sha256(argv[1], argv[2], TRUE);
		
	return 0;
}
