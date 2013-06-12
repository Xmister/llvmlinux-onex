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

# Assumes has been included from ../toolchain.mk

LLVMSRCDIR	= ${LLVMTOP}/src
LLVMBUILD	= $(subst ${TOPDIR},${BUILDROOT},${LLVMTOP}/build)
LLVMINSTALLDIR	:= ${LLVMTOP}/install
LLVMSTATE	= ${LLVMTOP}/state
LLVMPATCHES	= ${LLVMTOP}/patches

# Workaround for LLVM breakage
# undefined reference to `.Lline_table_start0'
#LLVM_COMMIT	= "baabdecbb9bf5b32fa81b1e2830ab13076d549f1"
#CLANG_COMMIT	= "953a61f26bf79932b9699b09add4c388764de170"
LLVM_COMMIT	= master
CLANG_COMMIT	= master

DEBDEP		+= cmake flex g++ git-svn subversion zlib1g-dev
RPMDEP		+= cmake flex subversion zlib-devel

# The following export is needed by clang_wrap.sh
export LLVMINSTALLDIR

CLANG		= ${LLVMINSTALLDIR}/bin/clang

LLVMDIR		= ${LLVMSRCDIR}/llvm
CLANGDIR	= ${LLVMSRCDIR}/clang
#COMPILERRTDIR	= ${LLVMDIR}/projects/compiler-rt

LLVMBUILDDIR	= ${LLVMBUILD}/llvm
CLANGBUILDDIR	= ${LLVMBUILD}/clang

LLVMDIR2	= ${LLVMSRCDIR}/llvm-unpatched
CLANGDIR2	= ${LLVMSRCDIR}/clang-unpatched
#COMPILERRTDIR2	= ${LLVMDIR2}/projects/compiler-rt
LLVMBUILDDIR2	= ${LLVMBUILD}/llvm-unpatched
CLANGBUILDDIR2	= ${LLVMBUILD}/clang-unpatched
LLVMINSTALLDIR2	:= ${LLVMTOP}/install-unpatched

LLVM_TARGETS 		= llvm llvm-[fetch,patch,configure,build,clean,sync]
CLANG_TARGETS 		= clang clang-[fetch,patch,configure,build,sync] clang-update-all
#COMPILERRT_TARGETS 	= compilerrt-fetch
LLVM_TARGETS_APPLIED	= llvm-patch-applied clang-patch-applied
LLVM_VERSION_TARGETS	= llvm-version clang-version
#compilerrt-version

TARGETS_TOOLCHAIN	+= ${LLVM_TARGETS} ${CLANG_TARGETS}
#${COMPILERRT_TARGETS}
FETCH_TARGETS		+= llvm-fetch clang-fetch
#compilerrt-fetch
SYNC_TARGETS		+= llvm-sync clang-sync
#compilerrt-sync
CLEAN_TARGETS		+= llvm-clean
MRPROPER_TARGETS	+= llvm-mrproper
RAZE_TARGETS		+= llvm-raze
PATCH_APPLIED_TARGETS	+= ${LLVM_TARGETS_APPLIED}
VERSION_TARGETS		+= ${LLVM_VERSION_TARGETS}
.PHONY:			${LLVM_TARGETS} ${CLANG_TARGETS} ${LLVM_TARGETS_APPLIED} ${LLVM_VERSION_TARGETS}

LLVM_GIT	= "http://llvm.org/git/llvm.git"
CLANG_GIT	= "http://llvm.org/git/clang.git"
#COMPILERRT_GIT	= "http://llvm.org/git/compiler-rt.git"

#LLVM_BRANCH	= "release_30"
LLVM_BRANCH	= "master"
CLANG_BRANCH	= "master"
#COMPILERRT_BRANCH = "master"
# The buildbot takes quite long to build the debug-version of clang (debug+asserts).
# Introducing this option to switch between debug and optimized.
#LLVM_OPTIMIZED	= ""
LLVM_OPTIMIZED	= --enable-optimized --enable-assertions

