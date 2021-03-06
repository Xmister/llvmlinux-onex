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

TOOLCHAIN	= ${TOPDIR}/toolchain
TOOLSDIR	= ${TOPDIR}/tools
ARCHDIR		= ${TOPDIR}/arch
TESTDIR		= ${TOPDIR}/test

COMMON_TARGETS	= list-config list-jobs list-targets list-fetch-all list-patch-applied list-path list-versions \
			clean-all fetch-all mrproper-all raze-all sync-all tmp-mrproper
TARGETS_UTILS	+= ${COMMON_TARGETS}
CMDLINE_VARS	+= 'CONFIG=<file>' JOBS=n GIT_HARD_RESET=1

HELP_TARGETS	+= common-help
.PHONY:		${COMMON_TARGETS}

##############################################################################
seperator = ---------------------------------------------------------------------
#banner	= ($(info ${seperator}) $(info ${1}) $(info ${seperator}))
banner	= (echo ${seperator}; echo ${1}; echo ${seperator})
echo	= (echo ${seperator}; echo ${1}; echo ${seperator})
state	= @mkdir -p $(dir ${1}) && touch ${1} \
	  && $(call echo,Finished state $(notdir ${1})) \
	  && ( [ -d $(dir ${1})${2} ] || rm -f $(dir ${1})${2} )
leavestate = rm -f $(wildcard $(addprefix ${1}/,${2}))
error1	= ( echo Error: ${1}; false )
assert	= [ ${1} ] || $(call error1,${2})
assert_found_in_path = which ${1} || (echo "${1}: Not found in PATH" ${2}; false)

##############################################################################
# recursive Make macros
makeclean = if [ -f ${1}/Makefile ]; then ${3} make --quiet -C ${1} ${2} clean ; fi
makemrproper = if [ -f ${1}/Makefile ]; then ${3} make --quiet -C ${1} ${2} mrproper ; fi

##############################################################################
# Quilt patch macros used by all subsystems
patches_dir = [ "`stat -c "%N" ${2}`" = "'${2}' -> '${1}'" ] || (rm -f ${2}; ln -sf ${1} ${2})
applied	= ( [ -d ${1} ] && cd ${1} && quilt applied || true )
patch	= mkdir -p ${TMPDIR}; [ ! -d ${1} ] || (cd ${1} && if [ -e patches ] && $(call echo,Applying patches to ${1}) && quilt unapplied ; then quilt push -a ; else >/dev/null ; fi)
unpatch	= mkdir -p ${TMPDIR}; [ ! -d ${1} ] || (cd ${1} && if [ -e patches ] && $(call echo,Unapplying patches from ${1}) && quilt applied ; then quilt pop -af ; else >/dev/null ; fi)
apply_patch = (cd ${1} && cat ${2} | patch -s -p1)

##############################################################################
# Check LLVMLinux commit macros used by all subsystems
check_llvmlinux_commit = [ -z "${FORCE_LLVMLINUX_COMMIT}" ] \
	|| ( $(call echo,Forcing LLVMLinux commit specified at ${1}) \
	&& [ "${LLVMLINUX_COMMIT}" = "`(cd ${TOPDIR} && git rev-parse HEAD)`" ] \
	|| $(call check_llvmlinux_commit_error_msg,${1}))
check_llvmlinux_commit_error_msg = (echo "Current HEAD does not match with checkpoint ${1}. Please run:" \
	&& echo "    git checkout ${LLVMLINUX_COMMIT}" && false)

##############################################################################
# Git macros used by all subsystems
gitclone = [ -d ${2}/.git ] || (rm -rf ${2} && git clone ${1} ${2} ${3})
gitcheckout = (cd ${1} && git checkout ${2} && ([ -z "${3}" ] || git pull && git checkout ${3}))
gitcommit = [ ! -d ${1}/.git ] || (cd ${1} && $(call prsetting,${2},`git rev-parse HEAD`))
gitmove = (cd ${1} && git branch --move ${2} $3 >/dev/null 2>&1)
gitpull = (cd ${1} && git checkout ${2} && git pull origin ${2})
gitreset = ([ -d ${1} ] && cd ${1} && $(call echo,Reseting git tree ${1}) && git reset --hard HEAD && git clean -d -f) || true
ifneq "${GIT_HARD_RESET}" ""
optional_gitreset = $(call gitreset,${1})
else
optional_gitreset =
endif

