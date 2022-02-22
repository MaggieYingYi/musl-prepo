#
# Makefile for musl (requires GNU make)
#
# This is how simple every makefile should be...
# No, I take that back - actually most should be less than half this size.
#
# Use config.mak to override any of the following variables.
# Do not make changes here.
#

# PH: Added repofile. This the name of the prepo to which output will be
# written. The default may be overridden by specifying REPOFILE=<path> on the
# command line.
REPOFILE ?= clang.db

srcdir = .
exec_prefix = /usr/local
bindir = $(exec_prefix)/bin

prefix = /usr/local/musl
includedir = $(prefix)/include
libdir = $(prefix)/lib
syslibdir = /lib

MALLOC_DIR = mallocng
SRC_DIRS = $(addprefix $(srcdir)/,src/* src/malloc/$(MALLOC_DIR) crt ldso $(COMPAT_SRC_DIRS))
BASE_GLOBS = $(addsuffix /*.c,$(SRC_DIRS))
ARCH_GLOBS = $(addsuffix /$(ARCH)/*.[csS],$(SRC_DIRS))
BASE_SRCS = $(sort $(wildcard $(BASE_GLOBS)))
ARCH_SRCS = $(sort $(wildcard $(ARCH_GLOBS)))
BASE_OBJS = $(patsubst $(srcdir)/%,%.o,$(basename $(BASE_SRCS)))
ARCH_OBJS = $(patsubst $(srcdir)/%,%.o,$(basename $(ARCH_SRCS)))
REPLACED_OBJS = $(sort $(subst /$(ARCH)/,/,$(ARCH_OBJS)))
ALL_OBJS = $(addprefix obj/, $(filter-out $(REPLACED_OBJS), $(sort $(BASE_OBJS) $(ARCH_OBJS))))

LIBC_OBJS = $(filter obj/src/%,$(ALL_OBJS)) $(filter obj/compat/%,$(ALL_OBJS))
LDSO_OBJS = $(filter obj/ldso/%,$(ALL_OBJS:%.o=%.lo))
CRT_OBJS = $(filter obj/crt/%,$(ALL_OBJS))

AOBJS = $(LIBC_OBJS)
LOBJS = $(LIBC_OBJS:.o=.lo)
GENH = obj/include/bits/alltypes.h obj/include/bits/syscall.h
GENH_INT = obj/src/internal/version.h
IMPH = $(addprefix $(srcdir)/, src/internal/stdio_impl.h src/internal/pthread_impl.h src/internal/locale_impl.h src/internal/libc.h)

LDFLAGS =
LDFLAGS_AUTO =
LIBCC = -lgcc
CPPFLAGS =
CFLAGS =
CFLAGS_AUTO = -Os -pipe
CFLAGS_C99FSE = -std=c99 -ffreestanding -nostdinc 

CFLAGS_ALL = $(CFLAGS_C99FSE)
CFLAGS_ALL += -D_XOPEN_SOURCE=700 -I$(srcdir)/arch/$(ARCH) -I$(srcdir)/arch/generic -Iobj/src/internal -I$(srcdir)/src/include -I$(srcdir)/src/internal -Iobj/include -I$(srcdir)/include
CFLAGS_ALL += $(CPPFLAGS) $(CFLAGS_AUTO) $(CFLAGS)

LDFLAGS_ALL = $(LDFLAGS_AUTO) $(LDFLAGS)

AR      = $(CROSS_COMPILE)ar
RANLIB  = $(CROSS_COMPILE)ranlib
INSTALL = $(srcdir)/tools/install.sh

ARCH_INCLUDES = $(wildcard $(srcdir)/arch/$(ARCH)/bits/*.h)
GENERIC_INCLUDES = $(wildcard $(srcdir)/arch/generic/bits/*.h)
INCLUDES = $(wildcard $(srcdir)/include/*.h $(srcdir)/include/*/*.h)
ALL_INCLUDES = $(sort $(INCLUDES:$(srcdir)/%=%) $(GENH:obj/%=%) $(ARCH_INCLUDES:$(srcdir)/arch/$(ARCH)/%=include/%) $(GENERIC_INCLUDES:$(srcdir)/arch/generic/%=include/%))

