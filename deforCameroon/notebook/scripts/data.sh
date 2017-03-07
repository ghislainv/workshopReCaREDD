#!/usr/bin/bash

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ghislainv.github.io
# GDAL version    :2.1.2 (OGR enabled)
# license         :GPLv3
# ==============================================================================

# Make output directory
mkdir -p data_raw
cd data_raw

# Variables
continent="africa"
country="cameroon"
iso="CMR"
proj="EPSG:32632" # WGS84 / UTM zone 32N, see http://epsg.io 
extent="431451 184295 1301829 1452775" # xmin ymin xmax ymax
tiles_long="38-40" # see http://dwtkns.com/srtm/
tiles_lat="10-12"

# ===========================
# Borders, roads and town
# ===========================

# Message
echo "Borders, roads, towns and rivers from OSM\n"

# Download OSM data from Geofabrik
url="http://download.geofabrik.de/"$continent"/"$country"-latest.osm.pbf"
wget -O country.osm.pbf $url
osmconvert country.osm.pbf -o=country.o5m

# Country borders
osmfilter country.o5m --verbose --keep='boundary=administrative and admin_level=2' > borders.osm 
ogr2ogr -overwrite -skipfailures -f 'ESRI Shapefile' -progress \
        -sql "SELECT osm_id, name, admin_level FROM multipolygons WHERE admin_level='2'" \
        -lco ENCODING=UTF-8 borders.shp borders.osm

# Main roads
osmfilter country.o5m --keep='highway=motorway or highway=trunk or highway=*ary' > roads.osm
ogr2ogr -overwrite -skipfailures -f 'ESRI Shapefile' -progress \
        -sql 'SELECT osm_id, name, highway FROM lines WHERE highway IS NOT NULL' \
        -lco ENCODING=UTF-8 roads.shp roads.osm
# Main towns
osmfilter country.o5m --keep='place=city or place=town or place=village' > towns.osm
ogr2ogr -overwrite -skipfailures -f 'ESRI Shapefile' -progress \
        -sql 'SELECT osm_id, name, place FROM points WHERE place IS NOT NULL' \
        -lco ENCODING=UTF-8 towns.shp towns.osm
# Main rivers
osmfilter country.o5m --keep='waterway=river or waterway=canal' > rivers.osm
ogr2ogr -overwrite -skipfailures -f 'ESRI Shapefile' -progress \
        -sql 'SELECT osm_id, name, waterway FROM lines WHERE waterway IS NOT NULL' \
        -lco ENCODING=UTF-8 rivers.shp rivers.osm

# Rasterize after reprojection
# borders (only reprojection)
ogr2ogr -overwrite -s_srs EPSG:4326 -t_srs $proj -f 'ESRI Shapefile' \
        -lco ENCODING=UTF-8 borders_UTM.shp borders.shp
# Extent: ogrinfo borders_UTM.shp borders_UTM | grep Extent
# towns
ogr2ogr -overwrite -s_srs EPSG:4326 -t_srs $proj -f 'ESRI Shapefile' \
        -lco ENCODING=UTF-8 towns_UTM.shp towns.shp
gdal_rasterize -te $extent -tap -burn 1 \
               -co "COMPRESS=LZW" -co "PREDICTOR=2" -ot Byte \
               -a_nodata 255 \
               -tr 150 150 -l towns_UTM towns_UTM.shp towns.tif
# roads
ogr2ogr -overwrite -s_srs EPSG:4326 -t_srs $proj -f 'ESRI Shapefile' \
        -lco ENCODING=UTF-8 roads_UTM.shp roads.shp
gdal_rasterize -te $extent -tap -burn 1 \
               -co "COMPRESS=LZW" -co "PREDICTOR=2" -ot Byte \
               -a_nodata 255 \
               -tr 150 150 -l roads_UTM roads_UTM.shp roads.tif
# rivers
ogr2ogr -overwrite -s_srs EPSG:4326 -t_srs $proj -f 'ESRI Shapefile' \
        -lco ENCODING=UTF-8 rivers_UTM.shp rivers.shp
gdal_rasterize -te $extent -tap -burn 1 \
               -co "COMPRESS=LZW" -co "PREDICTOR=2" -ot Byte \
               -a_nodata 255 \
               -tr 150 150 -l rivers_UTM rivers_UTM.shp rivers.tif

# Convert to kml
ogr2ogr -f 'KML' borders.kml borders_UTM.shp
ogr2ogr -f 'KML' towns.kml towns_UTM.shp
ogr2ogr -f 'KML' roads.kml roads_UTM.shp
ogr2ogr -f 'KML' rivers.kml rivers_UTM.shp

# Compute distances
gdal_proximity.py roads.tif _dist_road.tif -co "COMPRESS=LZW" -co "PREDICTOR=2" \
                  -values 1 -ot UInt32 -distunits GEO
gdal_proximity.py towns.tif _dist_town.tif -co "COMPRESS=LZW" -co "PREDICTOR=2" \
                  -values 1 -ot UInt32 -distunits GEO
gdal_proximity.py rivers.tif _dist_river.tif -co "COMPRESS=LZW" -co "PREDICTOR=2" \
                  -values 1 -ot UInt32 -distunits GEO

# Add nodata
gdal_translate -a_nodata 4294967295 -co "COMPRESS=LZW" -co "PREDICTOR=2" _dist_road.tif dist_road.tif
gdal_translate -a_nodata 4294967295 -co "COMPRESS=LZW" -co "PREDICTOR=2" _dist_town.tif dist_town.tif
gdal_translate -a_nodata 4294967295 -co "COMPRESS=LZW" -co "PREDICTOR=2" _dist_river.tif dist_river.tif

