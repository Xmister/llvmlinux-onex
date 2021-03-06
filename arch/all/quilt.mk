#############################################################################
# Copyright (c) 2012 Behan Webster
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

# Must be included by all.mk

#############################################################################
ifeq "${KERNEL_REPO_PATCHES}" ""
ifneq "${KERNEL_TAG}" ""
KERNEL_REPO_PATCHES = ${KERNEL_TAG}
else
KERNEL_REPO_PATCHES = ${KERNEL_BRANCH}
endif
endif

#############################################################################
GENERIC_PATCH_DIR	= $(filter-out %${KERNEL_REPO_PATCHES},$(filter-out ${TARGETDIR}/%,${KERNEL_PATCH_DIR}))
GENERIC_PATCH_SERIES	= $(addsuffix /series,$(GENERIC_PATCH_DIR))
TARGET_PATCH_SERIES	= ${PATCHDIR}/series
SERIES_DOT_TARGET	= ${TARGET_PATCH_SERIES}.target
ALL_PATCH_SERIES	= ${GENERIC_PATCH_SERIES} ${SERIES_DOT_TARGET}
PATCH_FILTER_REGEX	= .*

#############################################################################
checkfilefor	= grep -q ${2} ${1} || echo "${2}${3}" >> ${1}
reverselist	= mkdir -p ${TMPDIR}; for DIR in ${1} ; do echo $$DIR; done | tac
ln_if_new	= ls -l "${2}" 2>&1 | grep -q "${1}" || ln -fsv "${1}" "${2}"
mv_n_ln		= mv "${1}" "${2}" ; ln -sv "${2}" "${1}"

#############################################################################
QUILT_TARGETS		= kernel-quilt kernel-quilt-clean kernel-quilt-generate-series kernel-quilt-update-series-dot-target \
				kernel-quilt-link-patches kernel-patches-tar kernel-quilt-clean-broken-symlinks \
				list-kernel-patches list-kernel-patches-path list-kernel-maintainer list-kernel-checkpatch
TARGETS_BUILD		+= ${QUILT_TARGETS}
CLEAN_TARGETS		+= kernel-quilt-clean
HELP_TARGETS		+= kernel-quilt-help
MRPROPER_TARGETS	+= kernel-quilt-clean
SETTINGS_TARGETS	+= kernel-quilt-settings

.PHONY:			${QUILT_TARGETS} kernel-quilt-help kernel-quilt-settings

#############################################################################
kernel-quilt-help:
	@echo
	@echo "These are the quilt (patching) make targets:"
	@echo "* make kernel-quilt - Setup kernel(s) to be patched by quilt"
	@echo "* make kernel-quilt-clean - Remove quilt setup"
	@echo "* make kernel-quilt-generate-series"
	@echo "			- Build kernel quilt series file"
	@echo "* make kernel-quilt-update-series-dot-target"
	@echo "			- Save updates from kernel quilt series file to series.target file"
	@echo "* make kernel-quilt-link-patches"
	@echo "			- Link kernel patches to target patches directory"
	@echo "* make kernel-patches-tar"
	@echo "			- build a patches.tar.bz2 file containing all the patches for this target"
	@echo "* make kernel-quilt-clean-broken-symlinks"
	@echo "			- Remove links to deleted kernel patches from target patches directory"
	@echo "* make list-kernel-patches-path"
	@echo "			- List the order in which kernel patches directories are searched for patch filenames"
	@echo "* make list-kernel-patches"
	@echo "			- List which kernel patches will be applied"
	@echo
	@echo "* make list-kernel-checkpatch [PATCH_FILTER_REGEX=<regex>]"
	@echo "			- List which kernel maintainers should be contacted for each patch"
	@echo "* make list-kernel-maintainer [PATCH_FILTER_REGEX=<regex>]"
	@echo "			- List which kernel maintainers should be contacted for each patch"

#############################################################################
kernel-quilt-settings:
	@($(call prsetting,KERNEL_REPO_PATCHES,${KERNEL_REPO_PATCHES}) ; \
	[ -n "${CHECKPOINT}" ] && $(call prsetting,PATCHDIR,${CHECKPOINT_KERNEL_PATCHES}) \
	&& $(call prsetting,KERNEL_PATCH_DIR,${CHECKPOINT_KERNEL_PATCHES}) \
	|| $(call praddsetting,KERNEL_PATCH_DIR,${PATCHDIR} ${PATCHDIR}/${KERNEL_REPO_PATCHES}) ; \
	) | $(call configfilter)

