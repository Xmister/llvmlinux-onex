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

# The assumption is that this will be imported from the vexpress Makfile
# Also that it is imported after the vexpress-linaro.mk

VEXPRESS_LTP_TARGETS	= test3-ltp test3-gcc-ltp test3-all-ltp
TARGETS			+= ${VEXPRESS_LTP_TARGETS}
.PHONY:			${VEXPRESS_LTP_TARGETS}

help-vexpress-ltp:
	@echo ""
	@echo "* make test3-ltp     - linaro/ubuntu rootfs starting LTP, kernel built with clang"
	@echo "* make test3-gcc-ltp - linaro/ubuntu rootfs starting LTP, kernel built with gcc"
	@echo "* make test3-all-ltp - linaro/ubuntu rootfs starting LTP, for all built kernels"

#LTPTESTS = fcntl-locktests filecaps fs ipc mm pipes pty quickhit sched syscalls timers
LTPTESTS = ltplite

VEXPRESS_LTP_IMG	= vexpress-ltp.img
VEXPRESS_LTP_BZ		= ${VEXPRESS_LTP_IMG}.bz2
VEXPRESS_LTP_IMG_TMP	= ${TMPDIR}/${VEXPRESS_LTP_IMG}
VEXPRESS_LTP_BZ_TMP	= ${VEXPRESS_LTP_IMG_TMP}.bz2
LTP_RESULTS_DIR		= test-results

# Old attempt at LTP
#test-ltp: state/prep ${QEMUSTATE}/qemu-build state/kernel-build ${INITRAMFS}
#	@$(call qemu,${BOARD} -cpu cortex-a9,${KERNELDIR},768,/dev/ram0,ramdisk_size=327680 rw rdinit=/bin/sh,-initrd ${INITRAMFS} -net none)

# Build LTP image into linaro vexpress-a9 image (for uploading to prebuilt dir on website)
VEXPRESS_LTP_BZ: ${NANOIMG} ${LTPSTATE}/ltp-build ${LTPSTATE}/ltp-scripts
	@cp -v $< $@
	${TOOLSDIR}/partcopy.sh $@ rootfs ${LTPINSTALLDIR}/ /opt/ltp/ || (rm $@ && echo "E: $@ error" && false)
	bzip2 -9c $< > $@

# Get LTP image from prebuilt images on website
${VEXPRESS_LTP_BZ_TMP}:
	$(call get_prebuilt, $@)

# Uncompress LTP image from prebuilt LTP image
${VEXPRESS_LTP_IMG_TMP}: ${VEXPRESS_LTP_BZ_TMP}
	bunzip2 -9c $< > $@

fresh-vexpress-ltp-img: clean-vexpress-ltp-img ${VEXPRESS_LTP_IMG_TMP}

# Allow the user to keep the existing vexpress LTP image for all runs of LTP
# The default is make a new one for each run of LTP
ifeq "KEEPLTPIMG" "1"
refresh_vexpress_ltp_img = $(MAKE) ${VEXPRESS_LTP_IMG_TMP}
else
refresh_vexpress_ltp_img = $(MAKE) fresh-vexpress-ltp-img
endif

# Command to run the LTP on a built kernel
vexpress_run_ltp	= $(call refresh_vexpress_ltp_img) && $(call qemu,${BOARD},${1},256,/dev/mmcblk0p2,rootfstype=ext4 rw init=/opt/ltp/run-tests.sh ltptest=${2},-sd ${VEXPRESS_LTP_IMG_TMP}) ${NET}

# Run LTP tests on clang built kernel
test3-ltp: state/prep ${QEMUSTATE}/qemu-build state/kernel-build ${VEXPRESS_LTP_BZ_TMP}
	mkdir -p ${LTP_RESULTS_DIR}
	for LTPTEST in ${LTPTESTS} ; do \
		$(call vexpress_run_ltp,${KERNELDIR},$$LTPTEST) \
		| tee $(call ltplog,${LTP_RESULTS_DIR},clang,$$LTPTEST); \
	done

# Run LTP tests on gcc built kernel
test3-gcc-ltp: state/prep ${QEMUSTATE}/qemu-build state/kernel-gcc-build ${VEXPRESS_LTP_BZ_TMP}
	mkdir -p ${LTP_RESULTS_DIR}
	for LTPTEST in ${LTPTESTS} ; do \
		$(call vexpress_run_ltp,${KERNELGCC},$$LTPTEST) \
		| tee $(call ltplog,${LTP_RESULTS_DIR},gcc,$$LTPTEST); \
	done

test3-all-ltp: test3-ltp test3-gcc-ltp

clean-vexpress-ltp-bz:
	rm -f ${VEXPRESS_LTP_BZ}

clean-vexpress-ltp-img:
	rm -f ${VEXPRESS_LTP_IMG_TMP}

clean-vexpress-ltp: clean-vexpress-ltp-bz clean-vexpress-ltp-img

mrproper-vexpress-ltp: clean-vexpress-ltp ltp-mrproper
	rm -f ${VEXPRESS_LTP_BZ_TMP}

