# x86-64 Assembly Projects (NASM / Linux)

This repository contains two low-level systems programming projects written in **64-bit x86 Assembly (NASM)** for Linux. The codebase demonstrates multi-precision arithmetic, strict compliance with the **System V AMD64 ABI** calling convention, custom dynamic memory management via raw Linux kernel syscalls, and buffered I/O handling without relying on the C standard library (`libc`).

---

## Repository Structure

    .
    ├── 01-mp-linear-step/
    │   ├── mp_linear_step.asm        # C-callable arbitrary-precision linear step module
    │   └── Makefile
    ├── 02-lsystem-engine/
    │   ├── lsystem_engine.asm        # Standalone L-System iterative rewriting engine
    │   └── Makefile
    └── README.md

---

## Project 1: Multi-Precision Linear Step Evaluator (`mp_linear_step.asm`)

### Overview
A C-callable assembly module that computes the $k$-th step of a linear extrapolation (or an arithmetic sequence) for signed big integers of arbitrary length ($64n$-bit two's complement representation):

$$A_k = A_0 + (A_1 - A_0) \cdot k$$

Because $(A_1 - A_0)$ can require up to $64n + 1$ bits and multiplying by a 64-bit signed integer $k$ expands the result further, the full value of $A_k$ occupies $n + 2$ 64-bit words. The module writes the lower $n$ words directly into the destination buffer `out` and returns the highest 128 bits (words $n+1$ and $n+2$) via the `rdx:rax` register pair.

### Function Signature (System V AMD64 ABI)

    #include <stdint.h>
    #include <stddef.h>

    typedef struct {
        uint64_t lo; // Returned in RAX (word n+1)
        int64_t  hi; // Returned in RDX (word n+2, sign-extended)
    } int128_t;

    int128_t mp_linear_step(
        uint64_t const *base, // rdi: Pointer to the base term (n 64-bit words, little-endian, two's complement)
        uint64_t const *next, // rsi: Pointer to the next term (n 64-bit words, little-endian, two's complement)
        uint64_t *out,        // rdx: Output buffer for the lower 64n bits of the resulting term
        size_t word_count,    // rcx: Number of 64-bit words (n > 0)
        int64_t step          // r8:  Signed 64-bit step index (allows negative indices)
    );

### Key Technical Implementation Details
* **Sign Normalization:** Eliminates signed multiplication complexity by inspecting the sign bit of `step` upfront. If `step < 0`, the routine negates it into an unsigned multiplier and swaps input pointers `base` <-> `next`.
* **Multi-Word Subtraction & Borrow Propagation:** Computes the base difference across $n$ 64-bit words in a tight loop using `sbb` (Subtract with Borrow) and captures signed overflow (`SF != OF`) via `setl` to sign-extend the $(n+1)$-th word.
* **Carry-Propagated Unsigned Multiplication:** Multiplies the multi-word difference by $\vert{}step\vert{}$ word-by-word using 128-bit hardware multiplication (`mul`), propagating 64-bit carries across iterations in `r12` (`add` / `adc`).
* **Sign-Extended Final Addition:** Sign-extends the most significant bit of `base` across two upper 64-bit words and adds `base` to the intermediate product using `adc`, leaving the final upper 128 bits in `rdx:rax`.
* **ABI Compliance:** Properly saves and restores callee-saved registers (`push r12` / `pop r12`).

---

## Project 2: L-System Rewriting Engine (`lsystem_engine.asm`)

### Overview
A standalone 64-bit Linux executable (`_start`, zero `libc` dependencies) that generates discrete ASCII fractals by evaluating a deterministic context-free **Lindenmayer system (L-system)** over $N$ iterations ($0 \le N \le 2^{32}-1$).

### Input Format & Usage

    ./lsystem_engine <iterations> < rules.txt

* **Line 1:** Initial axiom string composed of printable ASCII symbols (codes `33`–`126`), or an empty line.
* **Subsequent Lines:** Parallel production rules `<symbol><replacement_string>\n`. Each symbol (`33`–`126`) may have at most one rule; replacement strings can be empty (erasing the symbol) or arbitrarily long (bounded only by available RAM). Symbols without explicit rules map to themselves.

*(Note: If running manually in the terminal without `< rules.txt`, press `Ctrl+D` to send the EOF signal and start the generation).*

**Example (`rules.txt` for $N = 4$):**

    A
    AAB
    BA

Output after 4 iterations: `ABAABABA`

### Key Technical Implementation Details
* **Custom Dynamic Memory Management (`mmap` / `mremap` / `munmap`):** Operates entirely without `malloc`/`free`. Allocates initial `4096`-byte memory pages via `sys_mmap` (`MAP_PRIVATE | MAP_ANONYMOUS`) and dynamically doubles buffer capacity on demand using `sys_mremap` (`MREMAP_MAYMOVE`) encapsulated in custom NASM macros (`enlarge`, `swap`).
* **$O(1)$ Rule Lookup Dictionary:** Builds a direct-indexed 127-entry offset table in the `.bss` section (`dictionary`). During each rewrite step, resolving a character's replacement string takes constant $O(1)$ time via scaled addressing (`[rsi + 8 * rax]`).
* **Ping-Pong Double Buffering:** Alternates pointers between two dynamically grown buffers (`word_before` in `r12` and `word_after` in `rbp`) at the end of each iteration, avoiding redundant memory copies.
* **Robust I/O & Error Handling:** Implements buffered `sys_read` and loop-guarded `sys_write` to handle partial reads/writes properly. Validates command-line bounds ($< 2^{32}$), checks ASCII ranges (`33`–`126`), rejects malformed lines, and guarantees clean deallocation of all mapped memory regions (`sys_munmap`) before exiting with code `0` (success) or `1` (error).

---

## Author
**Jakub Skalany**  
Computer Science and Mathematics (JSIM) Student at the University of Warsaw
## Author
**Jakub Skalany**  
Computer Science and Mathematics (JSIM) Student at the University of Warsaw