HELP_TARGETS	+= llvm-help
SETTINGS_TARGETS+= llvm-settings

# Add clang to the path
PATH		:= ${LLVMINSTALLDIR}/bin:${PATH}

# Default bisect good date
LLVM_CLANG_BISECT_START_DATE := 2012-11-01

##############################################################################
llvm-help:
	@echo
	@echo "These are the make targets for building LLVM and Clang:"
	@echo "* make llvm-[fetch,configure,build,sync,clean]"
	@echo "* make clang-[fetch,configure,build,sync,clean]"
	@echo "* make llvm-clang-bisect  LLVM_CLANG_BISECT_START_DATE=2012-11-01"
	@echo "* make llvm-clang-bisect-good  - mark as good"
	@echo "* make llvm-clang-bisect-bad   - mark as bad"
	@echo "* make llvm-clang-bisect-skip  - skip revision"
	@echo "* make llvm-clang-bisect-good[-llvm/-clang]  - mark as good (just llvm/clang)"
	@echo "* make llvm-clang-bisect-bad[-llvm/-clang]   - mark as bad"
	@echo "* make llvm-clang-bisect-skip[-llvm/-clang]  - skip revision"

##############################################################################
llvm-settings:
	@echo "# LLVM settings"
	@$(call prsetting,LLVM_GIT,${LLVM_GIT})
	@$(call prsetting,LLVM_BRANCH,${LLVM_BRANCH})
	@$(call gitcommit,${LLVMDIR},LLVM_COMMIT)
	@$(call prsetting,LLVM_OPTIMIZED,${LLVM_OPTIMIZED})
	@echo "# Clang settings"
	@$(call prsetting,CLANG_GIT,${CLANG_GIT})
	@$(call prsetting,CLANG_BRANCH,${CLANG_BRANCH})
	@$(call gitcommit,${CLANGDIR},CLANG_COMMIT)
#	@$(call prsetting,COMPILERRT_GIT,${COMPILERRT_GIT})
#	@$(call prsetting,COMPILERRT_BRANCH,${COMPILERRT_BRANCH})
#	@$(call gitcommit,${COMPILERRTDIR},COMPILERRT_COMMIT)

##############################################################################
llvmfetch = $(call banner,Fetching ${1}...) ; \
	mkdir -p $(dir ${2}) ; \
	$(call gitclone,${4} -b ${5},${3}) ; \
	if [ -n "${6}" ] ; then \
		$(call banner,Fetching commit-ish ${1}...) ; \
		$(call gitcheckout,${3},${5},${6}) ; \
	fi ;

##############################################################################
llvm-fetch: ${LLVMSTATE}/llvm-fetch
${LLVMSTATE}/llvm-fetch:
	@$(call llvmfetch,LLVM,${LLVMSRCDIR},${LLVMDIR},${LLVM_GIT},${LLVM_BRANCH},${LLVM_COMMIT})
	$(call state,$@,llvm-patch)

##############################################################################
#compilerrt-fetch: ${LLVMSTATE}/compilerrt-fetch
#${LLVMSTATE}/compilerrt-fetch: ${LLVMSTATE}/llvm-fetch
#	@$(call llvmfetch,compiler-rt,${LLVMSRCDIR},${COMPILERRTDIR},${COMPILERRT_GIT},${COMPILERRT_BRANCH},${COMPILERRT_COMMIT})
#	$(call state,$@)

##############################################################################
clang-fetch: ${LLVMSTATE}/clang-fetch
${LLVMSTATE}/clang-fetch:
	@$(call llvmfetch,Clang,${LLVMSRCDIR},${CLANGDIR},${CLANG_GIT},${CLANG_BRANCH},${CLANG_COMMIT})
	$(call state,$@,clang-patch)

