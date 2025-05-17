# Postgres Makefile

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

#### Variables

# Postgres managed image ref - see https://hub.docker.com/_/postgres for tags
# This is the managed image that in the cloud would get created as a managed database
PG_MANAGED_IMAGE_NAME := postgres
PG_MANAGED_IMAGE_VER  := 17
PG_MANAGED_IMAGE_REF  := $(PG_MANAGED_IMAGE_NAME):$(PG_MANAGED_IMAGE_VER)

# Generated managed image
PG_MANAGED_DEPLOY_NAME := pg_managed_db
PG_MANAGED_DEPLOY_VER  := 1.0
PG_MANAGED_DEPLOY_REF  := $(PG_MANAGED_DEPLOY_NAME):$(PG_MANAGED_DEPLOY_VER)

# Dir of env source code (DML only)
PG_MANAGED_SRC_ENV     := local
PG_MANAGED_SRC_ENV_DIR := $(if $(PG_MANAGED_SRC_ENV),src-env/$(PG_MANAGED_SRC_ENV),)
PG_MANAGED_SRC_ENV_ARG := $(if $(PG_MANAGED_SRC_ENV),--build-arg "PG_SRC_ENV_DIR=$(PG_MANAGED_SRC_ENV_DIR)",)

# Database name, and app_exec user password
PG_MANAGED_DB_NAME    := pg_managed
PG_MANAGED_PASS       := postgres
PG_MANAGED_EXEC_PASS  := pg_managed_exec_pass
PG_NUM_SEED_CUSTOMERS := 50

# Number of seed rows to generate for customers
#PG_MANAGED_NUM_CUSTOMERS_GEN := 5

#### Targets

# Default target
.PHONY: all
all: vars podman oci

# Ensure podman is up so we can use it to build containers
.PHONY: podman
podman: podman-path podman-machine-init podman-machine-start

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

# Ensure all oci container building operations are performed, so we have all the containers we need to run the app
.PHONY: oci
oci: podman oci-clean oci-pull oci-managed-build oci-managed-run

# Clean oci artifacts: remove all containers related to the image, and the image itself
# The only thing not removed is the base image needed to build the code
.PHONY: oci-clean
oci-clean:
	echo ">>> Cleaning previously generated Postgres OCI images and containers"
	for id in `podman ps -a --format '{{.ID}} {{.Image}}' | grep $(PG_MANAGED_DEPLOY_REF) | awk '{print $$1}'`; \
	do \
	  echo "Removing container $$id"; \
	  podman rm -f "$$id"; \
	done
	for id in `podman image ls --format '{{.ID}} {{.Repository}}:{{.Tag}}' | grep $(PG_MANAGED_DEPLOY_REF) | awk '{print $$1}'`; \
	do \
	  echo "Removing image $$id"; \
	  podman image rm "$$id"; \
	done

# Pull oci postgres images
.PHONY: oci-pull
oci-pull:
	echo ">>> Checking if postgres images need to be pulled"
	[ "`podman image list --format "{{.ID}}" --filter "reference=$(PG_MANAGED_IMAGE_REF)" | wc -l`" -gt 0 ] || { \
	  echo "Pulling compile image"; \
	  podman pull $(PG_MANAGED_IMAGE_REF); \
	}

# Always build docker/.Containerfile-postgres-managed in case args have changed
.PHONY: docker/.Containerfile-postgres-managed
docker/.Containerfile-postgres-managed: docker/Containerfile-postgres-managed.in
	echo ">>> Generating $@"
	cp $< $@
	if [ -n "$(PG_MANAGED_SRC_ENV_ARG)" ]; then echo "Include src-env"; sed 's,#COPY,COPY,' $@ > $@.tmp; mv $@.tmp $@; fi

