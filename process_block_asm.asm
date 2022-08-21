global process_block_asm

%define BLOCK_SIZE 64 ; En bytes

extern print_result

section .data
	
	K:		dd 0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
			dd 0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
		 	dd 0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
			dd 0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
		 	dd 0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
			dd 0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
			dd 0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
			dd 0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
	W:		times 64 dd 0
	M: 		dq 0x0000000000000000
	M2:		dq 0x0000000000000000
	l:		dq 0
	modo:	db 'r', 0

section .text

;void process_block_asm(uchar *M, uint *H)
;rdi = &M
;rsi = &H
process_block_asm:
	push rbp
	mov rbp, rsp
	push rbx
	push r12
	push r13
	push r14
	push r15
	sub rsp, 8
	
	mov r12, rdi
	mov rbx, rsi
	;; 1 - Preparar el message schedule
	xor rcx, rcx
	primer_ciclo:
		;W[t] = (M[4*t] << 24) | (M[4*t + 1] << 16) | (M[4*t + 2] << 8) | M[4*t + 3];
		xor r9, r9
		xor r10, r10
		xor rax, rax
		xor r13, r13
		
		mov r8, rcx
		shl r8, 2

		mov r9d, [r12 + r8]
		shl r9d, 24
		
		mov byte r10b, [r12 + r8 + 1]
		shl r10, 16
		
		mov byte al, [r12 + r8 + 2]
		shl rax, 8
		
		mov byte r13b, [r12 + r8 + 3]
		
		or r9d, r10d
		or r9d, eax
		or r9d, r13d
		
		mov dword [W + 4*rcx], r9d

		inc rcx
		cmp rcx, 16
		jne primer_ciclo

	mov rcx, 16 ; innecesario
	
	segundo_ciclo:
		; W[t] = sig1(W[t-2]) + W[t-7] + sig0(W[t-15]) + W[t-16];
		mov r8, rcx

		sub r8, 2
		mov dword r9d, [W + 4*r8]
		sub r8, 5
		mov dword r10d, [W + 4*r8]
		sub r8, 8
		mov dword eax, [W + 4*r8]
		dec r8
		mov dword r13d, [W + 4*r8]
		
		; r9d = sig1(r9d)
		mov r14d, r9d
		mov r15d, r9d
		ror r14d, 17
		ror r15d, 19
		shr r9d, 10
		xor r9d, r14d
		xor r9d, r15d
		
		; eax = sig0(eax)
		mov r14d, eax
		mov r15d, eax
		ror r14d, 7
		ror r15d, 18
		shr eax, 3
		xor eax, r15d
		xor eax, r14d
		
		; sig1(W[t-2]) = r9d, W[t-7] = r10d, sig0(W[t-15]) = r12d, W[t-16] = r13d
		add r9d, r10d
		add r9d, eax
		add r9d, r13d
		mov dword [W + 4*rcx], r9d
			
		inc rcx
		cmp rcx, 64
		jnz segundo_ciclo		

			
	;; 2 - initialize the 8 working variables	
	mov dword eax, [rbx]
	mov dword edx, [rbx + 4]
	mov dword esi, [rbx + 8]
	mov dword edi, [rbx + 12]
	mov dword r8d, [rbx + 16]
	mov dword r9d, [rbx + 20]
	mov dword r10d, [rbx + 24]
	mov dword r11d, [rbx + 28]
	
	;; 3 -	
	xor rcx, rcx
	tercer_ciclo:
		
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
		
		; le sumo a T1 K[t] y W[t], t = rcx
		add dword r11d, [K + 4*rcx]
		add dword r11d, [W + 4*rcx]		

		; calculo s0(a) = s0(eax), no se usa r11d, se puede ejecutar mientras se espera a la memoria
		mov r14d, eax
		ror r14d, 2
		mov r15d, eax
		ror r15d, 13
		xor r14d, r15d
		mov r15d, eax
		ror r15d, 22
		xor r14d, r15d
		mov r13d, r14d
		
		; calculo Maj(a,b,c) = Maj(eax, edx, esi)
		mov r14d, eax
		and r14d, edx
		mov r15d, eax
		and r15d, esi
		xor r14d, r15d
		mov r15d, edx
		and r15d, esi
		xor r14d, r15d
		
		add r13d, r14d				
		; actualizo variables
		mov r14d, eax
		mov r15d, r8d

		mov r8d, edi
		add r8d, r11d
		
		mov eax, r11d
		add eax, r13d
		
		mov r11d, r10d
		mov r10d, r9d
		mov r9d, r15d
		mov edi, esi
		mov esi, edx
		mov edx, r14d	
	
		inc rcx
		cmp rcx, 64
		jne tercer_ciclo
	
	add dword [rbx], eax
	add dword [rbx + 4], edx
	add dword [rbx + 8], esi
	add dword [rbx + 12], edi
	add dword [rbx + 16], r8d
	add dword [rbx + 20], r9d
	add dword [rbx + 24], r10d	
	add dword [rbx + 28], r11d
	
	add rsp, 8
	pop r15
	pop r14
	pop r13
	pop r12
	pop rbx
	pop rbp
	ret
