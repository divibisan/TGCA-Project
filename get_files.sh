#!/bin/bash

python3 ./NCI_getfiles.py | curl --remote-name --remote-header-name --request POST --header 'Content-Type: application/json' --data @- 'https://api.gdc.cancer.gov/data'