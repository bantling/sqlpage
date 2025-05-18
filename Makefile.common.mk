#### Change Make defaults

# Turn off default rules
.SUFFIXES:

# Silent, run "make VERBOSE=1 ..." to show output of each recipe invoked
ifndef VERBOSE
.SILENT:
endif

# Execute recipes with shell flags -eu, where:
# -e means die if any command fails with non-zero status
# -u means die if an undefined shell variable is referenced
.SHELLFLAGS := -eu
