#!/bin/bash
#
# Store Brazilian Government's Certificate Authorities certificate chain
#

set -euo pipefail
IFS=$'\n\t'

TODAY=$(date +'%Y%m%d')
URL='http://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil'

echo 'Baixando arquivo de hash...'
curl -sO "${URL}/hashsha512.txt"
if [[ "$(git diff hashsha512.txt)" == "" ]]; then
    echo 'No change in checksum file.'
    exit
fi

echo 'Baixando arquivo de cadeia de certificados...'
curl -sO "${URL}/ACcompactado.zip"
sha512sum -c hashsha512.txt
rm certs/*

echo 'Extraindo arquivo zip...'
unzip -q ACcompactado.zip -d certs

git diff --name-only --diff-filter=D certs/ | xargs -r git rm
git diff --name-only --diff-filter=ACM certs/ | xargs -r git add
if git diff-index --cached --quiet HEAD; then
    echo 'Nothing to commit'
else
    git add hashsha512.txt
    git commit -m "Update to ${TODAY}"
    git push
fi
