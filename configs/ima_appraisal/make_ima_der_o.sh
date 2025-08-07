#!/bin/sh
# Adjust this to the prefix of your RISC‑V toolchain (e.g. riscv64-linux-gnu- or riscv64-unknown-linux-musl-)
CROSS_COMPILE=CROSS_COMPILE="/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-"

# Use the cross‑compiler's objcopy
OBJCOPY="${CROSS_COMPILE}objcopy"

# Input DER certificate (must exist in certs/)
DER_FILE=/build/kernel/certs/ima.der

# Output object
OBJ_FILE=/build/kernel/certs/ima_der.o

# Create the ELF object: binary → elf64-littleriscv, RISC‑V little‑endian
"${OBJCOPY}" -I binary -O elf64-littleriscv -B riscv "${DER_FILE}" "${OBJ_FILE}"
echo "Generated ${OBJ_FILE}"


/host-tools/gcc/riscv64-linux-musl-x86_64/bin/riscv64-unknown-linux-musl-objcopy -I binary -O elf64-littleriscv -B riscv /build/kernel/certs/ima.der /build/kernel/certs/ima_der.o
