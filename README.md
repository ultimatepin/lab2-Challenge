# Challenge: 16×16 Multiplier

**Created:** March 16, 2025  
**Class:** Spring


## Introduction

The task is to design a 16×16 multiplier with the following constraint:

- Use no more than 64 full adders (FAs) in total.

The design goals are:

- Minimize hardware usage, measured primarily by the number of FAs.
- Complete multiplication in as few cycles as possible.

My solution uses 58 FAs and completes the multiplication in two cycles.

## Algorithm

The design converts operands from the binary number system (BNS) to a residue number system (RNS). Each number is represented by its residues modulo a set of pairwise-coprime moduli. The result can then be reconstructed using the Chinese Remainder Theorem (CRT).

The following notation is used:

- $x$ and $y$: multiplication operands
- $a$, $b$, and $c$: moduli
- $n$: quotient of $xy$ divided by 4080
- $r$: remainder of $xy$ divided by 4080

```math
xy = 4080n + r
```

## Chinese Remainder Theorem

### Simplified theorem

For pairwise-coprime moduli $a$, $b$, and $c$, suppose:

```math
\begin{aligned}
x &\equiv r_a \pmod a, \\
x &\equiv r_b \pmod b, \\
x &\equiv r_c \pmod c.
\end{aligned}
```

Then there is a unique solution modulo $abc$:

```math
x \equiv r_{abc} \pmod{abc}.
```

Equivalently, when $0 \le x < abc$, the value of $x$ can be reconstructed from $x \bmod a$, $x \bmod b$, and $x \bmod c$.

### Reconstruction formula

Let:

- $m_i$ be one modulus,
- $c_i$ be the residue modulo $m_i$,
- $M = \prod_i m_i$,
- $M_i = M/m_i$,
- $y_i$ be the multiplicative inverse satisfying $M_i y_i \equiv 1 \pmod{m_i}$.

Then:

```math
r \equiv \sum_i c_i M_i y_i \pmod M,
\qquad 0 \le r < M.
```

## Implementing the CRT

The implementation has three main stages:

1. Convert each operand from BNS to RNS.
2. Multiply the residues in RNS.
3. Convert the RNS result back to BNS.

The selected moduli are 15, 16, and 17 because they are convenient for bit-level manipulation.

## Converting BNS to RNS

Residues modulo 15, 16, and 17 must be calculated for both $x$ and $y$. The same hardware structure is instantiated for each operand.

### Modulo 15

Because $16 \equiv 1 \pmod{15}$:

```math
\begin{aligned}
16k &= 15k + k
    &&\Longrightarrow 16k \equiv k \pmod{15}, \\
(10000)_2 k &= (1111)_2 k + k
    &&\Longrightarrow (10000)_2 k \equiv k \pmod{15}.
\end{aligned}
```

A 16-bit number can be divided into four 4-bit chunks:

```math
x =
\underbrace{1100}_{C_3}\,
\underbrace{1010}_{C_2}\,
\underbrace{0111}_{C_1}\,
\underbrace{0000}_{C_0}.
```

Therefore:

```math
\begin{aligned}
x &= C_3 2^{12} + C_2 2^8 + C_1 2^4 + C_0, \\
x &\equiv C_3 + C_2 + C_1 + C_0 \pmod{15}.
\end{aligned}
```

Each $C_i$ is a 4-bit number. Finding the residue modulo 15 therefore requires adding four 4-bit values, which can be implemented using 9 FAs, 3 half adders (HAs), and combinational logic.

![Modulo-15 conversion datapath](images/image.png)

The `OP15` block applies combinational logic to reduce a 5-bit number modulo 15.

![OP15 reduction block](<images/image 1.png>)

The input is the sum of two 4-bit values, so its range is 0 to 30 (`00000` to `11110`). When the input is at least 15, the block subtracts 15. Because the upper bit can be discarded, subtracting `1111` from the lower four bits is equivalent to adding `0001` in two's-complement arithmetic. The output is a 4-bit value in the range 0 to 14.

### Modulo 16

The four least-significant bits of a binary number are its residue modulo 16:

```math
x \bmod 16 = x(3{:}0).
```

A bus selector is therefore sufficient. This selection is combined with multiplication logic described later.

### Modulo 17

> This section incorporates the correction made after the original submission deadline.

Because $2^8 = 256 \equiv 1 \pmod{17}$:

```math
\begin{aligned}
256k &= 255k + k, \\
256k &\equiv k \pmod{17}, \\
2^8 k &\equiv k \pmod{17}.
\end{aligned}
```