##############################################################################
# Tweak quilt setup to make diffs-of-diffs easier to read
QUILTRC	= ${HOME}/.quiltrc
kernel-quiltrc: ${QUILTRC}
${QUILTRC}:
	@$(call banner,Setting up quilt rc file...)
	@touch $@
	@$(call checkfilefor,$@,QUILT_NO_DIFF_INDEX,=1)
	@$(call checkfilefor,$@,QUILT_NO_DIFF_TIMESTAMPS,=1)
	@$(call checkfilefor,$@,QUILT_PAGER,=)

# Always check ~/.quiltrc
.PHONY: ${QUILTRC}

##############################################################################
# Handle the case of renaming target/%/series -> target/%/series.target
kernel-quilt-series-dot-target: ${SERIES_DOT_TARGET}
${SERIES_DOT_TARGET}:
	@$(call banner,Updating quilt series.target file for kernel...)
	@mkdir -p $(dir $@)
	@[ -f ${TARGET_PATCH_SERIES} ] || touch ${TARGET_PATCH_SERIES}
# Rename target series file to series.target (we will be generating the new series file)
	@[ -e $@ ] || mv ${TARGET_PATCH_SERIES} $@

##############################################################################
# Save any new patches from the generated series file to the series.target file
kernel-quilt-update-series-dot-target: ${SERIES_DOT_TARGET}
	-@[ ! -d ${TARGET_PATCH_SERIES} ] \
		|| [ `stat -c %Z ${TARGET_PATCH_SERIES}` -le `stat -c %Z ${SERIES_DOT_TARGET}` ] \
		|| ($(call echo,Saving quilt changes to series.target file for kernel...) ; \
		diff ${TARGET_PATCH_SERIES} ${SERIES_DOT_TARGET} \
		| perl -ne 'print "$$1\n" if $$hunk>1 && /^< (.*)$$/; $$hunk++ if /^[^<>]/' \
		>> ${SERIES_DOT_TARGET}; touch ${SERIES_DOT_TARGET})

##############################################################################
uniq = perl -ne 'print unless $$u{$$_}; $$u{$$_}=1'

##############################################################################
# Generate target series file from relevant kernel quilt patch series files
kernel-quilt-generate-series: ${TARGET_PATCH_SERIES}
${TARGET_PATCH_SERIES}: ${ALL_PATCH_SERIES}
	@$(MAKE) kernel-quilt-update-series-dot-target
	@$(call banner,Building quilt series file for kernel...)
	@cat ${ALL_PATCH_SERIES} | $(call uniq) > $@

##############################################################################
# Have git ignore extra patch files
QUILT_GITIGNORE	= ${PATCHDIR}/.gitignore
kernel-quilt-ignore-links: ${QUILT_GITIGNORE}
${QUILT_GITIGNORE}: ${GENERIC_PATCH_SERIES}
	@$(call banner,Ignore symbolic linked quilt patches for kernel...)
	@mkdir -p $(dir $@)
	@echo .gitignore > $@
	@echo series >> $@
	@cat ${GENERIC_PATCH_SERIES} >> $@

