# opclass 1001 CSR access

CSRRD     #csr8, DRt          ; DRt = CSR[csr8] (24-bit)
    isa                csr_read csr8, dt
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0000
    [15-12] DRt
    [11- 8] RESERVED
    [ 7- 0] csr8
    {Z}

CSRWR     DRs, #csr8          ; CSR[csr8] = DRs (24-bit)
    isa                csr_write ds, csr8
    [23-20] opclass            ; 1001
    [19-16] subop              ; 0001
    [15-14] RESERVED
    [13-10] DRs
    [ 9- 8] RESERVED
    [ 7- 0] csr8
    {}
