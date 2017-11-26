#!/bin/bash
cwd=$(pwd)
echo $cwd

# Array holding diseases to download files for
# First word is the tissue type, all following words are the disease name
#  EX: "Blood,Acute Myeloid Leukemia" will download files for "Acute Myeloid Leukemia"
#        and extract them to /files/Blood

diseases=( 
"Skin,Skin Cutaneous Melanoma" 
"Breast,Breast Invasive Carcinoma" 
"Blood,Acute Myeloid Leukemia" 
"Cervix,Cervical Squamous Cell Carcinoma and Endocervical Adenocarcinoma" 
"Uterus,Uterine Corpus Endometrial Carcinoma" )

# Loop through disease array
for disease in "${diseases[@]}"
do
    # Split disease on comma, store first word as tissue_name, the rest as disease_name
    IFS=',' read -r tissue_name disease_name  <<< "$disease"
    echo $tissue_name
    echo $disease_name
    
    # Run python script to get file_ids, pass to curl to download *.tar.gz containing files
    python3 ./NCI_getfiles.py "$disease_name" | 
    curl --remote-name --remote-header-name --request POST --header 'Content-Type: application/json' --data @- 'https://api.gdc.cancer.gov/data'

    # Get the compressed file (the newest .gz file)
    tarfile=$(find . -name "*.gz" -type f -print0 | xargs -0 stat -f "%m %N" | sort -rn | head -1 | cut -f2- -d" ")

    # Get the manifest file (the newest .csv file)
    manifestfile=./file_manifest.csv
    
    # Make directories for expanded files
    mkdir files
    mkdir files/$tissue_name

    # Move file manifest to disease specific directory
    mv -f $manifestfile files/$tissue_name/$manifestfile
    
    # Expand downloaded file
    tar -xf $tarfile -C ./files
    # Delete tar file
    rm $tarfile
    
    # Loop through all .gz files contained in .tar file
    #    Expand, move to disease specific directory, then delete parent directory
    for f in $(find ./files -name '*.gz')
    do
        gzip -d $f
        mv -f ${f%%.gz} ./files/$tissue_name
        rm -r $(dirname "$f")
    done
done