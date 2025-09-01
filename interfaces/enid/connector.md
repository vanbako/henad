# enid Connector Pin Layout

The enid slot connector provides high-speed serial connectivity and is available in two physical lengths supporting 1 or 2 ports of each 6 lanes.

## Base Key – 24 Pins

These pins are present on every connector, regardless of lane count.

| 24V |   A |   B |     |
|-----|-----|-----|-----|
| GND |   0 |   1 | GND |
| VCC |   2 |   3 | VCC |
| VCC |   4 |   5 | VCC |
| GND |   6 |   7 | GND |

| JTAG  |   A |   B |      |
|-------|-----|-----|------|
| GND   |   8 |   9 | VREF |
| TCK   |  10 |  11 | TMS  |
| TDI   |  12 |  13 | TDO  |
| RESET |  14 |  15 | GND  |

| 3V  |   A |   B |     |
|-----|-----|-----|-----|
| GND |  16 |  17 | GND |
| VCC |  18 |  19 | VCC |
| VCC |  20 |  21 | VCC |
| GND |  22 |  23 | GND |

So the connector key block is

|       |   A |   B |       |
|-------|-----|-----|-------|
| GND   |   0 |   1 | GND   |
| VCC24 |   2 |   3 | VCC24 |
| VCC24 |   4 |   5 | VCC24 |
| GND   |   6 |   7 | GND   |
| GND   |   8 |   9 | VREF  |
| TCK   |  10 |  11 | TMS   |
| TDI   |  12 |  13 | TDO   |
| RESET |  14 |  15 | GND   |
| GND   |  16 |  17 | GND   |
| VCC3  |  18 |  19 | VCC3  |
| VCC3  |  20 |  21 | VCC3  |
| GND   |  22 |  23 | GND   |

## Lane Ports

After the 24-pin key, the connector carries one or two lane ports. Each lane port contains six physical lanes. Connectors are either single-port 6-lane or dual-port 6-lane.

### Single port layout

|       |   A |   B |       |
|-------|-----|-----|-------|
| GND   |  24 |  25 | GND   |
| CLK_P |  26 |  27 | GND   |
| CLK_N |  28 |  29 | GND   |
| GND   |  30 |  31 | RX0_P |
| GND   |  32 |  33 | RX0_N |
| TX0_P |  34 |  35 | GND   |
| TX0_N |  36 |  37 | GND   |
| GND   |  38 |  39 | RX1_P |
| GND   |  40 |  41 | RX1_N |
| TX1_P |  42 |  43 | GND   |
| TX1_N |  44 |  45 | GND   |
| GND   |  46 |  47 | RX2_P |
| GND   |  48 |  49 | RX2_N |
| TX2_P |  50 |  51 | GND   |
| TX2_N |  52 |  53 | GND   |
| GND   |  54 |  55 | RX3_P |
| GND   |  56 |  57 | RX3_N |
| TX3_P |  58 |  59 | GND   |
| TX3_N |  60 |  61 | GND   |
| GND   |  62 |  63 | RX4_P |
| GND   |  64 |  65 | RX4_N |
| TX4_P |  66 |  67 | GND   |
| TX4_N |  68 |  69 | GND   |
| GND   |  70 |  71 | RX5_P |
| GND   |  72 |  73 | RX5_N |
| TX5_P |  74 |  75 | GND   |
| TX5_N |  76 |  77 | GND   |
| GND   |  78 |  79 | GND   |

### Dual port layout

|        |   A |   B |        |
|--------|-----|-----|--------|
| GND    |  24 |  25 | GND    |
| CLKA_P |  26 |  27 | GND    |
| CLKA_N |  28 |  29 | GND    |
| GND    |  30 |  31 | CLKB_P |
| GND    |  32 |  33 | CLKB_N |
| TX0A_P |  34 |  35 | GND    |
| TX0A_N |  36 |  37 | GND    |
| GND    |  38 |  39 | TX0B_P |
| GND    |  40 |  41 | TX0B_N |
| RX0A_P |  42 |  43 | GND    |
| RX0A_N |  44 |  45 | GND    |
| GND    |  46 |  47 | RX0B_P |
| GND    |  48 |  49 | RX0B_N |
| TX1A_P |  50 |  51 | GND    |
| TX1A_N |  52 |  53 | GND    |
| GND    |  54 |  55 | TX1B_P |
| GND    |  56 |  57 | TX1B_N |
| RX1A_P |  58 |  59 | GND    |
| RX1A_N |  60 |  61 | GND    |
| GND    |  62 |  63 | RX1B_P |
| GND    |  64 |  65 | RX1B_N |
| TX2A_P |  66 |  67 | GND    |
| TX2A_N |  68 |  69 | GND    |
| GND    |  70 |  71 | TX2B_P |
| GND    |  72 |  73 | TX2B_N |
| RX2A_P |  74 |  75 | GND    |
| RX2A_N |  76 |  77 | GND    |
| GND    |  78 |  79 | RX2B_P |
| GND    |  80 |  81 | RX2B_N |
| TX3A_P |  82 |  83 | GND    |
| TX3A_N |  84 |  85 | GND    |
| GND    |  86 |  87 | TX3B_P |
| GND    |  88 |  89 | TX3B_N |
| RX3A_P |  90 |  91 | GND    |
| RX3A_N |  92 |  93 | GND    |
| GND    |  94 |  95 | RX3B_P |
| GND    |  96 |  97 | RX3B_N |
| TX4A_P |  98 |  99 | GND    |
| TX4A_N | 100 | 101 | GND    |
| GND    | 102 | 103 | TX4B_P |
| GND    | 104 | 105 | TX4B_N |
| RX4A_P | 106 | 107 | GND    |
| RX4A_N | 108 | 109 | GND    |
| GND    | 110 | 111 | RX4B_P |
| GND    | 112 | 113 | RX4B_N |
| TX5A_P | 114 | 115 | GND    |
| TX5A_N | 116 | 117 | GND    |
| GND    | 118 | 119 | TX5B_P |
| GND    | 120 | 121 | TX5B_N |
| RX5A_P | 122 | 123 | GND    |
| RX5A_N | 124 | 125 | GND    |
| GND    | 126 | 127 | RX5B_P |
| GND    | 128 | 129 | RX5B_N |
| GND    | 130 | 131 | GND    |

Physical expansion is done in ports of six lanes, while logically the system operates on pairs of lanes (so 2, 4 or 6).

In prototype-1 only 2 lanes are used per port