# ===========================
# SRTM
# ===========================

# Message
echo "SRTM data from CGIAR-CSI\n"

# Download SRTM data from CSI CGIAR
url="http://srtm.csi.cgiar.org/SRT-ZIP/SRTM_V41/SRTM_Data_GeoTiff/srtm_["$tiles_long"]_["$tiles_lat"].zip"
#url="http://gis-lab.info/data/srtm-tif/srtm_["$tiles_long"]_["$tiles_lat"].zip"
curl -L $url -o 'SRTM_V41_#1_#2.zip'

# Unzip
for z in SRTM_*.zip; do
d=$(basename $z .zip)
mkdir $d && unzip $z -d $d
done

# Build vrt file
gdalbuildvrt srtm.vrt */*.tif

# Merge and reproject
gdalwarp -overwrite -t_srs $proj -te $extent -r bilinear \
         -co "COMPRESS=LZW" -co "PREDICTOR=2" \
         -tr 90 90 srtm.vrt altitude.tif

# Compute slope and aspect
gdaldem slope altitude.tif slope_.tif -co "COMPRESS=LZW" -co "PREDICTOR=2"
gdaldem aspect altitude.tif aspect_.tif -co "COMPRESS=LZW" -co "PREDICTOR=2"

# Convert to Int16
gdal_translate -ot Int16 -co "COMPRESS=LZW" -co "PREDICTOR=2" slope_.tif slope.tif
gdal_translate -ot Int16 -co "COMPRESS=LZW" -co "PREDICTOR=2" aspect_.tif aspect.tif

# ===========================
# SAPM
# ===========================

# Message
echo "Protected area network from Protected Planet\n"
# See protected planet: www.protectedplanet.net

# Download from Protected Planet
url="https://www.protectedplanet.net/downloads/WDPA_Mar2017_"$iso"?type=shapefile"
wget -O pa.zip $url
unzip pa.zip

# Reproject
input_file="WDPA_Mar2017_"$iso"-shapefile-polygons.shp"
ogr2ogr -overwrite -skipfailures -f 'ESRI Shapefile' -progress \
        -s_srs EPSG:4326 -t_srs $proj \
        -lco ENCODING=UTF-8 pa.shp $input_file

# Convert to kml
ogr2ogr -f 'KML' pa.kml pa.shp 

# Rasterize
gdal_rasterize -te $extent -tap -burn 1 \
               -co "COMPRESS=LZW" -co "PREDICTOR=2" \
               -init 0 \
               -a_nodata 255 \
               -ot Byte -tr 30 30 -l pa pa.shp pa.tif

# ===========================
# Forest
# ===========================

# Message
echo "Forest from Global Forest Watch\n"

# Download forest data from Google Drive directory
# Need the gdrive software: https://github.com/prasmussen/gdrive
gdrive download -f --recursive '0B4yCK7KmZr9rTENDaFd6LVJCbnM'  # workshopReCaREDD

# Change directory
cd workshopReCaREDD

# Compute distance to forest edge in 2005
gdal_proximity.py fcc05_10_cameroon.tif _dist_edge.tif -co "COMPRESS=LZW" -co "PREDICTOR=2" \
                  -values 0 -ot UInt32 -distunits GEO
gdal_translate -a_nodata 0 -co "COMPRESS=LZW" -co "PREDICTOR=2" _dist_edge.tif dist_edge.tif

# Create raster fcc05_10.tif with 1:for2010, 0:loss05_10
gdal_translate -a_nodata 99 -co "COMPRESS=LZW" -co "PREDICTOR=2" fcc05_10_cameroon.tif _fcc05_10.tif # Set nodata different from 255
gdal_calc.py --overwrite -A _fcc05_10.tif --outfile=fcc05_10.tif --type=Byte \
             --calc="255-254*(A==1)-255*(A==2)" --co "COMPRESS=LZW" --co "PREDICTOR=2" \
             --NoDataValue=255

# Compute distance to past deforestation (loss00_05)
# Create raster fcc00_05.tif  with 1:for2005, 0:loss00_05
gdal_translate -a_nodata 99 -co "COMPRESS=LZW" -co "PREDICTOR=2" loss00_05_cameroon.tif _loss00_05.tif
gdal_calc.py --overwrite -A _fcc05_10.tif -B _loss00_05.tif --outfile=fcc00_05.tif --type=Byte \
             --calc="255-254*(A>=1)*(B==0)-255*(A==0)*(B==1)" --co "COMPRESS=LZW" --co "PREDICTOR=2" \
             --NoDataValue=255
# Compute distance (with option -use_input_nodata YES, it is much more efficient)
gdal_proximity.py fcc00_05.tif _dist_defor.tif -co "COMPRESS=LZW" -co "PREDICTOR=2" \
                  -values 0 -ot UInt32 -distunits GEO -use_input_nodata YES
gdal_calc.py --overwrite -A _dist_defor.tif --outfile=dist_defor.tif --type=UInt32 \
             --calc="A*(A!=65535)" --co "COMPRESS=LZW" --co "PREDICTOR=2" \
             --NoDataValue=0

# Move files to data_raw
cp -t ../ fcc05_10.tif dist_defor.tif dist_edge.tif
cd ..
rm -R workshopReCaREDD

# ===========================
# Cleaning
# ===========================

# Message
echo "Cleaning directory\n"

# Create clean data directory
mkdir -p ../data
# Copy files
cp -t ../data fcc05_10.tif dist_*.tif *.kml altitude.tif slope.tif aspect.tif pa.tif
# Remove raw data directory
cd ..
rm -R data_raw

# End
