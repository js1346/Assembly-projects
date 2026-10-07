# x86-64 Assembly Projects (NASM / Linux)

This repository contains two low-level systems programming projects written in **64-bit x86 Assembly (NASM)** for Linux. The codebase demonstrates multi-precision arithmetic, strict compliance with the **System V AMD64 ABI** calling convention, custom dynamic memory management via raw Linux kernel syscalls, and buffered I/O handling without relying on the C standard library (`libc`).

---

## Repository Structure

```text
.
├── 01-arithmetic-sequence/
│   └── arithmetic_sequence.asm   # C-callable arbitrary-precision arithmetic module
├── 02-string-rewriter/
│   └── string_rewriter.asm       # Standalone iterative string rewriting engine
└── README.md
```

---

## Project 1: Arbitrary-Precision Arithmetic Sequence (`arithmetic_sequence.asm`)

### Overview
A C-callable assembly module that computes the $k$-th term of an arithmetic sequence for signed big integers of arbitrary length ($64n$-bit two's complement representation):

$$a_k = a_0 + (a_1 - a_0) \cdot k$$

Because $(a_1 - a_0)$ can require up to $64n + 1$ bits and multiplying by a 64-bit signed integer $k$ expands the result further, the full value of $a_k$ occupies $n + 2$ 64-bit words. The module writes the lower $n$ words directly into the destination buffer `ak` and returns the highest 128 bits (words $n+1$ and $n+2$) via the `rdx:rax` register pair.

### Function Signature (System V AMD64 ABI)
```c
#include <stdint.h>
#include <stddef.h>

__int128 arithmetic_sequence(
    const uint64_t *a0, // rdi: Pointer to the 0-th term (n 64-bit words, two's complement)
    const uint64_t *a1, // rsi: Pointer to the 1-st term (n 64-bit words, two's complement)
    uint64_t *ak,       // rdx: Output buffer for the lower n words of the k-th term
    size_t n,           // rcx: Number of 64-bit words per big integer (n >= 1)
    int64_t k           // r8:  Signed 64-bit step index
);
```

### Key Technical Implementation Details
* **Sign Normalization:** Eliminates signed multiplication complexity by inspecting the sign bit of $k$ upfront (`test r8, r8`). If $k < 0$, the routine negates $k$ into an unsigned multiplier and swaps input pointers $a_0 \leftrightarrow a_1$, utilizing the algebraic identity $a_0 + (a_1 - a_0) \cdot k = a_0 + (a_0 - a_1) \cdot (-k)$.
* **Multi-Word Subtraction & Borrow Propagation:** Computes the base difference across $n$ 64-bit words in a tight loop using `sbb` (Subtract with Borrow) and captures signed overflow (`SF != OF`) via `setl` to sign-extend the $(n+1)$-th word.
* **Carry-Propagated Unsigned Multiplication:** Multiplies the multi-word difference by $\vert{}k\vert{}$ word-by-word using 128-bit hardware multiplication (`mul r8`), propagating 64-bit carries across iterations in `r12` (`add` / `adc`) and applying two's complement correction on the most significant word when the difference is negative.
* **Sign-Extended Final Addition:** Sign-extends the most significant bit of $a_0$ across two upper 64-bit words and adds $a_0$ to the intermediate product using `adc`, leaving the final upper 128 bits in `rdx:rax`.
* **ABI Compliance:** Properly saves and restores callee-saved registers (`push r12` / `pop r12`).

---

## Project 2: Iterative String Rewriting Engine (`string_rewriter.asm`)

### Overview
A standalone Linux executable (`_start`, zero `libc` dependencies) that performs $N$ iterations of parallel string substitution (Lindenmayer system / L-system) based on transformation rules read from standard input (`stdin`).

### Input Format
The program takes a single command-line argument `<iterations>` ($0 \le N \le 2^{32}-1$) and reads the initial configuration from `stdin`:
1. **Line 1:** The initial word (axiom), consisting of printable ASCII characters (codes `33` to `126`), terminated by a newline (`\n`, ASCII `10`).
2. **Subsequent Lines:** Substitution rules formatted as `<char><replacement_string>\n`, where the first character on the line is replaced by the remaining characters on that line during each iteration.
   * Each character can have at most one rule defined (duplicate rules trigger an error).
   * Characters without an explicit rule default to an identity mapping ($X \rightarrow X$).

**Example (`input.txt`):**
```text
A
AB
BA
```
* Initial word: `A`
* Rule 1: `A` $\rightarrow$ `B`
* Rule 2: `B` $\rightarrow$ `A` (or multi-character expansion such as `A` $\rightarrow$ `AB`)

### Key Technical Implementation Details
* **Custom Dynamic Memory Management (`mmap` / `mremap` / `munmap`):** Operates entirely without `malloc`/`free`. Allocates initial `4096`-byte memory pages via `sys_mmap` (`MAP_PRIVATE | MAP_ANONYMOUS`) and dynamically doubles buffer capacity on demand using `sys_mremap` (`MREMAP_MAYMOVE`) encapsulated in custom NASM macros (`enlarge`, `swap`).
* **$O(1)$ Rule Lookup Dictionary:** Builds a direct-indexed 127-entry offset table in the `.bss` section (`dictionary`). During each rewrite step, resolving a character's replacement string takes constant $O(1)$ time via scaled addressing (`[rsi + 8 * rax]`).
* **Ping-Pong Double Buffering:** Alternates pointers between two dynamically grown buffers (`word_before` in `r12` and `word_after` in `rbp`) at the end of each iteration, avoiding redundant memory copies.
* **Robust I/O & Error Handling:** Implements buffered `sys_read` and loop-guarded `sys_write` to handle partial reads/writes properly. Validates command-line bounds ($< 2^{32}$), checks ASCII ranges (`33`–`126`), rejects malformed lines, and guarantees clean deallocation of all mapped memory regions (`sys_munmap`) before exiting with code `0` (success) or `1` (error).

---

## How to Build and Run

### Prerequisites
* **OS:** Linux (x86-64)
* **Assembler:** `nasm`
* **Compiler / Linker:** `gcc` and `ld` (GNU Binutils)

### Building Project 1 (`arithmetic_sequence.asm`)
Assemble the object file and link it with a C test driver:
```bash
nasm -f elf64 arithmetic_sequence.asm -o arithmetic_sequence.o
gcc -Wall -Wextra -O2 main.c arithmetic_sequence.o -o test_sequence
./test_sequence
```

### Building Project 2 (`string_rewriter.asm`)
Assemble and link directly into a standalone binary:
```bash
nasm -f elf64 string_rewriter.asm -o string_rewriter.o
ld string_rewriter.o -o string_rewriter
./string_rewriter 4 < input.txt
```

---

## Author
**Jakub Skalany**  
Computer Science and Mathematics (JSIM) Student at the University of Warsaw