Writing a 16-bit value as two 8-bit chunks gives:

```math
x =
\underbrace{11001010}_{C_1}\,
\underbrace{01110000}_{C_0}.
```

Hence:

```math
\begin{aligned}
x &= C_1 2^8 + C_0, \\
x &\equiv C_1 + C_0 \pmod{17}.
\end{aligned}
```

Each 8-bit chunk can be reduced further by splitting it into two 4-bit nibbles. For an 8-bit value $x = 16C_1 + C_0$:

```math
\begin{aligned}
x \bmod 17
  &= 17C_1 - C_1 + C_0 \\
  &= C_0 - C_1.
\end{aligned}
```

For a 4-bit value, the one's complement satisfies $\overline{C_1} = 15-C_1$. Therefore:

```math
\begin{aligned}
-C_1
  &= \overline{C_1} - 17 + 2, \\
x \bmod 17
  &= C_0 + \overline{C_1} - 17 + 2, \\
x \bmod 17
  &\equiv C_0 + \overline{C_1} + 2 \pmod{17}.
\end{aligned}
```

Modulo-17 conversion is divided into two stages: reduce each 8-bit chunk in parallel, then combine the two residues. The implementation uses 11 FAs and 1 HA.

#### Stage 1

![First stage of modulo-17 conversion](<images/image 2.png>)

#### Stage 2

`OP17.IN` is connected to `Merge.OUT`. The two parallel `OP17` outputs are residues in the range 0 to 16 and must be combined.

![Second stage of modulo-17 conversion](<images/image 3.png>)

Let the two residues be $A$ and $B$. Bit 4 is calculated separately from bits 3 through 0:

```math
\operatorname{OUT}(4)
=
\bigl(A(4)\oplus B(4)\bigr)\cdot \operatorname{EQ1.Q}.
```

The term $A(4)\oplus B(4)$ detects when exactly one input equals 16. If one operand is 16, then:

```math
16+n \equiv n-1 \pmod{17}.
```

The lower four bits of the other operand are therefore decremented using a multiplexer and a custom `MINUS1` block.

When both bit-4 inputs are zero, the lower values are added and reduced using `OP17`.

The original design failed when both $A$ and $B$ were 16, because:

```math
16+16 \equiv 15 \pmod{17}.
```

A multiplexer was added to handle this case.

![OP17 reduction block](<images/image 4.png>)

## Finding the Unique Solution

After calculating the residues modulo 15, 16, and 17, the residues are multiplied and recombined to obtain the unique result modulo 4080.

## Multiplying Residues

Residue multiplication follows from:

```math
\begin{aligned}
x &\equiv r_x \pmod a, \\
y &\equiv r_y \pmod a
\end{aligned}
\qquad\Longrightarrow\qquad
xy \equiv r_xr_y \pmod a.
```

### Multiplication modulo 15

CRT is used again with moduli 3 and 5.

![Modulo-15 residue multiplier](<images/image 5.png>)

`COMBINE3` and `COMBINE5` implement combinational reductions modulo 3 and modulo 5.

#### COMBINE3

![COMBINE3 block](<images/image 6.png>)

#### COMBINE5

![COMBINE5 block](<images/image 7.png>)

`CMY35` and `CMY53` produce the $c_iM_iy_i$ terms.

```math
M_3y_3 = 10.
```

![CMY35 block](<images/image 8.png>)

```math
M_5y_5 = 6.
```

![CMY53 block](<images/image 9.png>)

The two results are added to form a 6-bit value, which is then reduced modulo 15. Bits 5 and 4 are extended and folded into the lower bits. If bit 4 remains high, another subtraction of 15 is applied.

![Final modulo-15 reduction](<images/image 10.png>)

Finding $xy \bmod 15$ uses 7 FAs and 2 HAs.

### Multiplication modulo 16

The residue modulo 16 is obtained by multiplying and selecting bits 3 through 0 of the result. This selection is shared with later logic to save adders.

### Multiplication modulo 17

A 4-bit multiplier is used for the normal case.

![Modulo-17 residue multiplier](<images/image 11.png>)

The special cases involving 16 are handled separately:

- If both operands are 16, use $256 \equiv 1 \pmod{17}$.
- If exactly one operand is 16, shift the other operand left by four bits.
- If neither operand is 16, use the 4-bit multiplier, implemented with 8 FAs and 4 HAs.

The selected result is reduced by a modulo-17 block. The complete modulo-17 multiplication path uses 19 FAs and 5 HAs.

## Reconstruction Modulo 4080

The CRT constants are:

```math
M = 15\cdot16\cdot17 = 4080 = (1111\,1111\,0000)_2.
```

```math
\begin{aligned}
y_{15} &= 8, &
y_{16} &= 15, &
y_{17} &= 9, \\
M_{15}y_{15} &= 2176, &
M_{16}y_{16} &= 3825, &
M_{17}y_{17} &= 2160.
\end{aligned}
```

| Modulus $m_i$ | $M_i$ | $y_i$ | $M_iy_i$ | Binary representation |
| ---: | ---: | ---: | ---: | --- |
| 15 | 272 | 8 | 2176 | `1000 1000 0000` |
| 16 | 255 | 15 | 3825 | `1110 1111 0001` |
| 17 | 240 | 9 | 2160 | `1000 0111 0000` |

The three $c_iM_iy_i$ terms are generated, added, and reduced modulo 4080. Their constant-coefficient multipliers use bit manipulation rather than conventional adders.

### The $c_{15}M_{15}y_{15}$ term

Because:

```math
M_{15}y_{15} = (1000\,1000\,0000)_2,
```

and $c_{15}$ is only four bits wide, the product can be assembled without carry-generating additions.

![Constant multiplier for the modulo-15 term](<images/image 12.png>)

### The $c_{16}M_{16}y_{16}$ term

```math
M_{16}y_{16} = (1110\,1111\,0001)_2.
```

Bits 3 through 0 can be formed directly because they generate no carries.

For bits 7 through 4, a custom `NEGATE` block computes `10000 - IN` and outputs the lower four bits. Incrementing $c_{16}$ adds `1111` to this nibble, which is equivalent to subtracting 1.

Bits 11 through 8 use the same pattern, with an additional decrement because the first increment does not generate a carry. Bits 15 through 12 use a conditional `MINUS1` block.

![Constant multiplier for the modulo-16 term](<images/image 13.png>)

### The $c_{17}M_{17}y_{17}$ term

```math
M_{17}y_{17} = (1000\,0111\,0000)_2.
```

Bit 4 of the input is handled separately. For inputs below 16:

- Bits 3 through 0 are constant zero.
- Bits 6 through 4 use a 3-bit negation.
- Bits 10 through 7 subtract 1 for inputs below 8 and subtract 2 for inputs at least 8, compensating for a missing carry.
- Bits 14 through 11 require no carry correction.
- Bit 15 is constant zero.

Two multiplexers select the correct output when bit 4 of the input is set.

![Constant multiplier for the modulo-17 term](<images/image 14.png>)

The three 16-bit terms are reduced and added using 26 FAs and 7 HAs.

![CRT reconstruction datapath](<images/image 15.png>)

### MOD4080

Each `MOD4080` block uses 3 FAs to reduce a 16-bit input to a 12-bit residue.

Because:

```math
4080 = 4096 - 16 = (1111\,1111\,0000)_2,
```

the reduction can be implemented by folding the upper nibble into bits 11 through 4.

Bits 3 through 0 remain unchanged. Each conceptual subtraction of 4080 has one of two forms:

1. Decrement bits 15 through 12 and increment bits 11 through 4.
2. Leave bits 15 through 12 unchanged and increment bits 11 through 4 when bits 11 through 8 are `1111` and the lower addition generates a carry.

A final correction handles the `1111 1111` case in bits 11 through 4.

![MOD4080 block](<images/image 16.png>)

### MINUS4080

This block applies the bit-manipulation strategy above. The implementation is functional but could be optimized further.

![MINUS4080 block](<images/image 17.png>)

### ADDx3

Three 12-bit values are summed using 14 FAs and 2 HAs.

![ADDx3 block](<images/image 18.png>)

At this point, the remainder $r = xy \bmod 4080$ is known. The remaining task is to recover the quotient contribution.

## Finding the Final Product

Since:

```math
xy = 4080n + r,
```

the product can be reconstructed by adding 4080 to $r$, $n$ times:

```math
xy =
r +
\underbrace{4080 + 4080 + \cdots + 4080}_{n\ \text{times}}.
```

Adding 4080 adds `1111` to bits 7 through 4 while preserving the four least-significant bits. For a 16-bit result:

```math
65535 = 16\cdot4080 + 255.
```

This gives 16 possible values of $n$, which correspond to the 16 possible patterns in bits 7 through 4.

For example:

```math
\begin{aligned}
xy &= 34157, \\
34157 \bmod 4080 &= 1517, \\
34157 &= (1000\,0101\,0110\,1101)_2, \\
1517 &= (0000\,0101\,1110\,1101)_2.
\end{aligned}
```