##############################################################################
llvm-unpatched-fetch: ${LLVMSTATE}/llvm-unpatched-fetch
${LLVMSTATE}/llvm-unpatched-fetch: ${LLVMSTATE}/llvm-fetch
	@$(call llvmfetch,LLVM-unpatched,${LLVMSRCDIR},${LLVMDIR2},${LLVMDIR}/.git,${LLVM_BRANCH},${LLVM_COMMIT})
	$(call state,$@,llvm-unpatched-configure)

##############################################################################
#compilerrt-unpatched-fetch: ${LLVMSTATE}/compilerrt-unpatched-fetch
#${LLVMSTATE}/compilerrt-unpatched-fetch: ${LLVMSTATE}/llvm-unpatched-fetch
#	@$(call llvmfetch,compiler-rt-unpatched,${LLVMSRCDIR},${COMPILERRTDIR2},${COMPILERRTDIR}/.git,${COMPILERRT_BRANCH},${COMPILERRT_COMMIT})
#	$(call state,$@)

##############################################################################
clang-unpatched-fetch: ${LLVMSTATE}/clang-unpatched-fetch
${LLVMSTATE}/clang-unpatched-fetch: ${LLVMSTATE}/clang-fetch
	@$(call llvmfetch,Clang-unpatched,${LLVMSRCDIR},${CLANGDIR2},${CLANGDIR}/.git,${CLANG_BRANCH},${CLANG_COMMIT})
	$(call state,$@,clang-unpatched-configure)

##############################################################################
llvmpatch = $(call banner,Patching ${1}...) ; \
	$(call patches_dir,${2},${3}/patches) ; \
	$(call patch,${3})

##############################################################################
llvm-patch: ${LLVMSTATE}/llvm-patch
${LLVMSTATE}/llvm-patch: ${LLVMSTATE}/llvm-fetch
	@$(call llvmpatch,LLVM,${LLVMPATCHES}/llvm,${LLVMDIR})
	$(call state,$@,llvm-configure)

##############################################################################
clang-patch: ${LLVMSTATE}/clang-patch
${LLVMSTATE}/clang-patch: ${LLVMSTATE}/clang-fetch
	@$(call llvmpatch,Clang,${LLVMPATCHES}/clang,${CLANGDIR})
	$(call state,$@,clang-configure)

##############################################################################
#compilerrt-patch: ${LLVMSTATE}/compilerrt-patch
#${LLVMSTATE}/compilerrt-patch: ${LLVMSTATE}/compilerrt-fetch
#	@$(call llvmpatch,Compiler-rt,${LLVMPATCHES}/compiler-rt,${COMPILERRTDIR})
#	$(call state,$@)

##############################################################################
${LLVM_TARGETS_APPLIED}: %-patch-applied:
	@$(call banner,Patches applied for $*)
	@$(call applied,${LLVMSRCDIR}/$*)

##############################################################################
llvmconfig = $(call banner,Configure ${1}...) ; \
	mkdir -p ${2} ${3} && \
	(cd ${2} && cmake -DCMAKE_BUILD_TYPE=Release -DLLVM_BINUTILS_INCDIR=/usr/include/ \
	-DLLVM_TARGETS_TO_BUILD="AArch64;ARM;X86" -DCMAKE_INSTALL_PREFIX=${3} ${4} ${5})

##############################################################################
llvm-configure: ${LLVMSTATE}/llvm-configure
${LLVMSTATE}/llvm-configure: ${LLVMSTATE}/llvm-patch
	@make -s build-dep-check
	@$(call llvmconfig,LLVM,${LLVMBUILDDIR},${LLVMINSTALLDIR},,${LLVMDIR})
	$(call state,$@,llvm-build)

