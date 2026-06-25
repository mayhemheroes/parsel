/*
 * fuzz_extract_shim.c — tiny ELF launcher for the Atheris (Python) fuzz harness.
 *
 * Mayhem (and the fuzz-smoke gate) require the Mayhemfile `cmd:` target to be a real
 * ELF binary, not a `#!`-script. Atheris harnesses are Python scripts, so this shim is
 * the ELF entry point: it just re-executes the project's venv Python on the harness
 * script, forwarding every libFuzzer CLI arg (`-runs=`, `-max_total_time=`, the input
 * file, …) untouched. Atheris implements the libFuzzer command line, so to Maymem the
 * shim behaves exactly like a native libFuzzer target.
 *
 * Built by mayhem/build.sh with $DEBUG_FLAGS (DWARF < 4) so triage can read it.
 */
#include <unistd.h>
#include <stdlib.h>

#define VENV_PY "/opt/venv/bin/python3"
#define HARNESS "/mayhem/mayhem/fuzz_extract.py"

int main(int argc, char **argv) {
    /* python3 + harness + forwarded argv[1..] + NULL */
    char **nargv = (char **)calloc((size_t)argc + 3, sizeof(char *));
    if (!nargv) return 127;
    int n = 0;
    nargv[n++] = (char *)VENV_PY;
    nargv[n++] = (char *)HARNESS;
    for (int i = 1; i < argc; i++) nargv[n++] = argv[i];
    nargv[n] = (char *)0;
    execv(VENV_PY, nargv);
    return 127; /* exec failed */
}
