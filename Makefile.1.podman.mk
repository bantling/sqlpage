# Postgres podman Makefile

include Makefile.common.mk

# Ensure podman is up so we can use it to build containers
.PHONY: podman-all
podman-all: podman-path podman-machine-init podman-machine-start

# Ensure podman is in the path
.PHONY: podman-path
podman-path:
	echo ">>> Checking if podman is in path"
	which podman > /dev/null 2> /dev/null || { \
	  echo "podman is not installed, or not in your path"; \
	  exit 1; \
	}

# Ensure podman has been initialzed
.PHONY: podman-machine-init
podman-machine-init:
	echo ">>> Checking of podman has been intialized"
	[ "`podman machine list --format "{{.Name}}" | wc -l`" -ge 1 ] || { \
	  echo "Initializing podman"; \
	  podman machine init; \
	}

# Ensure podman has been started
.PHONY: podman-machine-start
podman-machine-start:
	echo ">>> Checking if podman has been started"
	[ "`podman machine list --format "{{.LastUp}}" | grep -i running | wc -l`" -ge 1 ] || { \
	  echo "Starting podman"; \
	  podman machine start; \
	}