##############################################################################
# Remove broken symbolic links to old patches
kernel-quilt-clean-broken-symlinks:
	@$(call banner,Removing broken symbolic linked quilt patches for kernel...)
	@[ -d ${PATCHDIR} ] && file ${PATCHDIR}/* | awk -F: '/broken symbolic link to/ {print $$1}' | xargs --no-run-if-empty rm

##############################################################################
# Move updated patches back to their proper place, and link patch files into target patches dir
kernel-quilt-link-patches refresh: ${QUILT_GITIGNORE}
	@[ -z "${GENERIC_PATCH_SERIES}" ] \
	|| ($(MAKE) kernel-quilt-update-series-dot-target kernel-quilt-clean-broken-symlinks \
	&& $(call banner,Linking quilt patches for kernel...) \
	&& REVDIRS=`$(call reverselist,${KERNEL_PATCH_DIR})` \
	&& for PATCH in `cat ${GENERIC_PATCH_SERIES}` ; do \
		PATCHLINK="${PATCHDIR}/$$PATCH" ; \
		for DIR in $$REVDIRS ; do \
			[ "$$DIR" != "${PATCHDIR}" ] || continue ; \
			if [ -f "$$DIR/$$PATCH" -a ! -L "$$DIR/$$PATCH" ] ; then \
				if [ -f "$$PATCHLINK" -a ! -L "$$PATCHLINK" ] ; then \
					$(call mv_n_ln,$$PATCHLINK,$$DIR/$$PATCH) ; \
				else \
					$(call ln_if_new,$$DIR/$$PATCH,$$PATCHLINK) ; \
				fi ; \
				rm -f ${TARGET_PATCH_SERIES} ; \
				break; \
			fi ; \
		done ; \
	done | sed -e 's|${TARGETDIR}|.|g; s|${TOPDIR}|...|g' ; \
	$(MAKE) ${TARGET_PATCH_SERIES})

##############################################################################
KERNEL_PATCHES_TAR = patches.tar.bz2
kernel-patches-tar: ${KERNEL_PATCHES_TAR}
${KERNEL_PATCHES_TAR}: kernel-quilt-link-patches
	@tar chfj $@ patches/series `grep -v ^# patches/series | sed -e 's|^|patches/|'`
	@$(call banner,Created $@)

##############################################################################
QUILT_STATE	= state/kernel-quilt
kernel-quilt: ${QUILT_STATE}
${QUILT_STATE}: state/prep state/kernel-fetch 
	@$(MAKE) ${QUILTRC} kernel-quilt-link-patches
	@$(call banner,Quilted kernel...)
	$(call state,$@,kernel-patch)

##############################################################################
# List patch search path
list-kernel-patches-path:
	@$(call reverselist,${KERNEL_PATCH_DIR})

##############################################################################
# List all patches which are being applied to the kernel
list-kernel-patches:
	@REVDIRS=`$(call reverselist,${KERNEL_PATCH_DIR})` ; \
	for PATCH in `cat ${ALL_PATCH_SERIES}` ; do \
		for DIR in $$REVDIRS ; do \
			if [ -f "$$DIR/$$PATCH" -a ! -L "$$DIR/$$PATCH" ] ; then \
				echo "$$DIR/$$PATCH" ; \
				break; \
			fi ; \
		done ; \
	done

##############################################################################
# List maintainers who are relevant to a particular patch
# You can specify a regex to narrow down the patches by setting PATCH_FILTER_REGEX
# e.g. make PATCH_FILTER_REGEX=vlais\* list-kernel-maintainer
list-kernel-maintainer: list-kernel-get_maintainer
list-kernel-checkpatch list-kernel-get_maintainer: list-kernel-%:
	@$(call banner,Running $* for patches PATCH_FILTER_REGEX="${PATCH_FILTER_REGEX}")
	@(REVDIRS=`$(call reverselist,${KERNEL_PATCH_DIR})` ; \
	cd ${KERNELDIR} ; \
	for PATCH in `cat ${ALL_PATCH_SERIES} | grep "${PATCH_FILTER_REGEX}"` ; do \
		for DIR in $$REVDIRS ; do \
			if [ -f "$$DIR/$$PATCH" -a ! -L "$$DIR/$$PATCH" ] ; then \
				$(call echo,$$DIR/$$PATCH) ; \
				./scripts/$*.pl "$$DIR/$$PATCH" ; \
				break; \
			fi ; \
		done ; \
	done)

##############################################################################
kernel-quilt-clean: ${SERIES_DOT_TARGET}
	@$(call banner,Removing symbolic linked quilt patches for kernel...)
	@rm -f ${QUILT_GITIGNORE}
	@[ ! -f ${SERIES_DOT_TARGET} ] || rm -f ${TARGET_PATCH_SERIES}
	@for FILE in ${PATCHDIR}/* ; do \
		[ ! -L $$FILE ] || rm $$FILE; \
	done
	@rm -f ${QUILT_STATE}
	@$(call banner,Quilting cleaned)

