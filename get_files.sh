#!/bin/bash
cwd=$(pwd)
echo $cwd

python3 ./NCI_getfiles.py "Lung Squamous Cell Carcinoma"|
curl --remote-name --remote-header-name --request POST --header 'Content-Type: application/json' --data @- 'https://api.gdc.cancer.gov/data'

# Get the newest file
newfile=$(find . -name "*.gz" -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -f2- -d" ")

echo $newfile
mkdir files
mkdir files/unzip

# Expand downloaded file to directory
tar -xf $newfile -C ./files

# Unzip files and transfer to new directory
for f in $(find ./files -name '*.gz')
do
    gzip -d $f
    mv -f ${f%%.gz} ./files/unzip
    parentdir=$(dirname "$f")
    rm -r $parentdir
done