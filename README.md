# Analysis of CD 27

This repo contains data, code and analyis supporting the Texas Tribune's redistricting project on Congressional Districit 27.

All the raw data is located in the data directory. All the edits that we made to the files are in the edits directory. All the topojson files for the maps are in the output directory.

The analysis files are within the shell directory. Here's a quick run through of what's in each:

1) process.sh: We downloaded shapefiles of all of Texas's congressional districts going back to 1982 -- the year CD-27 was created -- from the [Texas Legislative Council](http://www.tlc.state.tx.us/redist/data/data.html). This bash file simplifies those and turns them into topojoson files. It does the same for the county shapes, only we pull out just Nueces for them.

2) process-tracts.sh: This first pulls out CD-27 from the 2010 and 2012. It then finds all of the tracts that intersect with CD-27 in those years and merges Hispanic data into those shapefiles. Finally it converts to topojson for use with D3. These are used in the maps with the Hispanic population overlays. Tracts are made available by the [U.S. Census](https://factfinder.census.gov/faces/nav/jsf/pages/index.xhtml).

3) process-results.sh: This takes voting district data for 2008, 2010, 2012 and 2014 and merges it with voting district shapefiles. It then does some math to decide which party won the voting district, depending on who got the most votes. Finally, it converts to topojson. The data is from the [Texas Legislative Council](http://www.tlc.state.tx.us/redist/data/data.html).