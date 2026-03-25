# 4x4-matrix-multiplication-on-fpga
# 4×4 Matrix Multiplier on FPGA
**Device:** EP2C35F672C6 (Cyclone II, DE2 Board)  
**Tool:** Quartus II 13.0 / ModelSim

---

## Overview
Hardware implementation of 4×4 matrix multiplication **C = A × B** using a Multiply-Accumulate (MAC) unit on the Altera Cyclone II FPGA.

Both matrices A and B are pre-loaded via switches before computation. After pressing START, the MAC engine runs fully autonomously at 50 MHz with zero human timing dependency.

---

## Repository Structure
```
├── src/
│   ├── matrix4x4_mac.v     # MAC engine + mac_unit (top compute module)
│   └── de2_matrix_top.v    # DE2 board top level (I/O, display, debounce)
├── tb/
│   └── tb_matrix4x4_mac.v  # ModelSim testbench (random matrix tests)
├── constraints/
│   └── de2_matrix_top.qsf  # Quartus pin assignments for EP2C35F672C6
└── README.md
```

---

## Architecture

```
SW[7:0]  ──► data_in ──► load_a/load_b ──► mat_a[0..15] ┐
SW[9:8]  ──► row_sel                      mat_b[0..15] ┘
SW[11:10]──► col_sel                            │
SW[13:12]──► mat_sel                       KEY[2] START
                                                │
                                     ┌─── matrix4x4_mac ───┐
                                     │  for row=0..3:       │
                                     │   for col=0..3:      │
                                     │    for k=0..3:       │
                                     │     acc+=A[row][k]   │
                                     │         *B[k][col]   │
                                     │    C[row][col]=acc   │
                                     └──────────────────────┘
                                          │          │
                                       LEDR        HEX7..4
                                       LEDG        (result)
```

### FSM States
| State | Action |
|-------|--------|
| `IDLE` | Wait for start pulse |
| `LOAD` | Feed A[row][k] and B[k][col] to MAC unit for k=0..3 |
| `WAIT` | 1-cycle pipeline bubble |
| `CAPTURE` | Latch mac_acc → C[row][col], assert C_valid |
| `CLEARWAIT` | Clear accumulator, advance col/row |
| `DONE` | Assert done, return to IDLE |

---

## Switch & Key Mapping

| Signal | Function |
|--------|---------|
| `SW[7:0]` | 8-bit element value |
| `SW[9:8]` | Row select (0–3) |
| `SW[11:10]` | Column select (0–3) |
| `SW[13:12]=00` | Select matrix A for entry/view |
| `SW[13:12]=01` | Select matrix B for entry/view |
| `SW[13:12]=10` | View result matrix C |
| `KEY[0]` | Reset |
| `KEY[1]` | Store element (debounced) |
| `KEY[2]` | Start computation (debounced) |

---

## HEX Display

| Display | Shows |
|---------|-------|
| `HEX1, HEX0` | Current SW[7:0] live value |
| `HEX2` | Row selected |
| `HEX3` | Column selected |
| `HEX7..HEX4` | Stored value at selected position (A, B, or C) |

---

## LED Indicators

| LED | Meaning |
|-----|---------|
| `LEDR[0]` | MAC ready (IDLE state) |
| `LEDR[1]` | All done (16 results computed) |
| `LEDR[2]` | C_valid pulse (result available) |
| `LEDR[3]` | Computing in progress |
| `LEDG[1:0]` | C_row of last result |
| `LEDG[3:2]` | C_col of last result |

---

## Operation Steps

### 1. Reset
Press **KEY[0]**

### 2. Enter Matrix A (16 elements)
Set `SW[13:12] = 00`
```
For each element:
  SW[9:8]   = row (0–3)
  SW[11:10] = col (0–3)
  SW[7:0]   = value
  Press KEY[1]
```

### 3. Enter Matrix B (16 elements)
Set `SW[13:12] = 01`, same procedure as A.

### 4. Compute
Press **KEY[2]** once → `LEDR[1]` lights when done.

### 5. Read Results
Set `SW[13:12] = 10`
```
SW[9:8]=row, SW[11:10]=col → HEX7..4 shows C[row][col]
```

---

## Verification Example

**A = Identity, B = 1..16 → Expected C = B**

| C element | Expected | HEX7..4 |
|-----------|----------|---------|
| C[0][0] | 1 | 0001 |
| C[0][1] | 2 | 0002 |
| C[1][0] | 5 | 0005 |
| C[3][3] | 16 | 0010 |

---

## Simulation (ModelSim)

```tcl
vlog src/matrix4x4_mac.v tb/tb_matrix4x4_mac.v
vsim -gui work.tb_matrix4x4_mac
add wave *
run -all
```

Expected output:
```
TEST 1: Random Matrices
  Matrix A: ...
  Matrix B: ...
  Golden C: ...
  C[0][0] Got=X  Expected=X  PASS
  ...
  >> Test 1 PASSED!

ALL TESTS PASSED!
```

---

## Quartus Compilation

1. Open Quartus II
2. **File → New Project Wizard**
   - Top entity: `de2_matrix_top_full`
   - Device: `EP2C35F672C6`
3. Add `src/matrix4x4_mac.v` and `src/de2_matrix_top.v`
4. **Assignments → Import Assignments** → select `constraints/de2_matrix_top.qsf`
5. **Processing → Start Compilation**
6. **Tools → Programmer** → load `.sof` to board

> ⚠️ Verify pin assignments against your exact board revision before programming.

---

## Result Range
- A, B elements: 8-bit unsigned (0–255)
- Max C element: 4 × 255 × 255 = 260,100 → stored as 16-bit (max 65,535)
- Use values ≤ 127 per element to guarantee no overflow

---

## Files Summary

| File | Description |
|------|-------------|
| `src/matrix4x4_mac.v` | Core compute engine — MAC FSM + mac_unit |
| `src/de2_matrix_top.v` | Board top level — switches, keys, display, debounce |
| `tb/tb_matrix4x4_mac.v` | Testbench — 2 random matrix tests with golden reference |
| `constraints/de2_matrix_top.qsf` | Quartus pin assignments for EP2C35F672C6 |.