EMPTY_LIB_NAMES = m rt pthread crypt util xnet resolv dl
EMPTY_LIBS = $(EMPTY_LIB_NAMES:%=lib/lib%.a)
CRT_LIBS = $(addprefix lib/,$(notdir $(CRT_OBJS)))
STATIC_LIBS = lib/libc.a
SHARED_LIBS = lib/libc.so
TOOL_LIBS = lib/musl-gcc.specs
ALL_LIBS = $(CRT_LIBS) $(STATIC_LIBS) $(SHARED_LIBS) $(EMPTY_LIBS) $(TOOL_LIBS)
ALL_TOOLS = obj/musl-gcc

WRAPCC_GCC = gcc
WRAPCC_CLANG = clang

LDSO_PATHNAME = $(syslibdir)/ld-musl-$(ARCH)$(SUBARCH).so.1

-include config.mak
-include $(srcdir)/arch/$(ARCH)/arch.mak

ifeq ($(ARCH),)

all:
	@echo "Please set ARCH in config.mak before running make."
	@exit 1

else
#YY: added all-repo and all-repo2obj.
all: $(ALL_LIBS) $(ALL_TOOLS) all-repo all-repo2obj

OBJ_DIRS = $(sort $(patsubst %/,%,$(dir $(ALL_LIBS) $(ALL_TOOLS) $(ALL_OBJS) $(GENH) $(GENH_INT))) obj/include)

$(ALL_LIBS) $(ALL_TOOLS) $(ALL_OBJS) $(ALL_OBJS:%.o=%.lo) $(GENH) $(GENH_INT): | $(OBJ_DIRS)

$(OBJ_DIRS):
	mkdir -p $@

obj/include/bits/alltypes.h: $(srcdir)/arch/$(ARCH)/bits/alltypes.h.in $(srcdir)/include/alltypes.h.in $(srcdir)/tools/mkalltypes.sed
	sed -f $(srcdir)/tools/mkalltypes.sed $(srcdir)/arch/$(ARCH)/bits/alltypes.h.in $(srcdir)/include/alltypes.h.in > $@

obj/include/bits/syscall.h: $(srcdir)/arch/$(ARCH)/bits/syscall.h.in
	cp $< $@
	sed -n -e s/__NR_/SYS_/p < $< >> $@

obj/src/internal/version.h: $(wildcard $(srcdir)/VERSION $(srcdir)/.git)
	printf '#define VERSION "%s"\n' "$$(cd $(srcdir); sh tools/version.sh)" > $@

obj/src/internal/version.o obj/src/internal/version.lo: obj/src/internal/version.h

obj/crt/rcrt1.o obj/ldso/dlstart.lo obj/ldso/dynlink.lo: $(srcdir)/src/internal/dynlink.h $(srcdir)/arch/$(ARCH)/reloc.h

obj/crt/crt1.o obj/crt/scrt1.o obj/crt/rcrt1.o obj/ldso/dlstart.lo: $(srcdir)/arch/$(ARCH)/crt_arch.h

obj/crt/rcrt1.o: $(srcdir)/ldso/dlstart.c

obj/crt/Scrt1.o obj/crt/rcrt1.o: CFLAGS_ALL += -fPIC

OPTIMIZE_SRCS = $(wildcard $(OPTIMIZE_GLOBS:%=$(srcdir)/src/%))
$(OPTIMIZE_SRCS:$(srcdir)/%.c=obj/%.o) $(OPTIMIZE_SRCS:$(srcdir)/%.c=obj/%.lo): CFLAGS += -O3

MEMOPS_OBJS = $(filter %/memcpy.o %/memmove.o %/memcmp.o %/memset.o, $(LIBC_OBJS))
$(MEMOPS_OBJS) $(MEMOPS_OBJS:%.o=%.lo): CFLAGS_ALL += $(CFLAGS_MEMOPS)

NOSSP_OBJS = $(CRT_OBJS) $(LDSO_OBJS) $(filter \
	%/__libc_start_main.o %/__init_tls.o %/__stack_chk_fail.o \
	%/__set_thread_area.o %/memset.o %/memcpy.o \
	, $(LIBC_OBJS))
$(NOSSP_OBJS) $(NOSSP_OBJS:%.o=%.lo): CFLAGS_ALL += $(CFLAGS_NOSSP)

$(CRT_OBJS): CFLAGS_ALL += -DCRT

