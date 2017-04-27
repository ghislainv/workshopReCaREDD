#!/usr/bin/env python

# =============================================================================
#
# Forest-cover change from Global Forest Change data with Python and GEE API
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

# Region for Cameroon
coords = [410000, 165000, 1325000, 1500000]  # xmin, ymin, xmax, ymax
region = ee.Geometry.Rectangle(coords, proj='EPSG:32632', geodesic=False)
# Tree cover percentage threshold to define forest
perc = 50

# Hansen map
gfc = ee.Image('UMD/hansen/global_forest_change_2015').clip(region)

# Tree cover, loss, and gain
treecover = gfc.select(['treecover2000'])
lossyear = gfc.select(['lossyear'])

# Forest in 2000
forest2000 = treecover.gte(perc)

# Deforestation
loss00_05 = lossyear.gte(1).And(lossyear.lte(5))
loss00_10 = lossyear.gte(1).And(lossyear.lte(10))

# Forest
forest2005 = forest2000.where(loss00_05.eq(1), 0)
forest2010 = forest2000.where(loss00_10.eq(1), 0)
forest2014 = forest2000.where(lossyear.gte(1), 0)

# Forest-cover change 2005-2010
fcc05_10 = forest2005.where(loss00_10.eq(1).And(forest2005.eq(1)), 2)

# maxPixels
maxPix = 10e10

# Export fcc to drive
# param_fcc = {
#     'region': region.getInfo()['coordinates'],
#     'scale': 30,
#     'maxPixels': maxPix,
#     'crs': 'EPSG:32632',
#     'driveFolder': 'workshopReCaREDD',
#     'driveFileNamePrefix': 'fcc05_10_cameroon'}
# task = ee.batch.Export.image(image=fcc05_10,
#                              description='export_fcc',
#                              config=param_fcc)
# task.start()

task = ee.batch.Export.image.toDrive(image=fcc05_10,
                                     description='export_fcc',
                                     region=region.getInfo()['coordinates'],
                                     scale=30,
                                     maxPixels=maxPix,
                                     crs='EPSG:32632',
                                     folder='workshopReCaREDD',
                                     fileNamePrefix='fcc05_10_cameroon')
task.start()

# Export forest to drive
param_forest = {
    'region': region,
    'scale': 30,
    'maxPixels': maxPix,
    'crs': 'EPSG:32632',
    'drivefolder': 'workshopReCaREDD',
    'driveFileNamePrefix': 'forest2014_cameroon'
}
ee.batch.Export.image(image=forest2014,
                      description='export_forest',
                      config=param_forest)

# Export loss00_05 to drive
param_loss = {
    'region': region,
    'scale': 30,
    'maxPixels': maxPix,
    'crs': 'EPSG:32632',
    'drivefolder': 'workshopReCaREDD',
    'driveFileNamePrefix': 'loss00_05_cameroon'
}
ee.batch.Export.image(image=loss00_05,
                      description='export_loss',
                      config=param_loss)

# =============================================================================
# End
# =============================================================================
