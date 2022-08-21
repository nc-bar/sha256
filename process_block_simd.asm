global process_block_simd

%define BLOCK_SIZE 64 ; En bytes

section .data
	align 16
	shuf_mask_1: db 0x3, 0x2, 0x1, 0x0, 0x7, 0x6, 0x5, 0x4, 0xb, 0xa, 0x9, 0x8, 0xf, 0xe, 0xd, 0xc
	; dato del standard
	K:		dd 0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
			dd 0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
		 	dd 0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
			dd 0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
		 	dd 0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
			dd 0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
			dd 0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
			dd 0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
	align 16
	W:		times 64 dd 0

section .text

;;;;;;;;;;;;;;;;;
; MACROS:

%macro iteracion_segundo_ciclo 4	
	; usa los registros xmm4 - xmm9, ademas de %1 - %4
	; toma como parametro 4 registros xmm

	;W[t] = sig1(W[t-2]) + W[t-7] + sig0(W[t-15]) + W[t-16]
	movdqa xmm4, %4
	palignr xmm4, %3, 4 ; xmm0 = W[ 3 | 2 | 1 | 0 ]; xmm4 = W[ 12 | 11 | 10 | 9 ]
	movdqa xmm6, %2	
	paddd xmm4, %1 ; xmm4 = W[3] + W[12] | W[2] + W[11] | W[1] + W[10] | W[0] + W[9]  
	; calculo sig0(W[t-15]), sig0(W[t+1-15]), sig0(W[t+2-15]), sig0(W[t+3-15])
	; sig0(x) = (ROTR(x, 7) ^ ROTR(x, 18) ^ (x >> 3))
	movdqa xmm5, %2
	palignr xmm5, %1, 4 ; xmm5 = W[ 4 | 3 | 2 | 1 ]
	; no hay ror para simd, hay que hacerlo "a mano"
	movdqa xmm6, xmm5
	movdqa xmm7, xmm5
	psrld xmm6, 7
	movdqa xmm8, xmm5
	psrld xmm7, 18
	pslld xmm8, 14
	por xmm7, xmm8 ; ROTR(x, 18)
	psrld xmm5, 3
	pslld xmm8, 11 
	pxor xmm5, xmm7 
	por xmm6, xmm8 ; xmm6 = ROTR(x, 7)
	movdqa %1, %4
	pxor xmm5, xmm6  ; xmm5 = sig0(W[t-15]), sig0(W[t+1-15]), sig0(W[t+2-15]), sig0(W[t+3-15])
	psrldq %1, 8 ; xmm0 = 0, 0, W[t-1], W[t-2]
	paddd xmm5, xmm4 ; xmm5 = W - sig1
	; calculo sig1(W[t-2]) y sig1(W[t+1-2]), solo se puede calcular 2 en paralelo en este punto
	; sig1(x) = (ROTR(x, 17) ^ ROTR(x, 19) ^ (x >> 10))
	; cuando se llame a esta macro nuevamente, xmm0 "avanza 16 bytes"
	movdqa xmm6, %1
	movdqa xmm7, %1
	psrld xmm6, 17
	movdqa xmm8, %1
	psrld xmm7, 19
	pslld xmm8, 13
	psrld %1, 10
	por xmm7, xmm8 ; xmm7 = ROTR(x, 19)
	pslld xmm8, 2
	pxor %1, xmm7
	por xmm6, xmm8 ; xmm6 = ROTR(x, 17)
	pxor %1, xmm6 ; xmm0 = 0, 0, sig1(W[t-1]), sig1(W[t-2])
	paddd %1, xmm5 ; xmm0 = ?, ?, W[t+1], W[t]
	pslldq %1, 8
	psrldq %1, 8 ; xmm0 = 0, 0, W[t+1], W[t]
	; ahora que ya tengo W[t-1], W[t-2], puedo calcular los dos restantes
	movdqa xmm9, %1
	pslldq xmm9, 8 ; xmm9 = W[t+1], W[t], 0, 0
	movdqa xmm6, xmm9
	movdqa xmm7, xmm9
	psrld xmm6, 17
	movdqa xmm8, xmm9
	psrld xmm7, 19
	pslld xmm8, 13
	psrld xmm9, 10
	por xmm7, xmm8 ; xmm7 = ROTR(x, 19)
	pslld xmm8, 2
	pxor xmm9, xmm7
	por xmm6, xmm8 ; xmm6 = ROTR(x, 17)
	pxor xmm9, xmm6 ; xmm9 = sig1(W[t+1]), sig1(W[t]), ?, ?
	paddd xmm9, xmm5; xmm9 = W[t+3], W[t+4], ?, ?
	psrldq xmm9, 8
	pslldq xmm9, 8 ; xmm9 = W[t+3], W[t+4], 0, 0
	
	; uno los resultados
	por %1, xmm9
%endmacro