$(LOBJS) $(LDSO_OBJS): CFLAGS_ALL += -fPIC

CC_CMD = $(CC) $(CFLAGS_ALL) -c -o $@ $<

# Choose invocation of assembler to be used
ifeq ($(ADD_CFI),yes)
	AS_CMD = LC_ALL=C awk -f $(srcdir)/tools/add-cfi.common.awk -f $(srcdir)/tools/add-cfi.$(ARCH).awk $< | $(CC) $(CFLAGS_ALL) -x assembler -c -o $@ -
else
	AS_CMD = $(CC_CMD)
endif

obj/%.o: $(srcdir)/%.s
	$(AS_CMD)

obj/%.o: $(srcdir)/%.S
	$(CC_CMD)

obj/%.o: $(srcdir)/%.c $(GENH) $(IMPH)
	$(CC_CMD)

obj/%.lo: $(srcdir)/%.s
	$(AS_CMD)

obj/%.lo: $(srcdir)/%.S
	$(CC_CMD)

obj/%.lo: $(srcdir)/%.c $(GENH) $(IMPH)
	$(CC_CMD)

lib/libc.so: $(LOBJS) $(LDSO_OBJS)
	$(CC) $(CFLAGS_ALL) $(LDFLAGS_ALL) -nostdlib -shared \
	-Wl,-e,_dlstart -o $@ $(LOBJS) $(LDSO_OBJS) $(LIBCC)

lib/libc.a: $(AOBJS)
	rm -f $@
	$(AR) rc $@ $(AOBJS)
	$(RANLIB) $@

$(EMPTY_LIBS):
	rm -f $@
	$(AR) rc $@

lib/%.o: obj/crt/$(ARCH)/%.o
	cp $< $@

lib/%.o: obj/crt/%.o
	cp $< $@

lib/musl-gcc.specs: $(srcdir)/tools/musl-gcc.specs.sh config.mak
	sh $< "$(includedir)" "$(libdir)" "$(LDSO_PATHNAME)" > $@

obj/musl-gcc: config.mak
	printf '#!/bin/sh\nexec "$${REALGCC:-$(WRAPCC_GCC)}" "$$@" -specs "%s/musl-gcc.specs"\n' "$(libdir)" > $@
	chmod +x $@

obj/%-clang: $(srcdir)/tools/%-clang.in config.mak
	sed -e 's!@CC@!$(WRAPCC_CLANG)!g' -e 's!@PREFIX@!$(prefix)!g' -e 's!@INCDIR@!$(includedir)!g' -e 's!@LIBDIR@!$(libdir)!g' -e 's!@LDSO@!$(LDSO_PATHNAME)!g' $< > $@
	chmod +x $@

$(DESTDIR)$(bindir)/%: obj/%
	$(INSTALL) -D $< $@

$(DESTDIR)$(libdir)/%.so: lib/%.so
	$(INSTALL) -D -m 755 $< $@

$(DESTDIR)$(libdir)/%: lib/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(includedir)/bits/%: $(srcdir)/arch/$(ARCH)/bits/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(includedir)/bits/%: $(srcdir)/arch/generic/bits/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(includedir)/bits/%: obj/include/bits/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(includedir)/%: $(srcdir)/include/%
	$(INSTALL) -D -m 644 $< $@

$(DESTDIR)$(LDSO_PATHNAME): $(DESTDIR)$(libdir)/libc.so
	$(INSTALL) -D -l $(libdir)/libc.so $@ || true

install-libs: $(ALL_LIBS:lib/%=$(DESTDIR)$(libdir)/%) $(if $(SHARED_LIBS),$(DESTDIR)$(LDSO_PATHNAME),)

install-headers: $(ALL_INCLUDES:include/%=$(DESTDIR)$(includedir)/%)

install-tools: $(ALL_TOOLS:obj/%=$(DESTDIR)$(bindir)/%)

#YY: added install-ticket-libs and install-repo2obj-libs.
install: install-libs install-headers install-tools install-ticket-libs install-repo2obj-libs

musl-git-%.tar.gz: .git
	 git --git-dir=$(srcdir)/.git archive --format=tar.gz --prefix=$(patsubst %.tar.gz,%,$@)/ -o $@ $(patsubst musl-git-%.tar.gz,%,$@)

