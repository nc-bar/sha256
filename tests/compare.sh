#!/bin/sh
myhash="../sha256"
truehash="../sha256.sh"

if [ -f .myhash_c ]
then
    rm .myhash_c
fi

if [ -f .myhash_asm ]
then
    rm .myhash_asm
fi

if [ -f .truehash ]
then
	rm .truehash
fi

if [ -f .myhash_simd ]
then
	rm .myhash_simd
fi

if [ -f .myhash_simd_stitch ]
then
	rm .myhash_simd_stitch
fi


for file in $PWD/*
do
    if [ "$file" != "$PWD/generador" ]
    then 
		#echo "$file"
        $truehash $file >> .truehash
        $myhash $file c >> .myhash_c
		$myhash $file asm >> .myhash_asm
		$myhash $file simd >> .myhash_simd
		$myhash $file simd_stitch >> .myhash_simd_stitch
	fi	

done

	diff .myhash_asm .truehash
	if [ $? -ne 0 ]
	then
		echo "error en la version de assembler."
	else
		echo "Implementacion en Assembler funcionando correctamente"
	fi

	diff .myhash_c .truehash
	if [ $? -ne 0 ]
	then
		echo "error en la version de C."
	else
		echo "Implementacion en C funcionando correctamente"
	fi

	diff .myhash_simd .truehash
	if [ $? -ne 0 ]
	then
		echo "error en la version de SIMD"
	else
		echo "Implementacion en SIMD funcionando correctamente"
	fi

	diff .myhash_simd_stitch .truehash
	if [ $? -ne 0 ]
	then
		echo "error en la version de SIMD"
	else
		echo "Implementacion en SIMD con function stitching funcionando correctamente"
	fi