gitsync = if [ -n "${2}" ] ; then \
		$(call gitcheckout,${1},${3},${2}) ; \
	elif [ -n "${4}" ] ; then \
		$(call gitmove,${1},${4},tag-${4}) ; \
		$(call gitpull,${1},${4}) ; \
	else \
		$(call gitpull,${1},${3}) ; \
	fi

##############################################################################
# Subversion macros used by all subsystems
svncheckout = [ -d ${2}/.svn ] || svn --quiet checkout ${1} -r ${3} ${2}
svnupdate = (cd ${1} && svn update)

##############################################################################
# general download macros
wget = mkdir -p ${2} && wget -P ${2} -c ${1}
untgz = $(call echo,Unpacking $(notdir ${1}) into ${2}) \
		&& mkdir -p ${2} && tar --extract --gunzip --file ${1} --directory ${2}
unbz2 = $(call echo,Unpacking $(notdir ${1}) into ${2}) \
		&& mkdir -p ${2} && tar --extract --bzip2 --file ${1} --directory ${2}
unxz = $(call echo,Unpacking $(notdir ${1}) into ${2}) \
		&& mkdir -p ${2} && tar --extract --xz --file ${1} --directory ${2}

##############################################################################
# Settings macros used by all subsystems
prsetting = (printf "%-24s= %s\n" "${1}" "${2}" | unexpand --all)
praddsetting = (printf "%-23s+= %s\n" "${1}" "${2}" | unexpand --all)
configfilter = sed -e 's|${CHECKPOINT_DIR}|$${CHECKPOINT_DIR}|g; s|${TARGETDIR}|$${TARGETDIR}|g'

##############################################################################
# Default jobs is number of processors + 1 for disk I/O
ifeq "${JOBS}" ""
  JOBS:=${shell expr `getconf _NPROCESSORS_ONLN` + 1}
  ifeq "${JOBS}" ""
  JOBS:=2
  endif
endif

##############################################################################
common-help:
	@echo
	@echo "These are the generic make targets for all build targets:"
	@echo "* make clean-all	- clean all code"
	@echo "* make fetch-all	- fetch all repos and external files"
	@echo "* make mproper-all	- scrub all code (cleaner than clean)"
	@echo "* make raze-all		- Remove most things not in the llvmlinux repo"
	@echo "* make sync-all		- sync all repos"
	@echo
	@echo "* make list-config	- List make variables you can specify in the CONFIG files"
	@echo "* make list-jobs	- List number of parallel build jobs"
	@echo "* make list-targets	- List all build targets"
	@echo "* make list-fetch-all	- List all things to be downloaded"
	@echo "* make list-patch-applied - List all applied patches"
	@echo "* make list-path	- List the search path used by the Makefiles"
	@echo "* make list-versions	- List the version of all relevant software"
	@echo
	@echo "* make CONFIG=<file> ...    - Choose configuration file(s) to use"
	@echo "* make GIT_HARD_RESET=1 ... - Run a hard git reset after quilt unpatch"
	@echo "* make JOBS=n ...           - Choose how many jobs to run under make (default ${JOBS})"

##############################################################################
SETTINGS_TARGETS += common-settings
common-settings:
	@$(call gitcommit,${TOPDIR},LLVMLINUX_COMMIT)

##############################################################################
list-jobs:
	@echo "-j${JOBS}"

# The order of these includes is important
include ${TOPDIR}/arch/all/checkpoint.mk
include ${TOPDIR}/arch/all/dependency.mk
include ${TOPDIR}/arch/all/tmpfs-build.mk
include ${TOOLCHAIN}/toolchain.mk

