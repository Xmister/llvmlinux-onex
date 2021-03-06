##############################################################################
# Copyright (c) 2012 Mark Charlebois
#               2012 Jan-Simon Möller
#               2012 Behan Webster
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to 
# deal in the Software without restriction, including without limitation the 
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
# sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
##############################################################################

TARGETDIR	= ${CURDIR}
TOPDIR		= $(realpath ${TARGETDIR}/../..)

KERNEL_CFG	= ${TARGETDIR}/config_x86_64
# override KERNEL_TAG to v3.3
#KERNEL_TAG = v3.3
# around 3.10-rc7
#KERNEL_COMMIT = "4300a0f8bdcce5a03b88bfa16fc9827e15c52dc4"
#LLVM_COMMIT = release_34
#CLANG_COMMIT = release_34

#GDB_OPTS	= -gdb tcp::1234 -s -S
GDB_OPTS	=

all: prep kernel-build

include ${TOPDIR}/common.mk
include ${ARCHDIR}/x86_64/x86_64.mk
include ${CONFIG}

TARGETS+= clean mrproper test test2
.PHONY: test test2 fetch-initrd prep clean mrproper test

prep: state/prep
state/prep:
	$(MAKE) ${TMPDIR}
	@mkdir -p ${LOGDIR}
	$(call state,$@)

clean: kernel-clean kernel-gcc-clean
	@$(call banner,Clean)

mrproper: clean kernel-mrproper kernel-gcc-mrproper tmp-mrproper
	@rm -rf ${LOGDIR}/*
	@$(call banner,Very Clean)

${INITRAMFS}.clang: initramfs-unpacked
	@rm -rf ${INITBUILDFSDIR}/lib/modules
#	(cd ${KERNEL_BUILD} && make V=0 INSTALL_MOD_PATH=${INITBUILDFSDIR} modules_install 2>&1 > /dev/null)
	mkdir -p ${INITBUILDFSDIR}/usr/lib
	@rm -f ${INITRAMFS}
	@make ${INITRAMFS}
	mv ${INITRAMFS} ${INITRAMFS}.clang

# Create the generic initramfs, add in the kernel modules, then create the cpio
test: state/prep ${QEMUSTATE}/qemu-build ${INITRAMFS}.clang
	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,512,/dev/ram0,rw console=ttyS0 earlyprintk ,-initrd ${INITRAMFS}.clang -net none )
#	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,2048,/dev/ram0,ramdisk_size=512000 rdinit=/init console=ttyS0 earlyprintk,-initrd ${INITRAMFS}.clang -curses)

test-qemu: ${INITRAMFS}.clang ${QEMUSTATE}/qemu-build
	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,512,/dev/ram0,rw console=ttyS0 earlyprintk ,-initrd ${INITRAMFS}.clang -net none )
#	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,2048,/dev/ram0,ramdisk_size=512000 rdinit=/init console=ttyS0 earlyprintk,-M q35 -cpu SandyBridge -initrd ${INITRAMFS}.clang -curses)

test-qemu-debug: ${INITRAMFS}.clang
	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,512,/dev/ram0,rw console=ttyS0 earlyprintk ,-initrd ${INITRAMFS}.clang -net none -D qemulog.log -d in_asm,op,int,exec,cpu,cpu_reset,)
#	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,2048,/dev/ram0,ramdisk_size=512000 rdinit=/init console=ttyS0 earlyprintk,-M q35 -cpu SandyBridge -initrd ${INITRAMFS}.clang -curses)

test-qemu-smp:
	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,2048,/dev/ram0,ramdisk_size=512000 rdinit=/init console=ttyS0 earlyprintk,-M q35 -cpu SandyBridge -smp 4 -initrd ${INITRAMFS}.clang)

test-gcc:  state/prep ${QEMUSTATE}/qemu-build initramfs-unpacked
	@rm -rf ${INITBUILDFSDIR}/lib/modules
	(cd ${KERNEL_BUILD} && make V=0 INSTALL_MOD_PATH=${INITBUILDFSDIR} modules_install 2>&1 > /dev/null)
	mkdir -p ${INITBUILDFSDIR}/usr/lib
	@rm -f ${INITRAMFS}
	@make ${INITRAMFS}
	mv ${INITRAMFS} ${INITRAMFS}.gcc
	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,2048,/dev/ram0,ramdisk_size=512000 rdinit=/init console=ttyS0 earlyprintk,-initrd ${INITRAMFS}.gcc)

test-gcc-qemu:
	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,2048,/dev/ram0,ramdisk_size=512000 rdinit=/init console=ttyS0 earlyprintk,-initrd ${INITRAMFS}.gcc)
