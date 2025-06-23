; 1. Version where one assembly instruction is one machine code instruction

START:
	Lis	low#4
	MOVis	R0
	Lis	low#0
	MOVis	R1
LOOP:
	SRMOV	PC, LR
	Lis	low#SUB		; relative to PC
	BRAis
	Lis	low#1
	SUBis	R0
	Lis	low#0
	CMPis	R0
	Lis	low#LOOP	; relative to PC
	BGTis
	HLT
SUB:
	Lis	low#1
	ADDis	R1
	SRBRA	LR+1

; 2. Shorter version

START:
	MOVis	low#4, R0
	MOVis	low#0, R1
LOOP:
	SRMOV	PC, LR
	BRAis	#SUB
	SUBis	low#1, R0
	CMPis	low#0, R0
	BGTis	#LOOP
	HLT
SUB:
	ADDis	low#1, R1
	SRBRA	LR+1