##############################################################################
help:
	@${MAKE} --silent ${HELP_TARGETS} | less

##############################################################################
list-targets:
ifneq "${TARGETS}" ""
	@echo "List of unclassified make targets:"
	@for t in ${TARGETS}; do echo "\t"$$t; done | sort -u
	@echo
endif
	@echo "List of available make targets for test tools:"
	@for t in ${TARGETS_TEST}; do echo "\t"$$t; done | sort -u
	@echo
	@echo "List of available make targets for toolchain:"
	@for t in ${TARGETS_TOOLCHAIN}; do echo "\t"$$t; done | sort -u
	@echo
	@echo "List of available make targets for platform:"
	@for t in ${TARGETS_BUILD}; do echo "\t"$$t; done | sort -u
	@echo
	@echo "List of available utility make targets:"
	@for t in ${TARGETS_UTILS}; do echo "\t"$$t; done | sort -u
	@echo
	@echo "List of available command-line make variables:"
	@for t in ${CMDLINE_VARS}; do echo "\t"$$t; done | sort -u

##############################################################################
list-fetch-all:
	@for t in ${FETCH_TARGETS}; do echo $$t | sed -e "s|^`pwd`/||"; done

##############################################################################
list-patch-applied:
	${MAKE} ${PATCH_APPLIED_TARGETS}

##############################################################################
list-path:
	@echo ${PATH}

##############################################################################
list-settings settings list-config config:
	@${MAKE} --silent ${SETTINGS_TARGETS} 2>/dev/null | sed \
		-e 's|${TARGETDIR}|$${TARGETDIR}|g' \
		-e 's|${ARCHDIR}|$${ARCHDIR}|g' \
		-e 's|${TESTDIR}|$${TESTDIR}|g' \
		-e 's|${TOOLCHAIN}|$${TOOLCHAIN}|g' \
		-e 's|${TOOLSDIR}|$${TOOLSDIR}|g' \
		-e 's|${TOPDIR}|$${TOPDIR}|g' \
		-e 's|^make[:\[].*$$||g'

##############################################################################
list-versions:
	@cmake --version
	@gcc --version | head -1
	@git --version
	@make --version | head -1
	@echo "quilt version `quilt --version`"
	@${MAKE} ${VERSION_TARGETS} | grep -v ^make

##############################################################################
clean-all:
	@$(call banner,Cleaning everything...)
	${MAKE} ${CLEAN_TARGETS}
	@$(call banner,All clean!)

##############################################################################
fetch-all:
	@$(call banner,Fetching external repos...)
	${MAKE} ${FETCH_TARGETS}
	@$(call banner,All external sources fetched!)

##############################################################################
gc-all:
	@$(call banner,Running garbage collection for all git repos...)
	@for DIR in `find -name \*.git | sort` ; do \
		$(call banner,Garbage collection for $$DIR) ; \
		(cd $$DIR; git gc) ; \
	done
	
##############################################################################
mrproper-all: tmp-mrproper
	@$(call banner,Scrubbing everything...)
	${MAKE} ${MRPROPER_TARGETS}
	@$(call banner,All very clean!)

##############################################################################
raze-all: tmp-mrproper
	@$(call banner,Removing everything...)
	${MAKE} ${RAZE_TARGETS}
	@$(call banner,All external sources razed!)

##############################################################################
sync-all: state/prep
	@$(call banner,Syncing everything...)
	${MAKE} ${SYNC_TARGETS}
	@$(call banner,All external sources synced!)
list-sync:
	@echo ${SYNC_TARGETS}

##############################################################################
list-tmpdir:
	@echo ${TMPDIRS}

##############################################################################
tmp-mrproper:
	@$(call banner,Scrubbing tmp dirs...)
	rm -rf $(addsuffix /*,${TMPDIRS})
	@$(call banner,All tmp dirs very clean!)