##############################################################################
clang-configure: ${LLVMSTATE}/clang-configure
${LLVMSTATE}/clang-configure: ${LLVMSTATE}/clang-patch
	@$(call llvmconfig,Clang,${CLANGBUILDDIR},${LLVMINSTALLDIR},-DCLANG_PATH_TO_LLVM_SOURCE=${LLVMDIR} -DCLANG_PATH_TO_LLVM_BUILD=${LLVMBUILDDIR},${CLANGDIR})
	$(call state,$@,clang-build)

##############################################################################
llvm-unpatched-configure: ${LLVMSTATE}/llvm-unpatched-configure
${LLVMSTATE}/llvm-unpatched-configure: ${LLVMSTATE}/llvm-unpatched-fetch
	@$(call llvmconfig,LLVM-unpatched,${LLVMBUILDDIR2},${LLVMINSTALLDIR2},-DCMAKE_EXECUTABLE_SUFFIX=-unpatched,${LLVMDIR2})
	$(call state,$@,llvm-unpatched-build)

##############################################################################
clang-unpatched-configure: ${LLVMSTATE}/clang-unpatched-configure
${LLVMSTATE}/clang-unpatched-configure: ${LLVMSTATE}/clang-unpatched-fetch
	@$(call llvmconfig,Clang-unpatched,${CLANGBUILDDIR2},${LLVMINSTALLDIR2},-DCLANG_PATH_TO_LLVM_SOURCE=${LLVMDIR2} -DCLANG_PATH_TO_LLVM_BUILD=${LLVMBUILDDIR2} -DCMAKE_EXECUTABLE_SUFFIX=-unpatched,${CLANGDIR2})
	$(call state,$@,clang-unpatched-build)

##############################################################################
llvmbuild = $(call banner,Building ${1}...) ; \
	make -C ${2} -j${JOBS} install

##############################################################################
llvm llvm-build: ${LLVMSTATE}/llvm-build
${LLVMSTATE}/llvm-build: ${LLVMSTATE}/llvm-configure
	@[ -d ${LLVMBUILDDIR} ] || ${MAKE} llvm-clean $^ # build in tmpfs
	@$(call llvmbuild,LLVM,${LLVMBUILDDIR})
	$(call state,$@,clang-build)

