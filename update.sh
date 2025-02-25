#!/bin/bash
# Store Brazilian Government's Certificate Authorities certificate chain
#

set -euo pipefail
IFS=$'\n\t'

TODAY=$(date +'%Y%m%d')
URL='http://acraiz.icpbrasil.gov.br/credenciadas/CertificadosAC-ICP-Brasil'

PREV_HASH=$(cat hashsha512.txt | cut -d' ' -f1)
echo -n 'Downloading hash file... '
curl -sO -H 'Cache-Control: no-cache' "${URL}/hashsha512.txt"
echo 'Done'
NEW_HASH=$(cat hashsha512.txt | cut -d' ' -f1)
echo "Previous hash: $PREV_HASH"
echo "Newest hash:   $NEW_HASH"
if [[ "$NEW_HASH" == "$PREV_HASH" ]]; then
    echo 'Checksums are identical, no action required.'
    exit
fi

echo -n 'Fetching CA certificate chain... '
curl -sO "${URL}/ACcompactado.zip"
echo 'Done'

echo -n "Checking stored checksum against downloaded file... "
sha512sum -c hashsha512.txt
rm certs/*

echo -n 'Extracting zip file... '
unzip -q ACcompactado.zip -d certs
echo 'Done'

echo -n 'Changing file permissions to 644... '
chmod 644 certs/*
echo 'Done'

echo -n 'Doing git-rm of obsolete and git-add of new/updated... '
Added=$(git ls-files --others --exclude-standard certs/)
Deleted=$(git diff --name-only --diff-filter=D certs/)
Changed=$(git diff --name-only --diff-filter=C certs/)
Moved=$(git diff --name-only --diff-filter=M certs/)
echo $Deleted | xargs -r git rm
echo $Added $Changed $Moved | xargs -r git add
echo 'Done'

if git diff-index --cached --quiet HEAD; then
    echo 'ERROR: Nothing to commit, and that is unexpected.'
    exit 1
else
    # Format the commit message
    rm -f message.txt
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

    # Store the same commit message in the changelog file
    echo -e "----\n" >> CHANGELOG.md
    echo -n "## " >> CHANGELOG.md
    cat message.txt >> CHANGELOG.md

    git add hashsha512.txt CHANGELOG.md

    # Do not actually commit on Pull Requests, allowing to test this script
    set +u
    dry_run=''
    if [[ "$GITHUB_EVENT_NAME" == 'pull_request' ]]; then
      dry_run='--dry-run'
    fi

    git commit $dry_run -F message.txt
fi
