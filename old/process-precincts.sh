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

# Global vars
YEARS=('2008' '2010' '2012' '2014')
SHP="VTDs"

# Simplify and convert to topojson
if [[ " ${params_array[*]} " != *" districts "* ]]; then
  cd ../data/election-results/

  for year in "${YEARS[@]}"
  do
    echo "Triming results for election year $FILE"
    FILE=${year}"_General_Election_Returns"
    FILE_RENAME=og_$FILE
    FILE_EDIT_1="a_${year}_results_trim"

    # Rename file because sql hates me
    mv $FILE.csv $FILE_RENAME.csv
    csvsql --query "select * FROM $FILE_RENAME WHERE Office='U.S. Rep 27'" $FILE_RENAME.csv > $FILE_EDIT_1.csv
  done

  cd ../../../
fi

if [[ " ${params_array[*]} " != *" votes "* ]]; then
  cd ../data/election-results/

  for year in "${YEARS[@]}"
  do
    echo "Split up results by party for election year ${year}"
    FILE_EDIT_1="a_${year}_results_trim"
    FILE_EDIT_2="b_${year}_results_parties"

    csvsql --query "select cntyvtd, SUM(Votes) as total_votes, SUM(case when Party='D' then Votes else 0 end) as dem_votes, SUM(case when Party='R' then Votes else 0 end) as rep_votes from $FILE_EDIT_1 GROUP BY cntyvtd" $FILE_EDIT_1.csv > $FILE_EDIT_2.csv
  done

  cd ../../../
fi

if [[ " ${params_array[*]} " != *" percent"* ]]; then
  cd ../data/election-results/

  for year in "${YEARS[@]}"
  do
    echo "Split up results by party for election year ${year}"
    FILE_EDIT_2="b_${year}_results_parties"
    FILE_EDIT_3="c_${year}_results_parties_perc"

    csvsql --query "select cntyvtd, total_votes, rep_votes, dem_votes, printf('%.0f', CAST(CAST(rep_votes AS float) / CAST(total_votes AS float) * 100 AS numeric(10,1))) as rep_perc, printf('%.0f', CAST(CAST(dem_votes AS float) / CAST(total_votes AS float) * 100 AS numeric(10,1))) as dem_perc from $FILE_EDIT_2" $FILE_EDIT_2.csv > $FILE_EDIT_3.csv
  done

  cd ../../../
fi


if [[ " ${params_array[*]} " != *" shapes "* ]]; then
  cd ../data/election-results/

  for year in "${YEARS[@]}"
  do
    echo "Merge election results with VTD shapefile for ${year}"
    FILE_EDIT_3="c_${year}_results_parties_perc"
    SHP_EDIT_1="a_${year}_results"

    ogr2ogr $SHP_EDIT_1.shp $SHP.shp -sql "select $SHP.*, $FILE_EDIT_3.* from $SHP left join '$FILE_EDIT_3.csv'.$FILE_EDIT_3 on $SHP.CNTYVTD = $FILE_EDIT_3.cntyvtd"
  done

  cd ../../../
fi

if [[ " ${params_array[*]} " != *" shapes-filter "* ]]; then
  cd ../data/election-results/

  # Make sure all the files are here
  # We'll move them to edits dir when done
  # (see bottom)
  cp ../../edits/election-results/* .

  for year in "${YEARS[@]}"
  do
    echo "Filter shapefiles for ${year}"
    SHP_EDIT_1="a_${year}_results"
    SHP_EDIT_2="b_${year}_results_filter"

    ogr2ogr $SHP_EDIT_2.shp $SHP_EDIT_1.shp -dialect sqlite -sql "select $SHP_EDIT_1.geometry, c_${year}_res as cntyvtd, c_${year}_r_1 as all_votes, c_${year}_r_2 as rep_votes, c_${year}_r_3 as dem_votes, c_${year}_r_4 as rep_perc, c_${year}_r_5 as dem_perc from $SHP_EDIT_1 where c_${year}_res != ''"
  done

  # Copy new files to edits dir
  cp a_* ../../edits/election-results
  cp b_* ../../edits/election-results
  cp c_* ../../edits/election-results
  rm a_*
  rm b_*
  rm c_*

  cd ../../../
fi


if [[ " ${params_array[*]} " != *" output "* ]]; then
  cd ../edits/election-results/

  for year in "${YEARS[@]}"
  do
    echo "Filter shapefiles for ${year}"
    SHP_EDIT_2="b_${year}_results_filter"
    OUTPUT_FILE="cd27_vtds_results_${year}"
    TOPOJSON="../../output/map/$OUTPUT_FILE"
    SIMPLIFY="2%"

    mapshaper $SHP_EDIT_2.shp -simplify dp $SIMPLIFY -proj wgs84   -o format=topojson $TOPOJSON.topojson
    cp $TOPOJSON.topojson ../../../redistricting-CD27/app/assets/data/$OUTPUT_FILE.topojson
  done

  cd ../../../
fi