musl-%.tar.gz: .git
	 git --git-dir=$(srcdir)/.git archive --format=tar.gz --prefix=$(patsubst %.tar.gz,%,$@)/ -o $@ v$(patsubst musl-%.tar.gz,%,$@)

endif
#YY: added include/linux and clang.db.
clean:
	rm -rf obj lib include/linux $(REPOFILE)

distclean: clean
	rm -f config.mak

.PHONY: all clean install install-libs install-headers install-tools

#
# YY: build for the repo target.
#
EXCLUDED_SRCS = ./crt/x86_64/crti.s \
                ./crt/x86_64/crtn.s \
                ./src/fenv/x86_64/fenv.s \
                ./src/ldso/x86_64/dlsym.s \
                ./src/ldso/x86_64/tlsdesc.s \
                ./src/math/x86_64/acosl.s \
                ./src/math/x86_64/asinl.s \
                ./src/math/x86_64/atan2l.s \
                ./src/math/x86_64/atanl.s \
                ./src/math/x86_64/exp2l.s \
                ./src/math/x86_64/expl.s \
                ./src/math/x86_64/floorl.s \
                ./src/math/x86_64/log10l.s \
                ./src/math/x86_64/log1pl.s \
                ./src/math/x86_64/log2l.s \
                ./src/math/x86_64/logl.s \
                ./src/process/x86_64/vfork.s \
                ./src/signal/x86_64/restore.s \
                ./src/signal/x86_64/sigsetjmp.s \
                ./src/string/x86_64/memcpy.s \
                ./src/string/x86_64/memmove.s \
                ./src/string/x86_64/memset.s \
                ./src/thread/x86_64/__unmapself.s \
                ./src/thread/x86_64/syscall_cp.s
EXCLUDED_ALL = ./crt/Scrt1.c \
               ./crt/rcrt1.c \
               ./ldso/dlstart.c \
               ./src/thread/x86_64/__set_thread_area.s \
               ./src/setjmp/x86_64/longjmp.s \
               ./src/setjmp/x86_64/setjmp.s \
               ./src/thread/x86_64/clone.s \
               $(EXCLUDED_SRCS)
EXCLUDED_TICKETS = $(addprefix obj/, $(patsubst $(srcdir)/%,%.t,$(basename $(EXCLUDED_ALL))))
REPLACEMENT_GENERIC = $(sort $(subst /$(ARCH)/,/,$(EXCLUDED_SRCS)))
REPLACEMENT_GENERIC_TICKETS = $(addprefix obj/, $(patsubst $(srcdir)/%,%.t,$(basename $(REPLACEMENT_GENERIC))))
ALL_TICKETS = $(filter-out $(EXCLUDED_TICKETS), $(sort $(ALL_OBJS:.o=.t) $(REPLACEMENT_GENERIC_TICKETS)))

JSON_TICKET = obj/src/thread/__set_thread_area.t \
              obj/src/setjmp/x86_64/longjmp.t \
              obj/src/setjmp/x86_64/setjmp.t \
              obj/src/thread/x86_64/clone.t
JSON_CRT_TICKET = obj/crt/crt1_asm.t

LIBC_TICKETS = $(JSON_TICKET) $(filter obj/src/%,$(ALL_TICKETS)) $(filter obj/compat/%,$(ALL_TICKETS))
CRT_TICKETS = $(JSON_CRT_TICKET) $(filter obj/crt/%,$(ALL_TICKETS))
ATICKETS = $(LIBC_TICKETS)

LINUX_INCLUDES = include/linux/futex.h include/linux/version.h

CRT_TICKET_LIBS = $(addprefix lib/,$(notdir $(CRT_TICKETS)))
STATIC_TICKET_LIBS = lib/libc_repo.a
ALL_TICKET_LIBS = $(CRT_TICKET_LIBS) $(STATIC_TICKET_LIBS) $(EMPTY_LIBS) $(REPOFILE)

all-repo:
	$(MAKE) $(REPOFILE)
	$(MAKE) repo-installs

repo-installs: $(ALL_TICKET_LIBS) $(LINUX_INCLUDES)

$(REPOFILE): src/musl-prepo.json
	-rm -f $@
	pstore-import $@ $<


