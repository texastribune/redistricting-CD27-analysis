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

VRT="raw.vrt"

# Pull out CD 27 in 2010 and 2012
if [[ " ${params_array[*]} " != *" districts "* ]]; then
  # Select District 27
  cd ../data/historical-districts-simplified/2006-election

  ogr2ogr cd27_2006_2010.shp ../../../shell/$VRT -sql "SELECT District FROM PlanC1440_06_10_Elections WHERE District='27'"

  # Copy newly created SHP
  # And remove files in old dir
  cp cd27* ../../cd27-census-tracts
  rm cd27*

  # Return to shell root
  cd ../../../shell

  # Select District 27
  cd ../data/historical-districts-simplified/2012-current
  ogr2ogr cd27_2012_current.shp ../../../shell/$VRT -sql "SELECT DISTRICT FROM PLANC235 WHERE DISTRICT='27'"

  # Copy newly created SHP
  # And remove files in old dir
  cp cd27* ../../cd27-census-tracts
  rm cd27*

  # Return to shell root
  cd ../../../shell
fi

# Pull out tracts that are in District 27 or overlap
if [[ " ${params_array[*]} " != *" tracts "* ]]; then
  cd ../data/cd27-census-tracts

  # Select our tracts by if they intersect with district
  echo "Year: 2010"
  ogr2ogr ../../edits/a_tracts_within_cd27_2010.shp ../../shell/$VRT -dialect sqlite -sql "SELECT * FROM tl_2010_48_tract10 a, cd27_2006_2010 b WHERE ST_Intersects(a.geometry, b.geometry)"
  
  echo "Year: 2012"
  ogr2ogr ../../edits/a_tracts_within_cd27_2012.shp ../../shell/$VRT -dialect sqlite -sql "SELECT * FROM tl_2012_48_tract a, cd27_2012_current b WHERE ST_Intersects(a.geometry, b.geometry)"

  cd ../../shell

fi

# Merge Hispanic population data with total population data
if [[ " ${params_array[*]} " != *" hispanic "* ]]; then
  FILE_ALL="DEC_10_SF1_P12"
  FILE_HISPANIC="DEC_10_SF1_P12H"
  FILE_COMBINED="DEC_10_SF1_P12_combined"
  OUTPUT="a_hispanic_pop_tracts"

  cd ../data/age-pop/

  echo "Add up total, hispanic pop"
  csvsql --query  "select $FILE_ALL.GEOid2, $FILE_ALL.GEOdisplaylabel, ($FILE_ALL.D007 + $FILE_ALL.D008 + $FILE_ALL.D009 + $FILE_ALL.D010 + $FILE_ALL.D011 + $FILE_ALL.D012 + $FILE_ALL.D013 + $FILE_ALL.D014 + $FILE_ALL.D015 + $FILE_ALL.D016 + $FILE_ALL.D017 + $FILE_ALL.D018 + $FILE_ALL.D019 + $FILE_ALL.D020 + $FILE_ALL.D021 + $FILE_ALL.D022 + $FILE_ALL.D023 + $FILE_ALL.D024 + $FILE_ALL.D025 + $FILE_ALL.D031 + $FILE_ALL.D032 + $FILE_ALL.D033 + $FILE_ALL.D034 + $FILE_ALL.D035 + $FILE_ALL.D036 + $FILE_ALL.D037 + $FILE_ALL.D038 + $FILE_ALL.D039 + $FILE_ALL.D040 + $FILE_ALL.D041 + $FILE_ALL.D042 + $FILE_ALL.D043 + $FILE_ALL.D044 + $FILE_ALL.D045 + $FILE_ALL.D046 + $FILE_ALL.D047 + $FILE_ALL.D048 + $FILE_ALL.D049) as total_over_18_pop, ($FILE_HISPANIC.D007 + $FILE_HISPANIC.D008 + $FILE_HISPANIC.D009 + $FILE_HISPANIC.D010 + $FILE_HISPANIC.D011 + $FILE_HISPANIC.D012 + $FILE_HISPANIC.D013 + $FILE_HISPANIC.D014 + $FILE_HISPANIC.D015 + $FILE_HISPANIC.D016 + $FILE_HISPANIC.D017 + $FILE_HISPANIC.D018 + $FILE_HISPANIC.D019 + $FILE_HISPANIC.D020 + $FILE_HISPANIC.D021 + $FILE_HISPANIC.D022 + $FILE_HISPANIC.D023 + $FILE_HISPANIC.D024 + $FILE_HISPANIC.D025 + $FILE_HISPANIC.D031 + $FILE_HISPANIC.D032 + $FILE_HISPANIC.D033 + $FILE_HISPANIC.D034 + $FILE_HISPANIC.D035 + $FILE_HISPANIC.D036 + $FILE_HISPANIC.D037 + $FILE_HISPANIC.D038 + $FILE_HISPANIC.D039 + $FILE_HISPANIC.D040 + $FILE_HISPANIC.D041 + $FILE_HISPANIC.D042 + $FILE_HISPANIC.D043 + $FILE_HISPANIC.D044 + $FILE_HISPANIC.D045 + $FILE_HISPANIC.D046 + $FILE_HISPANIC.D047 + $FILE_HISPANIC.D048 + $FILE_HISPANIC.D049) as hispanic_over_18_pop FROM $FILE_ALL LEFT JOIN $FILE_HISPANIC ON ($FILE_ALL.GEOid2 = $FILE_HISPANIC.GEOid2)" $FILE_ALL.csv $FILE_HISPANIC.csv > $FILE_COMBINED.csv

  echo "Figure out hispanic pop percent"
  csvsql --query  "select GEOid2, GEOdisplaylabel, printf('%.0f', CAST(CAST(hispanic_over_18_pop AS float) / CAST(total_over_18_pop AS float) * 100 AS numeric(10,1))) as hispanic_pop_perc FROM $FILE_COMBINED" $FILE_COMBINED.csv > $OUTPUT.csv

  cp $OUTPUT.csv ../../edits/$OUTPUT.csv

  cd ../../
