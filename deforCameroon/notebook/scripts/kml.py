import os
from osgeo import ogr, osr
from mpl_toolkits.basemap import Basemap

kml = "borders.kml"
os.system("ogr2ogr ")
drv = ogr.GetDriverByName("KML")
ds = drv.Open(kml)
lyr = ds.GetLayer()

# Use VectorPlotter
vp = VectorPlotter(True)
vp.plot(kml)
vp.draw()

# Print srs
print(lyr.GetSpatialRef())

# Plot
