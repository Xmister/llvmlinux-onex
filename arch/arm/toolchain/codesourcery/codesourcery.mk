##############################################################################
# Copyright {c} 2012 Mark Charlebois
#               2012 Behan Webster
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files {the "Software"}, to 
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

# Note: use CROSS_ARM_TOOLCHAIN=codesourcery to include this file

CSCC_URL	= https://sourcery.mentor.com/GNUToolchain/package8739/public/arm-none-linux-gnueabi/arm-2011.03-41-arm-none-linux-gnueabi-i686-pc-linux-gnu.tar.bz2
CSCC_NAME	= arm-2011.03
CSCC_TAR	= ${notdir ${CSCC_URL}}
CSCC_TOPDIR	= ${ARCH_ARM_TOOLCHAIN}/codesourcery
CSCC_TMPDIR	= ${CSCC_TOPDIR}/tmp

HOST		= arm-none-linux-gnueabi
CSCC_DIR	= ${CSCC_TOPDIR}/${CSCC_NAME}
CSCC_BINDIR	= ${CSCC_DIR}/bin
HOST_TRIPLE	= arm-none-gnueabi
COMPILER_PATH	= ${CSCC_DIR}
CC_FOR_BUILD	= ${CSCC_BINDIR}/${HOST}-gcc
export HOST HOST_TRIPLE

# Add path so that ${CROSS_COMPILE}${CC} is resolved
PATH		:= ${CSCC_BINDIR}:${ARCH_ARM_BINDIR}:${PATH}

# Get ARM cross compiler
${CSCC_TMPDIR}/${CSCC_TAR}:
	@mkdir -p ${CSCC_TMPDIR}
	wget -c -P ${CSCC_TMPDIR} "${CSCC_URL}"

CROSS_GCC=${CSCC_BINDIR}/${CROSS_COMPILE}gcc
codesourcery-gcc arm-cc: ${ARCH_ARM_TOOLCHAIN_STATE}/codesourcery-gcc
${ARCH_ARM_TOOLCHAIN_STATE}/codesourcery-gcc: ${CSCC_TMPDIR}/${CSCC_TAR}
	tar -x -j -C ${CSCC_TOPDIR} -f $<
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/arm-none-linux-gnueabi-ar ${CSCC_DIR}/bin/arm-eabi-ar)
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/arm-none-linux-gnueabi-as ${CSCC_DIR}/bin/arm-eabi-as)
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/arm-none-linux-gnueabi-strip ${CSCC_DIR}/bin/arm-eabi-strip)
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/arm-none-linux-gnueabi-ranlib ${CSCC_DIR}/bin/arm-eabi-ranlib)
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/arm-none-linux-gnueabi-ld ${CSCC_DIR}/bin/arm-eabi-ld)
	$(call state,$@)

state/arm-cc: ${ARCH_ARM_TOOLCHAIN_STATE}/codesourcery-gcc
	$(call state,$@)
	
codesourcery-gcc-clean arm-cc-clean:
	@$(call banner,Removing Codesourcery compiler...)
	@rm -f state/arm-cc ${ARCH_ARM_TOOLCHAIN_STATE}/codesourcery-gcc
	@rm -rf ${CSCC_DIR} ${CSCC_TMPDIR}

arm-cc-version: ${ARCH_ARM_TOOLCHAIN_STATE}/codesourcery-gcc
	@${CROSS_GCC} --version | head -1

${ARCH_ARM_TMPDIR}:
	@mkdir -p $@
