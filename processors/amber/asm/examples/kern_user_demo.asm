; Kernel/User mode demo using SWI/SRET and absolute handler

.org 0
    MOVSI #0x001, DR1         ; user: set DR1
    SWIUI #0x000000000040     ; trap to absolute 0x40, enters kernel, LR=PC+1
    MOVSI #0x123, DR2         ; resumes here after SRET
    SRHLT                     ; halt

.org 64
    ; kernel handler at 0x40
    MOVSI #0x777, DR3         ; do something in kernel
    SRET                      ; return to LR (PC+1 from SWI)

