CPP_CC = clang++
LD_CC  = ld.lld

CPPFLAGS = \
    -std=c++20 \
    -target x86_64-pc-none-elf \
    -ffreestanding \
    -fno-exceptions \
    -fno-rtti \
    -fno-threadsafe-statics \
    -mno-red-zone \
    -mno-sse \
    -mno-sse2 \
    -mgeneral-regs-only \
    -Wall -Wextra \
    -O3 \
    -mcmodel=kernel \
    -Isource/kernel \
    -Isource/vendor

LDFLAGS = -nostdlib -T source/linker.ld

.PHONY: all iso clean run

all: iso

HEADERS = \
    source/kernel/gfx/font.eixx \
    source/kernel/gfx/fb.eixx \
    source/kernel/gfx/kprint.eixx \
    source/kernel/cpu/gdt.eixx \
    source/kernel/cpu/idt.eixx \
    source/kernel/cpu/isr.eixx \
    source/kernel/cpu/pic.eixx \
    source/kernel/mm/pmm.eixx \
    source/kernel/mm/cascade.eixx \
    source/kernel/sys/panic.eixx \
    source/kernel/drv/io.eixx \
    source/kernel/drv/driver.eixx \
    source/kernel/drv/input/keyboard.eixx \
    source/kernel/fs/vfs.eixx \
    source/kernel/sys/shell.eixx

build/entry.o: source/kernel/entry.eixx $(HEADERS)
	mkdir -p build
	$(CPP_CC) $(CPPFLAGS) -x c++ -c source/kernel/entry.eixx -o build/entry.o

build/kernel.bin: build/entry.o
	$(LD_CC) $(LDFLAGS) build/entry.o -o build/kernel.bin

iso: build/kernel.bin
	mkdir -p build/iso/limine build/iso/bin build/iso/efi/boot
	cp source/limine.conf                        build/iso/limine/limine.conf
	cp build/kernel.bin                          build/iso/bin/kernel.bin
	cp source/vendor/limine/limine-bios.sys      build/iso/limine/
	cp source/vendor/limine/limine-bios-cd.bin   build/iso/limine/
	cp source/vendor/limine/limine-uefi-cd.bin   build/iso/limine/
	cp source/vendor/limine/BOOTX64.EFI          build/iso/efi/boot/
	xorriso -as mkisofs \
		-b limine/limine-bios-cd.bin \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		--efi-boot limine/limine-uefi-cd.bin \
		-efi-boot-part --efi-boot-image --protective-msdos-label \
		build/iso -o build/bwyOS.iso 2>/dev/null
	limine bios-install build/bwyOS.iso

run: iso
	qemu-system-x86_64 -cdrom build/bwyOS.iso -m 256M -no-reboot -serial stdio -vga std

clean:
	rm -rf build

deploy-limine-vendor:
	git clone https://github.com/limine-bootloader/limine.git --branch=v10.x-binary --depth=1 source/vendor/limine
	curl -fsSL https://raw.githubusercontent.com/limine-bootloader/limine-protocol/trunk/include/limine.h -o source/vendor/limine/limine.h
