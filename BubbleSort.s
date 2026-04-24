

# --- Initialise constants ---
addi x11, x0, 1            # x11 = 1  (constant, used to check swapped flag)
addi x12, x0, 10           # x12 = 10 (SIZEC = array length)
addi x19, x0, 10           # x19 = 10 (base word address of array)

# ============================================================
# OUTER LOOP
# ============================================================
OUTERLOOP:
addi x13, x0, 0            # x13 = 0  (swapped = false at start of pass)
addi x14, x0, 1            # x14 = 1  (i = 1)

# ============================================================
# INNER LOOP
# ============================================================
INNERLOOP:
beq  x14, x12, END_INNER   # if i == SIZEC exit inner loop

# compute word address of c[i-1]
addi x15, x14, -1          # x15 = i - 1
add  x15, x15, x19         # x15 = (i-1) + 10

# compute word address of c[i]
add  x16, x14, x19         # x16 = i + 10

# load values from memory
lw   x17, 0(x15)           # x17 = c[i-1]

# *** FIX: one instruction gap between the two LW instructions ***
# Without this gap, two consecutive loads cause a pipeline hazard  
# where x18 receives a stale forwarded value instead of the correct
# memory data. This addi recomputes x16 harmlessly (x16 = x14 + 0)
# and gives the pipeline one cycle to resolve the first load before
# the second load enters the MEM stage.
addi x16, x14, 0           # pipeline gap — x16 = x14 (will be corrected by add below)
add  x16, x16, x19         # x16 = x14 + 10 (recompute correct address)

lw   x18, 0(x16)           # x18 = c[i]

bge  x18, x17, JUMP       # if c[i] >= c[i-1] -> skip swap

# swap: c[i] = c[i-1],  c[i-1] = c[i]
sw   x17, 0(x16)           # c[i]   = old c[i-1]
sw   x18, 0(x15)           # c[i-1] = old c[i]
addi x13, x0, 1            # swapped = true

JUMP:
addi x14, x14, 1           # i++
beq  x0,  x0,  INNERLOOP   # unconditional jump back to INNERLOOP

END_INNER:
beq  x13, x11, OUTERLOOP   # if swapped == 1, repeat outer loop

EXIT:
beq  x0, x0, EXIT          # infinite loop
