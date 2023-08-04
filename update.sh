#!/bin/bash
# Store Brazilian Government's Certificate Authorities certificate chain
#

set -euo pipefail
IFS=$'\n\t'

TODAY=$(date +'%Y%m%d')
URL='http://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil'

echo 'Downloading hash file...'
curl -sO "${URL}/hashsha512.txt"
if [[ "$(git diff hashsha512.txt)" == "" ]]; then
    echo 'No change in checksum file. Quiting.'
    exit
fi

echo 'Fetching CA certificate chain...'
curl -sO "${URL}/ACcompactado.zip"
sha512sum -c hashsha512.txt
rm certs/*

echo 'Extracting zip file...'
unzip -q ACcompactado.zip -d certs
chmod 644 certs/*

echo 'Commiting updates...'
git diff --name-only --diff-filter=D certs/ | xargs -r git rm
git diff --name-only --diff-filter=ACM certs/ | xargs -r git add
git add certs/
if git diff-index --cached --quiet HEAD; then
    echo 'error: Nothing to commit, and that is unexpected.'
    exit 1
else
    git add hashsha512.txt
    git commit -m "Update to ${TODAY}"
fi
