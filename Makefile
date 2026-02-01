# Top level Makefile just includes all other Makefiles

# Recipes don't echo the lines as they run
.SILENT:

MAKE_FILES   := $(filter-out Makefile.common.mk,$(wildcard *.mk))
MAKE_TARGETS := $(shell echo $(MAKE_FILES) | tr ' ' '\n' | sed -r 's,Makefile[.][^.]*[.](.*)[.]mk,\1,;s,[.],-,;s,$$,-all,')

# Default target calls the all targets of every .mk file except the common.mk file
.DEFAULT: all
.PHONY: all
all: $(MAKE_TARGETS)

# Include all .mk files except for Makefile.common.mk file
include $(MAKE_FILES)