Adding 4080 repeatedly gives:

```math
\begin{array}{c|c}
\text{Additions} & \text{Current sum} \\
\hline
1 & 0001\,0101\,1101\,1101 \\
2 & 0010\,0101\,1100\,1101 \\
3 & 0011\,0101\,1011\,1101 \\
4 & 0100\,0101\,1010\,1101 \\
5 & 0101\,0101\,1001\,1101 \\
6 & 0110\,0101\,1000\,1101 \\
7 & 0111\,0101\,0111\,1101 \\
8 & 1000\,0101\,0110\,1101
\end{array}
```

When bits 7 through 4 match the independently calculated benchmark, the current sum is the final product.

### Bits 7 Through 4 Logic

One `MULTx4` block, two `MULTx4LSB4` blocks, 6 FAs, and 2 HAs are used to calculate bits 7 through 4 of $xy$.

Write each operand as four 4-bit chunks:

```math
\begin{aligned}
x &= C_3 2^{12} + C_2 2^8 + C_1 2^4 + C_0, \\
y &= D_3 2^{12} + D_2 2^8 + D_1 2^4 + D_0.
\end{aligned}
```

Then:

```math
xy(7{:}4)
=
(C_0D_0)(7{:}4)
+
(C_1D_0)(3{:}0)
+
(C_0D_1)(3{:}0).
```

This logic also supplies $xy \bmod 16$, saving additional adders.

![Bits 7 through 4 calculation](<images/image 19.png>)

#### MULTx4

A 4×4 multiplier implemented with 8 FAs and 4 HAs.

![MULTx4 block](<images/image 20.png>)

#### MULTx4LSB4

A 4×4 multiplier that outputs only the four least-significant bits. It uses 3 FAs and 3 HAs.

![MULTx4LSB4 block](<images/image 21.png>)

### Cascaded 4080 Adder Logic

The cascaded adder receives:

1. `MOD4080`: the remainder $r$.
2. `BENCHMARK`: the calculated value of $xy(7{:}4)$.
3. `EN`: `1` when `MOD4080(7:4)` does not equal `BENCHMARK`; otherwise `0`.

![Cascaded 4080 adder top level](<images/image 22.png>)

Each stage outputs `NEXTEN` and `OUT`. Together with `BENCHMARK`, these become the inputs to the next stage.

![Cascaded adder chain](<images/image 23.png>)

`CASADD4080` clears `NEXTEN` when its output matches the benchmark. All later stages then pass the value through unchanged.

![CASADD4080 block](<images/image 24.png>)

The addition logic follows from two's-complement identities:

```math
\begin{aligned}
\overline{\overline{A}-B}
&=
\overline{-A-1+\overline{B}+1} \\
&=
\overline{-A+\overline{B}} \\
&=
-(-A+\overline{B})-1 \\
&=
-(-A-B-1)-1 \\
&=
A+B.
\end{aligned}
```

The final product is then available.

# Implementing `MULT` in EEP1

The 64-adder limit requires the operation to be split across two cycles. Stage 1 performs BNS-to-RNS conversion and part of the final-product calculation. Stage 2 performs residue multiplication, CRT reconstruction, and the remaining final-product logic.

## Two-Stage Design

### Stage 1

Two 16-bit registers and one new 4-bit register store intermediate values.

![Stage-1 design](<images/image 25.png>)

| Component | Count | Total FAs | Total HAs |
| --- | ---: | ---: | ---: |
| MOD15 | 2 | 18 (9 each) | 6 (3 each) |
| MOD17 | 2 | 22 (11 each) | 2 (1 each) |
| MULTx4 | 1 | 8 | 4 |
| MULTx4LSB4 | 1 | 3 | 3 |
| Other logic | 1 | 3 | 1 |
| **Total** | **7** | **54** | **16** |

### Stage 2

The values stored in the three registers are read and processed.

![Stage-2 design](<images/image 26.png>)

| Component | Count | Total FAs | Total HAs |
| --- | ---: | ---: | ---: |
| MULTRNS15 | 1 | 7 | 2 |
| CMY16 | 1 | 0 | 0 |
| MULTRNS17: MOD17 | 1 | 11 | 1 |
| MULTRNS17: MULTx4 | 1 | 8 | 4 |
| MULTRNS17: CMY17 | 1 | 0 | 0 |
| MULTRNS17 total | 1 | 19 | 5 |
| MOD4080 | 4 | 12 (3 each) | 4 (1 each) |
| ADDx3 | 1 | 14 | 3 |
| MULTx4LSB4 | 1 | 3 | 3 |
| Q4080 | 1 | 0 | 0 |
| Other logic | 1 | 3 | 1 |
| **Total** | **11** | **58** | **18** |

