; Example: User-defined macros with params and .local

    .org 0

.macro SAVE2 r1, r2
    .local Ldone
    PUSHur {r1}, AR0
    PUSHur {r2}, AR0
Ldone:
.endm

.macro REST2 r1, r2
    POPur  AR0, {r2}
    POPur  AR0, {r1}
.endm

start:
    MOVui #0x11, DR1
    MOVui #0x22, DR2
    SAVE2 DR1, DR2
    ; do work ...
    REST2 DR1, DR2

