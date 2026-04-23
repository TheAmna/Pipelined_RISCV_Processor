# ============================================================
# Bubble Sort - RISC-V Assembly
# Array: {23, 12, 5, 44, 98, 53, 6, 89, 32, 65}
# Array pre-loaded in DataMemory at word addresses 10-19
# No initialisation block needed - memory already has values
#
# Register usage:
#   x11 = constant 1       (used to check swapped flag)
#   x12 = SIZEC = 10       (array length)
#   x13 = swapped flag     (0=false, 1=true per pass)
#   x14 = loop counter i   (starts at 1, goes to SIZEC-1)
#   x15 = word address of c[i-1]
#   x16 = word address of c[i]
#   x17 = value of c[i-1]  (loaded from memory)
#   x18 = value of c[i]    (loaded from memory)
#   x19 = base address     (word address 10)
# ============================================================

# --- Initialise constants ---
addi x11, x0, 1       # x11 = 1  (constant, used to check swapped flag)
addi x12, x0, 10      # x12 = 10 (SIZEC = array length)
addi x19, x0, 10      # x19 = 10 (base word address of array)

# ============================================================
# OUTER LOOP
# Repeats full passes until no swap occurs in a pass
# ============================================================
OUTERLOOP:
addi x13, x0, 0       # x13 = 0  (swapped = false at start of pass)
addi x14, x0, 1       # x14 = 1  (i = 1, start inner loop from index 1)

# ============================================================
# INNER LOOP
# Compares c[i-1] and c[i], swaps if out of order
# ============================================================
INNERLOOP:
beq  x14, x12, END_INNER  # if i == SIZEC (10), exit inner loop

# compute word address of c[i-1]
addi x15, x14, -1         # x15 = i - 1
add  x15, x15, x19        # x15 = (i-1) + 10  = word address of c[i-1]

# compute word address of c[i]
add  x16, x14, x19        # x16 = i + 10      = word address of c[i]

# load values from memory
lw   x17, 0(x15)          # x17 = c[i-1]  (load from word address x15)
lw   x18, 0(x16)          # x18 = c[i]    (load from word address x16)

# compare - if c[i-1] <= c[i], no swap needed, skip to JUMP
blt  x17, x18, JUMP       # if c[i-1] < c[i]  -> skip swap
beq  x17, x18, JUMP       # if c[i-1] == c[i] -> skip swap

# swap: c[i] = c[i-1],  c[i-1] = c[i]
sw   x17, 0(x16)          # c[i]   = old c[i-1]
sw   x18, 0(x15)          # c[i-1] = old c[i]
addi x13, x0, 1           # swapped = true

JUMP:
addi x14, x14, 1          # i++
beq  x0,  x0,  INNERLOOP  # unconditional jump back to INNERLOOP

# ============================================================
# END OF INNER LOOP
# Check if any swap occurred this pass
# If swapped=true, do another full pass
# ============================================================
END_INNER:
beq  x13, x11, OUTERLOOP  # if swapped == 1, repeat outer loop

# ============================================================
# EXIT
# Array is now sorted in ascending order at mem[10]-mem[19]
# Sorted result: {5, 6, 12, 23, 32, 44, 53, 65, 89, 98}
# ============================================================
EXIT:
beq  x0, x0, EXIT         # infinite loop to keep PC visible in waveform