### ISSIE Error

I attempted to combine the adders:

![Attempted combined-adder design](<images/image 27.png>)

ISSIE reported an error that appeared to be related to functionality still under development:

![ISSIE error](<images/image 28.png>)

The two stages were therefore implemented separately in EEP1.

## Machine Code

Two registers must be written simultaneously during stage 1. Existing `MOV` instruction fields are not large enough to encode four register addresses and a multiplication opcode, so the unused `INS(15:13) = 111` prefix is assigned to `MULT`.

| 15 | 14 | 13 | 12 | 11 | 10 | 9 | 8 | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | 1 | 0 | a2 | a1 | a0 | d2 | b2 | b1 | b0 | c2 | c1 | c0 | d1 | d0 |
| 1 | 1 | 1 | 1 | a2 | a1 | a0 | X | b2 | b1 | b0 | c2 | c1 | c0 | X | X |

The assembler cannot encode this custom format, so operands are first loaded into registers with `MOV`, and the two `MULT` instructions are entered as machine code.

- `INS(15:13)`: `111`, selects `MULT`.
- `INS(12)`: `MULTOPC`; `0` selects stage 1 and `1` selects stage 2.
- `INS(11:9)`: register address `a`, read port A.
- `INS(7:5)`: register address `b`, read port B.
- `INS(4:2)`: register address `c`, write port C.
- `INS(8)` and `INS(1:0)`: register address `d`, the additional write port used in stage 1.

## EEP1 Modifications

### DPDECODE

A wire label named `INS1` extends the `INS` input.

The `AD1SELC` and `WEN1` logic were modified using XOR gates so that the output is high when exactly one of the normal-instruction condition and the `MULT` condition is high.

![DPDECODE AD1SELC modification](<images/image 29.png>)

![DPDECODE WEN1 modification](<images/image 30.png>)

New DPDECODE outputs were added:

- `D`: register-file address for `Rd`
- `MULTOPC`: `0` for stage 1 and `1` for stage 2
- `WEN0`: enables the second write port during stage 1
- `MULTEN`: enables multiplication logic in the ALU

![DPDECODE multiplication outputs](<images/image 31.png>)

### REGFILE

The register file was expanded to three write ports and three read ports. One read/write pair is reserved for `REG8`, a new register that stores intermediate multiplication data.

![Modified register file](<images/image 32.png>)

One register connection was simplified so the register can be read correctly.

![Readable register connection](<images/image 33.png>)

The two multiplexers and OR gate allow the two normal write ports to operate independently. At most two register enables are high: one register receives `DIN0`, and the other receives `DIN1`.

A custom `REG8` block provides an independent read port, write port, and enable signal.

![REG8 block](<images/image 34.png>)

### ALU

When `MULTEN` is zero, the output multiplexer selects the normal ALU result. During multiplication, `OUT` is written to `Rc`, and stage 1 also writes `OUT0` to `Rd`.

![ALU multiplication integration](<images/image 35.png>)

The completed CPU schematic is shown below.

![Final CPU schematic](<images/image 36.png>)

## Example

The ROM contents used for simulation are:

![ROM contents](<images/image 37.png>)

Addresses `0x0000` and `0x0001` contain:

```text
MOV R0, #47
MOV R1, #53
```

Addresses `0x0002` and `0x0003` contain the two custom `MULT` instructions.

### Stage 1 Instruction

```text
0x0002: 1110 0001 0011 1011
```

Decoded fields:

- `INS(15:13) = 111`: `MULT` opcode
- `INS(12) = 0`: stage 1
- `INS(11:9) = 000`: read $x$ from `R0`
- `INS(7:5) = 001`: read $y$ from `R1`
- `INS(4:2) = 110`: write port C to `R6`
- `INS(8), INS(1:0) = 111`: additional write port D to `R7`

### Stage 2 Instruction

```text
0x0003: 1111 1100 1111 0000
```

Decoded fields:

- `INS(15:13) = 111`: `MULT` opcode
- `INS(12) = 1`: stage 2
- `INS(11:9) = 110`: read port A from `R6`
- `INS(7:5) = 111`: read port B from `R7`
- `INS(4:2) = 100`: write the final product to `R4`
- `INS(8), INS(1:0) = 000`: `Rd` is unused

![Simulation result](<images/image 38.png>)

The simulation produces the expected result.