##############################################################################
clang clang-build: ${LLVMSTATE}/clang-build
${LLVMSTATE}/clang-build: ${LLVMSTATE}/llvm-build ${LLVMSTATE}/clang-configure
	@[ -d ${LLVMBUILDDIR} ] || ${MAKE} llvm-clean llvm-build $^ # build in tmpfs
	@$(call llvmbuild,Clang,${CLANGBUILDDIR})
	cp -a ${CLANGDIR}/tools/scan-build/* ${LLVMINSTALLDIR}/bin
	cp -a ${CLANGDIR}/tools/scan-view/* ${LLVMINSTALLDIR}/bin
	$(call state,$@)

##############################################################################
llvm-unpatched-build: ${LLVMSTATE}/llvm-unpatched-build
${LLVMSTATE}/llvm-unpatched-build: ${LLVMSTATE}/llvm-unpatched-configure
	@[ -d ${LLVMBUILDDIR2} ] || (rm -f ${LLVMSTATE}/llvm-unpatched-configure; ${MAKE} $^) # build in tmpfs
	@$(call llvmbuild,LLVM-unpatched,${LLVMBUILDDIR2})
	$(call state,$@,clang-build)

##############################################################################
clang-unpatched-build: ${LLVMSTATE}/clang-unpatched-build
${LLVMSTATE}/clang-unpatched-build: ${LLVMSTATE}/llvm-unpatched-build ${LLVMSTATE}/clang-unpatched-configure
	@[ -d ${LLVMBUILDDIR2} ] || (rm -f ${LLVMSTATE}/*-unpatched-configure; ${MAKE} $^) # build in tmpfs
	@$(call llvmbuild,Clang-unpatched,${CLANGBUILDDIR2})
	$(call state,$@)

##############################################################################
llvm-reset: ${LLVMSTATE}/clang-fetch
#${LLVMSTATE}/compilerrt-fetch
# Patched LLVM
	@$(call banner,Cleaning LLVM...)
	@$(call makeclean,${LLVMBUILDDIR})
	@$(call banner,Removing LLVM patches...)
	@$(call unpatch,${LLVMDIR})
#	@$(call optional_gitreset,${COMPILERRTDIR})
	@$(call optional_gitreset,${LLVMDIR})
# Unpatched LLVM
	@$(call banner,Cleaning unpatched LLVM...)
	@$(call makeclean,${LLVMBUILDDIR2})
#	@$(call optional_gitreset,${COMPILERRTDIR2})
	@$(call optional_gitreset,${LLVMDIR2})
	@$(call leavestate,${LLVMSTATE},llvm-patch llvm-configure llvm-build llvm-unpatched-configure llvm-unpatched-build)

##############################################################################
llvm-clean-noreset:
	@$(call banner,Removing LLVM Build and Install dirs...)
	@rm -rf ${LLVMBUILDDIR} ${LLVMINSTALLDIR} ${LLVMINSTALLDIR2}
	@$(call leavestate,${LLVMSTATE},llvm-configure llvm-build llvm-unpatched-configure llvm-unpatched-build)

##############################################################################
llvm-clean: llvm-reset llvm-clean-noreset clang-clean

##############################################################################
llvm-mrproper: llvm-clean clang-mrproper

##############################################################################
llvm-raze: llvm-clean-noreset clang-raze
	@$(call banner,Razing LLVM...)
	@rm -rf ${LLVMDIR}
	@$(call leavestate,${LLVMSTATE},llvm-*)

##############################################################################
clang-reset: ${LLVMSTATE}/clang-fetch
# Patched Clang
	@$(call banner,Cleaning Clang...)
	@$(call makeclean,${CLANGBUILDDIR})
	@$(call banner,Removing Clang patches...)
	@$(call unpatch,${CLANGDIR})
	@$(call optional_gitreset,${CLANGDIR})
# Unpatched Clang
	@$(call banner,Cleaning unpatched Clang...)
	@$(call makeclean,${CLANGBUILDDIR2})
	@$(call optional_gitreset,${CLANGDIR2})
	@$(call leavestate,${LLVMSTATE},clang-patch clang-configure clang-build clang-unpatched-configure clang-unpatched-build)

##############################################################################
clang-clean-noreset: llvm-clean-noreset
	@$(call banner,Removing Clang Build and Install dirs...)
	@rm -rf ${LLVMINSTALLDIR}/clang ${CLANGBUILDDIR} ${CLANGBUILDDIR2}

##############################################################################
clang-clean: clang-reset clang-clean-noreset

##############################################################################
clang-mrproper: clang-clean
	(cd ${CLANGDIR} && git clean -f)

##############################################################################
clang-raze: clang-clean-noreset
	@$(call banner,Razing Clang...)
	@rm -rf ${CLANGDIR}
	@$(call leavestate,${LLVMSTATE},clang-*)

##############################################################################
llvmsync = $(call banner,Updating ${1}...) ; \
	$(call unpatch,${2}) ; \
	[ ! -d ${2} ] || if [ -n "${4}" ] ; then \
		$(call banner,Syncing commit-ish ${1}...) ; \
		$(call gitcheckout,${2},${3},${4}) ; \
	else \
		$(call gitpull,${2},${3}) ; \
	fi

##############################################################################
llvm-sync: llvm-clean
	@$(call check_llvmlinux_commit,${CONFIG})
	@$(call llvmsync,LLVM,${LLVMDIR},${LLVM_BRANCH},${LLVM_COMMIT})
	@$(call llvmsync,unpatched LLVM,${LLVMDIR2},${LLVM_BRANCH},${LLVM_COMMIT})

##############################################################################
clang-sync: clang-clean
	@$(call check_llvmlinux_commit,${CONFIG})
	@$(call llvmsync,Clang,${CLANGDIR},${CLANG_BRANCH},${CLANG_COMMIT})
	@$(call llvmsync,Unpatched Clang,${CLANGDIR2},${CLANG_BRANCH},${CLANG_COMMIT})

##############################################################################
#compilerrt-sync: llvm-clean
#	@$(call check_llvmlinux_commit,${CONFIG})
#	@$(call llvmsync,compiler-rt,${COMPILERRTDIR},${COMPILERRT_BRANCH},${COMPILERRT_COMMIT})
#	@$(call llvmsync,Unpatched compiler-rt,${COMPILERRTDIR2},${COMPILERRT_BRANCH},${COMPILERRT_COMMIT})

##############################################################################
llvm-version:
	@(cd ${LLVMDIR} && [ -f "${LLVMINSTALLDIR}/bin/llc" ] \
		&& echo "`${LLVMINSTALLDIR}/bin/llc --version | grep version | xargs echo` commit `git rev-parse HEAD`" \
		|| echo "LLVM version ? commit `git rev-parse HEAD`")

##############################################################################
clang-version:
	@(cd ${CLANGDIR} && [ -f "${CLANG}" ] \
		&& echo "`${CLANG} --version | grep version | xargs echo` commit `git rev-parse HEAD`" \
		|| echo "clang version ? commit `git rev-parse HEAD`")

##############################################################################
#compilerrt-version:
#	@(cd ${COMPILERRTDIR} && echo "compiler-rt version ? commit `git rev-parse HEAD`")

##############################################################################
clang-update-all: llvm-sync clang-sync llvm-build clang-build
#compilerrt-sync

llvm-clang-bisect: llvm-mrproper clang-mrproper
	@(cd ${LLVMDIR} ; git bisect reset ; git bisect start ; git bisect bad ; git bisect good `git log --pretty=format:'%ai §%H' | grep ${LLVM_CLANG_BISECT_START_DATE} | head -1 | cut -d"§" -f2` )
	@(cd ${CLANGDIR} ; git bisect reset ; git bisect start ; git bisect bad ; git bisect good `git log --pretty=format:'%ai §%H' | grep ${LLVM_CLANG_BISECT_START_DATE} | head -1 | cut -d"§" -f2` )

llvm-clang-bisect-good: llvm-clean clang-clean kernel-clean
	@(cd ${LLVMDIR} ; git bisect good )
	@(cd ${CLANGDIR} ; git bisect good )

llvm-clang-bisect-good-llvm: llvm-clean clang-clean kernel-clean
	@(cd ${LLVMDIR} ; git bisect good )

llvm-clang-bisect-good-clang: clang-clean kernel-clean
	@(cd ${CLANGDIR} ; git bisect good )

llvm-clang-bisect-bad: llvm-clean clang-clean kernel-clean
	@(cd ${LLVMDIR} ; git bisect bad)
	@(cd ${CLANGDIR} ; git bisect bad)

llvm-clang-bisect-bad-llvm: llvm-clean clang-clean kernel-clean
	@(cd ${LLVMDIR} ; git bisect bad)

llvm-clang-bisect-bad-clang: clang-clean kernel-clean
	@(cd ${CLANGDIR} ; git bisect bad)

llvm-clang-bisect-skip: llvm-clean clang-clean kernel-clean
	@(cd ${LLVMDIR} ; git bisect skip)
	@(cd ${CLANGDIR} ; git bisect skip)

llvm-clang-bisect-skip-llvm: llvm-clean clang-clean kernel-clean
	@(cd ${LLVMDIR} ; git bisect skip)

llvm-clang-bisect-skip-clang: clang-clean kernel-clean
	@(cd ${CLANGDIR} ; git bisect skip)

llvm-clang-bisect-reset: llvm-mrproper clang-mrproper
	@(cd ${LLVMDIR} ; git bisect reset)
	@(cd ${CLANGDIR} ; git bisect reset)