fi

# Merge Census tracts shapefiles with Hispanic data
if [[ " ${params_array[*]} " != *" merge "* ]]; then
  # Copy over the files we're gonna merge
  cd ../edits

  # Merge for all of our years
  YEARS=("10" "12")

  for year in "${YEARS[@]}"
  do
    echo "Year: 20${year}"
    CSV="a_hispanic_pop_tracts"
    SHP="a_tracts_within_cd27_20${year}"
    if [ "${year}" == "10" ]; then
      SHP_GEOID="GEOID10"
    else
      SHP_GEOID="GEOID"
    fi

    ogr2ogr b_hispanic_20${year}_merge.shp ../shell/$VRT -sql "select ${SHP}.*, ${CSV}.* from ${SHP} left join '${CSV}.csv'.${CSV} on ${SHP}.${SHP_GEOID} = ${CSV}.GEOid2" 
  done

  cd ../shell
fi

# With our merged shapefiles, we'll select just the columns we want
if [[ " ${params_array[*]} " != *" filter "* ]]; then
  cd ../edits

  # Merge for all of our years
  YEARS=("10" "12")

  for year in "${YEARS[@]}"
  do
    echo "Year: 20${year}"
    SHP="b_hispanic_20${year}_merge"
    OUTPUT="c_hispanic_20${year}_merge_filter"

    ogr2ogr $OUTPUT.shp $SHP.shp -dialect sqlite -sql "select ${SHP}.geometry, a_hispan_1 as GEO_label, a_hispan_2 as hisp_perc from ${SHP}"
  done

  cd ../shell
fi

# Convert our merged shapefiles into topojson to use with D3
if [[ " ${params_array[*]} " != *" convert "* ]]; then
  # All of our years
  YEARS=("10" "12")

  for year in "${YEARS[@]}"
  do
    echo "Year: 20${year}"
    SHP="../edits/c_hispanic_20${year}_merge_filter"
    OUTPUT_FILE="cd27_hispanic_20${year}"
    TOPOJSON="../output/map/$OUTPUT_FILE"
    SIMPLIFY="2%"

    mapshaper $SHP.shp -simplify dp $SIMPLIFY -o format=topojson $TOPOJSON.topojson

    cp $TOPOJSON.topojson ../../redistricting-CD27/app/assets/data/$OUTPUT_FILE.topojson
  done
fi