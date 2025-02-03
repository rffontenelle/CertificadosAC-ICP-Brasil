#!/bin/bash
# Store Brazilian Government's Certificate Authorities certificate chain
#

set -euo pipefail
IFS=$'\n\t'

TODAY=$(date +'%Y%m%d')
URL='http://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil'

echo 'Downloading hash file...'
curl -sO -H 'Cache-Control: no-cache' "${URL}/hashsha512.txt"
sleep 1
if [[ "$(git diff hashsha512.txt)" == "" ]]; then
    echo 'No changes in the checksum file. Quitting.'
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
Added=$(git ls-files --others --exclude-standard certs/)
Deleted=$(git diff --name-only --diff-filter=D certs/)
Changed=$(git diff --name-only --diff-filter=C certs/)
Moved=$(git diff --name-only --diff-filter=M certs/)

echo $Deleted | xargs -r git rm
echo $Added $Changed $Moved | xargs -r git add

git add certs/
if git diff-index --cached --quiet HEAD; then
    echo 'ERROR: Nothing to commit, and that is unexpected.'
    exit 1
else
    # Format the message for commit and changelog
    touch message.txt
    echo "Update to ${TODAY}" > message.txt
    echo "" >> message.txt
    for type in Added Deleted Changed Moved; do
      if [[ "${!type}" != "" ]]; then
        echo "- $type:" >> message.txt
        for file in ${!type}; do
          echo "  - $file" >> message.txt
        done
        echo "" >> message.txt
      fi
    done

    # Store the message in changelog
    echo -e "----\n" >> CHANGELOG.md
    echo -n "## " >> CHANGELOG.md
    cat message.txt >> CHANGELOG.md

    git add hashsha512.txt CHANGELOG.md
    git commit --dry-run -F message.txt
fi
