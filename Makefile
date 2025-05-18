# Top level Makefile just includes all other Makefiles

# Default target calls the all targets of every .mk file except the common.mk file
.DEFAULT: all
.PHONY: all
all: podman-all pg-managed-all

# Include all .mk files except for common.mk file
include $(filter-out Makefile.common.mk,$(wildcard *.mk))
