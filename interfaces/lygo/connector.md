# Lygo Connector Pin Layout

The Lygo slot connector provides high-speed serial connectivity and is available in two physical lengths supporting 1 or 2 ports of each 6 lanes.

## Base Key – 24 Pins
These pins are present on every connector, regardless of lane count.

| Pin Range | Function   | Notes                                     |
|-----------|------------|-------------------------------------------|
|  1– 8     | 24 V Power |                                           |
|  9–16     | JTAG       | gnd, vref, tck, tms, tdi, tdo, reset, gnd |
| 17–24     | 3 V Power  |                                           |

## Lane Ports
After the 24-pin key, the connector carries one or two lane ports. Each lane port contains six physical lanes and occupies 52 pins. Connectors are either single-port 6-lane or dual-port 6-lane.

### Pin map per port
| Pin Range | Function   | Notes                |
|-----------|------------|--------------------- |
|  1– 4     | Clock      | gnd, clk+, clk−, gnd |

### Pin Map per Lane (x6 per port)
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
| Ports | Total Pins |
|-------|------------|
|  1    |  76        |
|  2    | 128        |

Physical expansion is done in ports of six lanes, while logically the system operates on pairs of lanes (so 2, 4 or 6).

In prototype-1 only 2 lanes are used per port