setAutoThreshold("Default dark no-reset");
getBiggestROI();


function getBiggestROI() { 
// function description

	if (roiManager("size") > 0) {
	roiManager("Select", 0);
	roiManager("Delete");
	roiManager("Delete");
	}
	
	run("Select None");
	run("Create Selection");
	run("ROI Manager...");
	
	roiManager("Add");
	
	roiManager("Select", 0);
	roiManager("Split");
	roiManager("Select", 0);
	roiManager("Delete");
	roiManager("Select", 0);
	roiManager("Show None");
	
	biggest=0;
	for (i = 0; i < roiManager("size"); i++) {
		roiManager("Select", i);
		getStatistics(area, mean, min, max, std, histogram);
		if (area > biggest) {
			biggest=area;
			winnerIndex=i;
		}
	}
	roiManager("Select", winnerIndex);
}
