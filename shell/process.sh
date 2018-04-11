#!/bin/bash
# source `which virtualenvwrapper.sh`
source globals.sh

# We can use parameters to skip certain tasks within this script
# Example:
# sh process.sh --skip=convert

# Pull out parameters and make them an array
# Called params_array
params=$1
prefix="--skip="
param=${params#$prefix}
IFS=', ' read -r -a params_array <<< ${param}

# Simplify and convert to topojson
if [[ " ${params_array[*]} " != *" districts "* ]]; then
  FILES=('/1982/Congress_82' '/1984-90/Congress_84_90' '/1992-96/Congress_92_96P' '/1996-2000/PlanC0746_96_00_Elections' '/2002-election/PlanC1151_02_Election' '/2004-election/PlanC1374_04_Election' '/2006-election/PlanC1440_06_10_Elections' '/2012-current/PLANC235')

  for file in "${FILES[@]}"
  do
    SHP="../data/historical-districts$file.shp"
    SHP_SIMPLIFIED="../data/historical-districts-simplified$file.shp"
    TOPOJSON="../output/map$file.topojson"
    SIMPLIFY='5%'

    echo "Simplify and create shapefile"
    mapshaper $SHP -simplify dp $SIMPLIFY -proj wgs84 -o format=shapefile $SHP_SIMPLIFIED

    echo "Simplify and create topojson"
    mapshaper $SHP -simplify dp $SIMPLIFY -proj wgs84 -o format=topojson $TOPOJSON
  done
fi

# Simplify, convert to topojson and pull out Nueces County
if [[ " ${params_array[*]} " != *" counties "* ]]; then
  FP="/2010_Census_Counties"
  SHP="../data/counties$FP.shp"
  SHP_SIMPLIFIED="../data/counties-simplified$FP.shp"
  TOPOJSON="../output/map/counties.topojson"
  TOPOJSON_NUECES="../output/map/nueces.topojson"
  SIMPLIFY='5%'

  echo "Simplify and create shapefile"
  mapshaper $SHP -simplify dp $SIMPLIFY -proj wgs84 -o format=shapefile $SHP_SIMPLIFIED

  echo "Simplify and create topojson"
  mapshaper $SHP -simplify dp $SIMPLIFY -proj wgs84 -o format=topojson $TOPOJSON

  echo "Pull out Nueces county"
  mapshaper $SHP -filter '"NUECES".indexOf(FENAME) > -1' -simplify dp $SIMPLIFY -proj wgs84 -o format=topojson $TOPOJSON_NUECES
fi