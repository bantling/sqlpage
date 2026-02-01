#!/bin/bash

set -eu

# Disable trust authorization
sed -ri 's,(.*trust),#\1,' /var/lib/postgresql/data/pg_hba.conf
