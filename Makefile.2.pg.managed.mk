# Postgres managed container Makefile

include Makefile.common.mk

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
PG_MANAGED_SRC_ENV_ARG := $(if $(PG_MANAGED_SRC_ENV),--build-arg "PG_MANAGED_SRC_ENV_DIR=$(PG_MANAGED_SRC_ENV_DIR)",)

# Database name, and app_exec user password
PG_MANAGED_DB_NAME            := pg_managed
PG_MANAGED_PASS               := pg_managed_pass
PG_MANAGED_EXEC_USER          := managed_app_exec
PG_MANAGED_EXEC_PASS          := pg_managed_exec_pass
PG_MANAGED_NUM_SEED_CUSTOMERS := 1_000

#### Targets

# Default target
.PHONY: pg-managed-all
all: pg-managed-vars pg-managed-oci

# Ensure all oci container building operations are performed, so we have all the containers we need to run the app
.PHONY: pg-managed-oci
pg-managed-oci: pg-managed-oci-clean pg-managed-oci-pull pg-managed-oci-build pg-managed-oci-run

# Clean oci artifacts: remove all containers related to the image, and the image itself
# The only thing not removed is the base image needed to build the code
.PHONY: pg-managed-oci-clean
pg-managed-oci-clean:
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
.PHONY: pg-managed-oci-pull
pg-managed-oci-pull:
	echo ">>> Checking if postgres images need to be pulled"
	[ "`podman image list --format "{{.ID}}" --filter "reference=$(PG_MANAGED_IMAGE_REF)" | wc -l`" -gt 0 ] || { \
	  echo "Pulling compile image"; \
	  podman pull $(PG_MANAGED_IMAGE_REF); \
	}

# Always build oci/.Containerfile-pg-managed in case args have changed
.PHONY: oci/.Containerfile-pg-managed
oci/.Containerfile-pg-managed: oci/Containerfile-pg-managed.in
	echo ">>> Generating $@"
	cp $< $@
	if [ -n "$(PG_MANAGED_SRC_ENV_ARG)" ]; then echo "Include $(PG_MANAGED_SRC_ENV_DIR)"; sed 's,#COPY,COPY,' $@ > $@.tmp; mv $@.tmp $@; fi

# Build oci image
# Pruning removes the unnamed initial stage images of multi stage builds
.PHONY: pg-managed-oci-build
pg-managed-oci-build: oci/.Containerfile-pg-managed
	echo ">>> Building postgres managed image"
	podman build \
	  --build-arg "PG_MANAGED_IMAGE_REF=$(PG_MANAGED_IMAGE_REF)" \
	  --build-arg "PG_MANAGED_EXEC_PASS=$(PG_MANAGED_EXEC_PASS)" \
	  --build-arg "PG_MANAGED_NUM_SEED_CUSTOMERS=$(PG_MANAGED_NUM_SEED_CUSTOMERS)" \
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
.PHONY: pg-managed-oci-run
pg-managed-oci-run:
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

# Display logs for running postgres container
.PHONY: pg-managed-oci-logs
pg-managed-oci-logs:
	podman logs $(PG_MANAGED_DEPLOY_NAME)

# Run psql inside running postgres container as app layer user
.PHONY: pg-managed-oci-psql
pg-managed-oci-psql:
	podman exec -e "PGPASSWORD=$(PG_MANAGED_EXEC_PASS)" -it $(PG_MANAGED_DEPLOY_NAME) psql -U $(PG_MANAGED_EXEC_USER) -h 127.0.0.1 -d $(PG_MANAGED_DB_NAME)

# Run psql inside running postgres container as postgres super user
.PHONY: pg-managed-oci-super
pg-managed-oci-super:
	podman exec -e "PGPASSWORD=$(PG_MANAGED_PASS)" -it $(PG_MANAGED_DEPLOY_NAME) psql -U postgres -h 127.0.0.1 -d $(PG_MANAGED_DB_NAME)

# Run bash inside running postgres container
.PHONY: pg-managed-oci-bash
pg-managed-oci-bash:
	podman exec -it $(PG_MANAGED_DEPLOY_NAME) /bin/bash

.PHONY: pg-managed-vars
pg-managed-vars:
	echo ">>> Displaying pg-managed variables"
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
	echo "PG_MANAGED_EXEC_USER   = $(PG_MANAGED_EXEC_USER)"
	echo "PG_MANAGED_EXEC_PASS   = $(PG_MANAGED_EXEC_PASS)"
