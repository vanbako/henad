# opclass 1000 Stack helpers

PUSHur      DRs, (ARt)         ; --1(ARt) = DRs;
    isa                push ds, (at)
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0000
    [15-14] ARt
    [13-10] DRs
    [ 9- 0] RESERVED
    {}
    µops
        SUBAsi      #1, ARt
        STso        DRs, #0(ARt)
PUSHAur     ARs, (ARt)         ; --2(ARt) = ARs;
    isa                push as, (at)
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0001
    [15-14] ARt
    [13-12] ARs
    [11- 0] RESERVED
    {}
    µops
        SUBAsi      #2, ARt
        STAso       ARs, #0(ARt)
POPur       (ARs), DRt         ; DRt = (ARs)1++
    isa                pop (as), dt
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0010
    [15-12] DRt
    [11-10] ARs
    [ 9- 0] RESERVED
    {}
    µops
        ADDAsi      #1, ARs
        LDso        #-1(ARs), DRt
POPAur      (ARs), ARt         ; ARt = (ARs)2++
    isa                pop (as), at
    [23-20] opclass            ; 1000
    [19-16] subop              ; 0011
    [15-14] ARt
    [13-12] ARs
    [11- 0] RESERVED
    {}
    µops
        ADDAsi      #2, ARs
        LDAso       #-2(ARs), ARt
