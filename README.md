# bwy.kernel

a minimal, freestanding kernel for x86_64.

## features

* cascade (slab-based) memory management
* IDT, ISR, GDT and PIC
* driver management (IOKit-inspired) and universal driver interface
* a VFS
* simulated userland (shell)
* limine-based framebuffer, and baked-in font
* kernel panic

## building

requires a cross-compiler (e.g., this repo uses `clang++`) and `make`.

```bash
make -j(nproc)
```

(NOTE: you have to add `-j(nproc)`)
this will produce `build/bwyOS.iso`.

before building, ensure that you've gotten the limine vendor files,
which you can do by running:

```bash
make deploy-limine-vendor
```

this project has no affiliation with limine. you agree to abide by the limine licensing by running that command.

## running

```bash
make run
```

runs the produced bwyOS.iso in qemu
