#!/bin/bash

# Give permissions to access the TPM device
chmod 666 /dev/tpm0
chmod 666 /dev/tpmrm0


# Prepopulate PCRs
tpm2_pcrevent 0 /api/docker-entrypoint.sh
tpm2_pcrevent 1 /api/Gemfile
tpm2_pcrevent 2 /api/Rakefile
tpm2_pcrevent 3 /judge0.conf

cron
exec "$@"