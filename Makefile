cpp_cc = ccache clang++
ld_cc  = ld.lld

cppflags = \
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
	-O1 \
	-mcmodel=kernel \
	-isystem source/vendor \
	-isystem source/kernel \
	-MMD -MP

ldflags = -nostdlib -T source/linker.ld

pch_src = source/kernel/common.hpp
pch = build/common.pch

entry_src = source/kernel/entry.eixx
entry_obj = build/entry.o
kernel_bin = build/kernel.bin

# all .eixx except entry
all_eixx = $(filter-out $(entry_src),$(wildcard source/kernel/**/*.eixx))

.PHONY: all iso clean pch run deploy-limine-vendor

# make sure build exists for run_cmd
build_dir := build
$(shell mkdir -p $(build_dir))

# run_cmd: status logging
define run_cmd
	@mkdir -p build; \
	TMP=build/.cmd.$$RANDOM.out; \
	printf "  $(1)... "; \
	$(2) > $$TMP 2>&1; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
		echo "OK"; \
	else \
		echo "ERR:"; \
		sed 's/^/    /' $$TMP; \
		echo "  exited with code $$status"; \
		rm -f $$TMP; \
		exit $$status; \
	fi; \
	rm -f $$TMP
endef

all: iso

# generate common.hpp from all .eixx except entry
$(pch_src): $(all_eixx)
	@rm -f $(pch_src)
	@echo "// auto-generated common.hpp" > $(pch_src)
	@for f in $(all_eixx); do \
		rel=$$(realpath --relative-to=source/kernel $$f); \
		echo "#include \"$$rel\"" >> $(pch_src); \
	done

# build PCH
$(pch): $(pch_src)
	@mkdir -p build
	$(call run_cmd,compiling precompiled header,$(cpp_cc) $(cppflags) -x c++-header $(pch_src) -o $@)

# compile entry.o with PCH + bear
$(entry_obj): $(entry_src) $(pch)
	@mkdir -p build
	$(call run_cmd,compiling source,bear -- $(cpp_cc) $(cppflags) -x c++ -include-pch $(pch) -c $(entry_src) -o $(entry_obj))

# link kernel
$(kernel_bin): $(entry_obj)
	$(call run_cmd,linking kernel,$(ld_cc) $(ldflags) $^ -o $@)

# iso
iso: $(kernel_bin)
	@mkdir -p build/iso/limine build/iso/bin build/iso/efi/boot
	$(call run_cmd,copying limine.conf,cp source/limine.conf build/iso/limine/limine.conf)
	$(call run_cmd,copying kernel.bin,cp build/kernel.bin build/iso/bin/kernel.bin)
	$(call run_cmd,copying limine bios.sys,cp source/vendor/limine/limine-bios.sys build/iso/limine/)
	$(call run_cmd,copying limine bios cd,cp source/vendor/limine/limine-bios-cd.bin build/iso/limine/)
	$(call run_cmd,copying limine uefi cd,cp source/vendor/limine/limine-uefi-cd.bin build/iso/limine/)
	$(call run_cmd,copying bootx64.efi,cp source/vendor/limine/BOOTX64.EFI build/iso/efi/boot/)
	$(call run_cmd,creating iso,xorriso -as mkisofs \
		-b limine/limine-bios-cd.bin \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		--efi-boot limine/limine-uefi-cd.bin \
		-efi-boot-part --efi-boot-image --protective-msdos-label \
		build/iso -o build/bwyos.iso)
	$(call run_cmd,installing limine bootloader,limine bios-install build/bwyos.iso)

# run qemu
run: iso
	$(call run_cmd,running qemu,qemu-system-x86_64 -cdrom build/bwyos.iso -m 256M -no-reboot -serial stdio -vga std)

# clean build
clean:
	@mkdir -p build
	$(call run_cmd,cleaning build,rm -rf build)

# deploy limine vendor
deploy-limine-vendor:
	@mkdir -p source/vendor
	$(call run_cmd,cloning limine vendor,git clone https://github.com/limine-bootloader/limine.git --branch=v10.x-binary --depth=1 source/vendor/limine)
	$(call run_cmd,downloading limine.h,curl -fsSL https://raw.githubusercontent.com/limine-bootloader/limine-protocol/trunk/include/limine.h -o source/vendor/limine/limine.h)