$(JSON_CRT_TICKET): $(REPOFILE)
	mkdir -p $(dir $@)
	repo-create-ticket --output=$@ --repo=$< 0d89c794f89f75747df70d0f6b2832ed

obj/src/thread/__set_thread_area.t: $(REPOFILE)
	mkdir -p $(dir $@)
	repo-create-ticket --output=$@ --repo=$< 61823da085f534c947264e1497f73741

obj/src/setjmp/x86_64/longjmp.t: $(REPOFILE)
	mkdir -p $(dir $@)
	repo-create-ticket --output=$@ --repo=$< b4969a1aad5e095bfdb567c8929359a2

obj/src/setjmp/x86_64/setjmp.t: $(REPOFILE)
	mkdir -p $(dir $@)
	repo-create-ticket --output=$@ --repo=$< 140eae3767a12b28780d48ef2e02a69e

obj/src/thread/x86_64/clone.t: $(REPOFILE)
	mkdir -p $(dir $@)
	repo-create-ticket --output=$@ --repo=$< 24d6c5a06191cf4bc70ba5c414005d62

obj/src/internal/version.t: obj/src/internal/version.h

obj/crt/crt1.t: CFLAGS_ALL += -D__REPO__

MEMOPS_TICKETS = $(filter %/memcpy.t %/memmove.t %/memcmp.t %/memset.t, $(LIBC_TICKETS))
$(MEMOPS_TICKETS): CFLAGS_ALL += $(CFLAGS_MEMOPS)

NOSSP_TICKETS = $(CRT_TICKETS) $(filter %/__libc_start_main.t \
		%/__init_tls.t %/__stack_chk_fail.t \
		%/__set_thread_area.t %/memset.t %/memcpy.t \
		, $(LIBC_TICKETS))
$(NOSSP_TICKETS): CFLAGS_ALL += $(CFLAGS_NOSSP)

$(CRT_TICKETS): CFLAGS_ALL += -DCRT

$(ALL_TICKETS) $(CRT_TICKETS):  CFLAGS_ALL +=  -target x86_64-pc-linux-gnu-repo

obj/%.t: $(srcdir)/%.s
	$(AS_CMD)

obj/%.t: $(srcdir)/%.S
	$(CC_CMD)

obj/%.t: $(srcdir)/%.c $(GENH) $(IMPH)
	$(CC_CMD)

$(STATIC_TICKET_LIBS): $(ATICKETS)
	rm -f $@
	$(AR) rc $@ $(ATICKETS)
	$(RANLIB) $@

lib/%.t: obj/crt/%.t
	cp $< $@

include/linux/version.h: /usr/include/linux/version.h
	mkdir -p include/linux
	cp -f $< $@

include/linux/futex.h: src/internal/futex.h
	mkdir -p include/linux
	cp -f $< $@

install-ticket-libs: $(ALL_TICKET_LIBS:lib/%=$(DESTDIR)$(libdir)/%)

#
# YY: generate the ELF library from the repo ticket files using the repo2oj tool.
#

utils_dir ?= /usr/share/repo
CRT_REPO2OBJS = $(CRT_TICKETS:.t=.t.o)
CRT_REPO2OBJ_LIBS = $(addprefix lib/,$(notdir $(CRT_REPO2OBJS)))
STATIC_REPO2OBJ_LIBS = lib/libc_elf.a
ALL_REPO2OBJ_LIBS= $(CRT_REPO2OBJ_LIBS) $(STATIC_REPO2OBJ_LIBS)
ARCHIVE = $(utils_dir)/archive.py
REPO2OBJ_CMD = repo2obj -o $@ $<

.PRECIOUS: obj/crt/%.t.o
obj/crt/%.t.o : obj/crt/%.t
	$(REPO2OBJ_CMD)

lib/%.t.o: obj/crt/%.t.o
	mkdir -p lib
	cp $< $@

$(STATIC_REPO2OBJ_LIBS): $(ATICKETS)
	rm -f $@
	$(ARCHIVE) rc $@ $(ATICKETS)
	$(RANLIB) $@

all-repo2obj: $(ALL_REPO2OBJ_LIBS)

install-repo2obj-libs: $(ALL_REPO2OBJ_LIBS:lib/%=$(DESTDIR)$(libdir)/%)

print-%: ; @echo $*=$($*)