%macro iteracion_tercer_ciclo 0
		; calculo s1(e) = s1(r8d)
		mov r14d, r8d
		mov r15d, r8d
		ror r14d, 6
		ror r15d, 11
		xor r14d, r15d
		mov r15d, r8d
		ror r15d, 25
		xor r14d, r15d
		
		; se lo sumo a T1 = r11d
		add r11d, r14d
	
		; calculo Ch(e,f,g) = Ch(r8d, r9d, r10d)
		mov r14d, r8d
		mov r15d, r8d
		and r14d, r9d
		not r15d
		and r15d, r10d
		xor r14d, r15d
		
		; se lo sumo a T1 = r11d
		add r11d, r14d
		

		; le sumo a T1 K[t] y W[t], t = rsi
		add dword r11d, edi
		add dword r11d, [K + 4*rsi]
		shr rdi, 32

		; calculo s0(a) = s0(eax)
		mov r15d, eax
		mov r14d, eax
		ror r15d, 13
		ror r14d, 2
		xor r14d, r15d
		mov r15d, eax
		ror r15d, 22
		xor r14d, r15d
		mov r13d, r14d
		
		; calculo Maj(a,b,c) = Maj(eax, edx, esi)
		mov r14d, eax
		mov r15d, eax
		and r14d, edx
		and r15d, ebx
		xor r14d, r15d
		mov r15d, edx
		and r15d, ebx
		xor r14d, r15d
		
		add r13d, r14d				
		; actualizo variables
		mov r14d, eax
		mov r15d, r8d

		mov r8d, r12d
		add r8d, r11d
		
		mov eax, r11d
		add eax, r13d
		
		mov r11d, r10d
		mov r10d, r9d
		mov r9d, r15d
		mov r12d, ebx
		mov ebx, edx
		mov edx, r14d
		
		add rsi, 1
		
%endmacro

; void process_block_SIMD(uchar *M, uint *H) 
; rdi = M
; rsi = H
process_block_simd:
	push rbp
	mov rbp, rsp
	push rbx
	push r12
	push r13
	push r14
	push r15
	sub rsp, 8

				
	;; 2 - initialize the 8 working variables
	mov dword eax, [rsi]
	mov dword edx, [rsi + 4]
	mov dword ebx, [rsi + 8]
	mov dword r12d, [rsi + 12]
	mov dword r8d, [rsi + 16]
	mov dword r9d, [rsi + 20]
	mov dword r10d, [rsi + 24]
	mov dword r11d, [rsi + 28]

	push rsi
	xor rsi, rsi
	movdqa xmm13, [shuf_mask_1]
	
	;; 1 - Preparar el message schedule
	.primer_ciclo:
		;W[t] = (M[4*t] << 24) | (M[4*t + 1] << 16) | (M[4*t + 2] << 8) | M[4*t + 3]
		movdqa xmm0, [rdi]
		movdqa xmm1, [rdi+16]
		pshufb xmm0, xmm13
		movdqa xmm2, [rdi+32]
		pshufb xmm1, xmm13
		movdqa xmm3, [rdi+48]
		pshufb xmm2, xmm13
		pshufb xmm3, xmm13

		movdqa xmm10, xmm0
		movq rdi, xmm0
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		psrldq xmm10, 8
		movq rdi, xmm10
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		
		movdqa xmm10, xmm1
		movq rdi, xmm1
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		psrldq xmm10, 8
		movq rdi, xmm10
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		
		movdqa xmm10, xmm2
		movq rdi, xmm2
		psrldq xmm10, 8
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		movq rdi, xmm10
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		
		movdqa xmm10, xmm3
		movq rdi, xmm3
		psrldq xmm10, 8
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		movq rdi, xmm10
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		
	mov rcx, 3
	.segundo_ciclo:
		; W[t] = sig1(W[t-2]) + W[t-7] + sig0(W[t-15]) + W[t-16]
		iteracion_segundo_ciclo xmm0, xmm1, xmm2, xmm3
		movq rdi, xmm0
		movdqa xmm10, xmm0
		psrldq xmm10, 8
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		movq rdi, xmm10
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		
		iteracion_segundo_ciclo xmm1, xmm2, xmm3, xmm0
		movq rdi, xmm1
		movdqa xmm10, xmm1
		psrldq xmm10, 8
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		movq rdi, xmm10
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		
		iteracion_segundo_ciclo xmm2, xmm3, xmm0, xmm1
		movq rdi, xmm2
		movdqa xmm10, xmm2
		psrldq xmm10, 8
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		movq rdi, xmm10
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		
		iteracion_segundo_ciclo xmm3, xmm0, xmm1, xmm2
		movq rdi, xmm3
		movdqa xmm10, xmm3
		psrldq xmm10, 8
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo
		movq rdi, xmm10
		iteracion_tercer_ciclo
		iteracion_tercer_ciclo

		dec rcx
		jnz .segundo_ciclo

	pop rsi
	
	add dword [rsi], eax
	add dword [rsi + 4], edx
	add dword [rsi + 8], ebx
	add dword [rsi + 12], r12d
	add dword [rsi + 16], r8d
	add dword [rsi + 20], r9d
	add dword [rsi + 24], r10d
	add dword [rsi + 28], r11d
	
	add rsp, 8
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
		
	ret
