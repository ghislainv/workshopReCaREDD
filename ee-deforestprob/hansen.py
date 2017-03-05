#!/usr/bin/env python

# =============================================================================
#
# Estimating deforestation probability with Python and GEE API
#
# Ghislain Vieilledent <ghislain.vieilledent@cirad.fr> / <ghislainv@gmail.com>
#
# Notes:
# 1. GOOGLE EARTH ENGINE (abbreviated GEE)
# - GEE account is needed: https://earthengine.google.com
# - GEE API Python client is needed:
#   https://developers.google.com/earth-engine/python_install
# =============================================================================

# Imports
import ee

# Initialize
ee.Initialize()

# =============================================================================
# Historical map of deforestation
# =============================================================================

# Region for Cameroon
regCMR = ee.Geometry.Rectangle(coords=[8.382218, 1.654666,
                                       16.192148, 13.083333])

# Hansen map
gfcImage = ee.Image('UMD/hansen/global_forest_change_2015').clip(regCMR)
# print(gfcImage.getInfo())

# Tree cover, loss, and gain
treecover = gfcImage.select(['treecover2000'])
loss = gfcImage.select(['loss'])
gain = gfcImage.select(['gain'])
lossyear = gfcImage.select(['lossyear'])

# Computing forest in 2000
forest = treecover.gte(50)

# Export Asset
exportAsset = ee.batch.Export.image.toAsset(forest,
                                            maxPixels=1500000000,
                                            description='expforCameroon',
                                            assetId='users/ghislainv/deforestprob/forestCameroon')
exportAsset.start()

# =============================================================================
# End of defor.py
# =============================================================================
