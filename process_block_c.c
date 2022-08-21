#include "sha256.h"

// Variable global, key extraida del standard del NIST
uint K[64] = {0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
			  0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
		 	  0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
			  0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
		 	  0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
			  0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
			  0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
			  0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2};

/* Funciones definidas en el standard */
#define Ch(x,y,z) ((x & y) ^ ((~x) & z))
#define Maj(x,y,z) ((x & y) ^ (x & z) ^ (y & z))
#define ROTR(x,k) ((x >> k) | ((x << (32 - k))))
#define S0(x) (ROTR(x, 2) ^ ROTR(x, 13) ^ ROTR(x, 22))
#define S1(x) (ROTR(x, 6) ^ ROTR(x, 11) ^ ROTR(x, 25))
#define sig0(x) (ROTR(x, 7) ^ ROTR(x, 18) ^ (x >> 3))
#define sig1(x) (ROTR(x, 17) ^ ROTR(x, 19) ^ (x >> 10))


void process_block_c(uchar *M, uint *H)
{
	// aplicar el algoritmo a un bloque de 64 bytes
	uint t;	
	uint W[64];
	uint a, b, c, d, e, f, g, h, T1, T2;

	// 1 - Preparar el message schedule
	for (t = 0; t < 16; t++) // problemas con endianness
		W[t] = (M[4*t] << 24) | (M[4*t + 1] << 16) | (M[4*t + 2] << 8) | M[4*t + 3];

	for (t = 16; t < 64; t++)
		W[t] = sig1(W[t-2]) + W[t-7] + sig0(W[t-15]) + W[t-16];


	// 2 - initialize the 8 working variables
	a = H[0];
	b = H[1];
	c = H[2];
	d = H[3];
	e = H[4];
	f = H[5];
	g = H[6];
	h = H[7];
	
	// 3 - 
	for (t = 0; t < 64; t++)
	{
		T1 = h + S1(e) + Ch(e,f,g) + K[t] + W[t];
		T2 = S0(a) + Maj(a,b,c);
		h  = g;
		g  = f;
		f  = e;
		e  = d + T1;
		d  = c;
		c  = b;
		b  = a;
		a = T1 + T2;
	}

	// 4 - Compute the i_th intermediate hash value H[i]

	H[0] = a + H[0];
	H[1] = b + H[1];
	H[2] = c + H[2];
	H[3] = d + H[3];
	H[4] = e + H[4];
	H[5] = f + H[5];
	H[6] = g + H[6];
	H[7] = h + H[7];

}
