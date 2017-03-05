#!/bin/bash

# =============================================================================
#
# Import several individual files:
# From: Google Cloud Storage
# To: Google Earth Engine Assets
#
# Ghislain Vieilledent <ghislain.vieilledent@cirad.fr>
# Astrid Verhegghen <astrid.verhegghen@jrc.eu.europa.ec>
# Christelle Vancutsem <christelle.vancutsem@jrc.eu.europa.ec>

# Notes:
# 1. GOOGLE EARTH ENGINE (abbreviated GEE)
# - GEE account is needed: https://earthengine.google.com
# - GEE Command Line Tool (earthengine) must be installed: https://developers.google.com/earth-engine/command_line
#   It is installed automatically when you install the GEE API Python client: https://developers.google.com/earth-engine/python_install
# 2. GOOGLE CLOUD STORAGE (abbreviated GS or GCS)
# - GS is needed: https://cloud.google.com/storage 
# - Google Cloud SDK must be installed: https://cloud.google.com/sdk/docs/#deb (gives access to command gsutil for example)
# 3. EXECUTION
# - make this script executable (with command chmod +x import.sh) and execute with ./import.sh
#  -or execute directly with /bin/bash import.sh
#
# =============================================================================

RegExp=".*Annual_SumNF1_UL43E11S_LR51E26S.*" # Regular expression to match desired pattern https://en.wikipedia.org/wiki/Regular_expression
tiffs=$(gsutil ls gs://roadlessafr/ | grep -E $RegExp)
folder="users/ghislainv/christelle" # Path to folder in GEE assets
for i in $tiffs
do
    j=$(echo ${i:17}) # Remove "gs://roadlessafr/" from filename
    f=${j%%.*} # Remove extension from filename
    earthengine upload image --asset_id="$folder/$f" $i
    echo "$f has been imported in GEE"
done

