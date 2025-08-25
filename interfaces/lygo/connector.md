# Lygo Connector Pin Layout

The Lygo connector provides high-speed serial connectivity and is available in three physical lengths supporting 4, 8, or 12 lanes.

## Base Key – 48 Pins
These pins are present on every connector, regardless of lane count.

| Pin Range | Function   | Notes                                     |
|-----------|------------|-------------------------------------------|
|  1– 8     | 24 V Power |                                           |
|  9–12     | Reserved   |                                           |
| 13–20     | JTAG       | gnd, vref, tck, tms, tdi, tdo, reset, gnd |
| 21–24     | Reserved   |                                           |
| 25–32     | 3 V Power  |                                           |
| 33–36     | Reserved   |                                           |
| 37–40     | Clock      | gnd, clk+, clk−, gnd                      |
| 41–48     | Reserved   |                                           |

## Lane Sets
After the 48-pin key, the connector carries one to three lane sets. Each lane set contains four physical lanes and occupies 32 pins. Connectors therefore come in 4-, 8-, or 12-lane versions.

### Pin Map per Lane
Each lane uses the following eight-pin pattern:

| Pin Offset | Signal |
|------------|--------|
| 1          | GND    |
| 2          | RX+    |
| 3          | RX−    |
| 4          | GND    |
| 5          | GND    |
| 6          | TX+    |
| 7          | TX−    |
| 8          | GND    |

### Connector Sizes
| Lanes | Lane Sets | Total Pins |
|-------|-----------|------------|
|  4    | 1         |  80        |
|  8    | 2         | 112        |
| 12    | 3         | 144        |

Physical expansion is done in groups of four lanes, while logically the system operates on pairs of lanes.