# Build oci image
# Pruning removes the unnamed initial stage images of multi stage builds
.PHONY: oci-managed-build
oci-managed-build: docker/.Containerfile-postgres-managed
	echo ">>> Building postgres managed image"
	podman build \
	  --build-arg "PG_IMAGE_REF=$(PG_MANAGED_IMAGE_REF)" \
	  --build-arg "PG_EXEC_PASS=$(PG_MANAGED_EXEC_PASS)" \
	  --build-arg "PG_NUM_SEED_CUSTOMERS=$(PG_NUM_SEED_CUSTOMERS)" \
	  $(PG_MANAGED_SRC_ENV_ARG) \
	  -f $< \
	  -t $(PG_MANAGED_DEPLOY_REF) \
	  db/postgres/managed
	podman system prune -f

# Run oci image
# If there are no errors, "database system is ready to accept connections" occurs twice
# If there are errors, "database system is ready to accept connections" occurs once, followed by ERROR line
# Use a loop to check for one of two things:
# - 2 logging lines that say "database system is ready to accept connections", indicating success
# - At least 1 ERROR line, indicating failure
.PHONY: oci-managed-run
oci-managed-run:
	echo ">>> Running postgres managed container"; \
	podman create \
	  --name=$(PG_MANAGED_DEPLOY_NAME) \
	  -e POSTGRES_DB=$(PG_MANAGED_DB_NAME) \
	  -e POSTGRES_PASSWORD="$(PG_MANAGED_PASS)" \
	  -p 5432:5432 \
	  $(PG_MANAGED_DEPLOY_REF)
	podman start $(PG_MANAGED_DEPLOY_NAME)
	while true; do \
	  sleep 1; \
	  printf "."; \
	  [ "`podman logs $(PG_MANAGED_DEPLOY_NAME) 2>&1 | grep "database system is ready to accept connections" | wc -l`" -lt 2 ] || { \
	    break; \
	  }; \
	  [ "`podman logs $(PG_MANAGED_DEPLOY_NAME) 2>&1 | grep "ERROR" | wc -l`" -lt 1 ] || { \
	    echo; \
	    podman logs $(PG_MANAGED_DEPLOY_NAME); \
	    exit 1; \
	  }; \
	done; \
	echo; \
	echo "Database $(PG_MANAGED_DEPLOY_REF) started"

# Run psql inside running postgres container
.PHONY: oci-managed-psql
oci-managed-psql:
	podman exec -it $(PG_MANAGED_DEPLOY_NAME) psql -U postgres -d $(PG_MANAGED_DB_NAME)

# Run bash inside running postgres container
.PHONY: oci-managed-bash
oci-managed-bash:
	podman exec -it $(PG_MANAGED_DEPLOY_NAME) /bin/bash

.PHONY: vars
vars:
	echo ">>> Displaying variables"
	echo "PG_MANAGED_IMAGE_NAME  = $(PG_MANAGED_IMAGE_NAME)"
	echo "PG_MANAGED_IMAGE_VER   = $(PG_MANAGED_IMAGE_VER)"
	echo "PG_MANAGED_IMAGE_REF   = $(PG_MANAGED_IMAGE_REF)"
	echo "PG_MANAGED_DEPLOY_NAME = $(PG_MANAGED_DEPLOY_NAME)"
	echo "PG_MANAGED_DEPLOY_VER  = $(PG_MANAGED_DEPLOY_VER)"
	echo "PG_MANAGED_DEPLOY_REF  = $(PG_MANAGED_DEPLOY_REF)"
	echo "PG_MANAGED_SRC_ENV     = $(PG_MANAGED_SRC_ENV)"
	echo "PG_MANAGED_SRC_ENV_DIR = $(PG_MANAGED_SRC_ENV_DIR)"
	echo "PG_MANAGED_SRC_ENV_ARG = $(PG_MANAGED_SRC_ENV_ARG)"
	echo "PG_MANAGED_DB_NAME     = $(PG_MANAGED_DB_NAME)"
	echo "PG_MANAGED_PASS        = $(PG_MANAGED_PASS)"
	echo "PG_MANAGED_EXEC_PASS   = ${PG_MANAGED_EXEC_PASS}"
