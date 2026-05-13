//fsdb-rev-date: 260109

if (getArgument() == "") {
	outSuff=".wc";
} else {
	outSuff=getArgument();
}
	title=getTitle();
if(indexOf(title, ".") == -1) {
	ft="";
	bn=title;
} else {
	ft=replace(title, ".*\\.", "\\.");
	//print(suff);
	bn=replace(title, ft, "");
	//print(bn);
}

dbgName="writeContrast";
dbg=1; // debugging; active, when greater than 0
interactive=0;
ic=0;
if (dbg > 0) { print("::"+dbgName); }
fs=File.separator;

//myPath=getInfo("macro.filepath");
myPath=getDirectory("current");
print(myPath);
pArr=split(myPath, "/");
for (i = 0; i < lengthOf(pArr); i++) {
	if (matches(pArr[i], "fsdb..") == 1) {
		FSDBVERSION=pArr[i];
		FSDBDIR=replace(myPath, FSDBVERSION+"/.*", FSDBVERSION);
	} else {
		FSDBDIR=myPath+"/../../../";
	}
}
FSDBDIR=replace(myPath, FSDBVERSION+"/.*", FSDBVERSION);
print(FSDBDIR);

if (dbg > 0) { print(dbgName+": A"); }
COREMACROS=FSDBDIR+"/fsdb-core/macros/fsdb.core/";
INITLOG_FMAC=COREMACROS+"/fsdb.core.initLOG.ijm";
DEBUG_FMAC=COREMACROS+"/fsdb.core.logger.ijm";

// prepare parameters for logging
LOG=runMacro(INITLOG_FMAC, dbgName);

function debugger(str, LOG){
	if (dbg > 0){
		str=dbgName+dbg+": "+str+" "+LOG;
		runMacro(DEBUG_FMAC, str);
		dbg++;
	}
}

debugger("start", LOG);
if (interactive > 0 ) {waitForUser(dbgName+" "+ic); ic++;}
//==== fsdb-end ====

getDimensions(width, height, channels, slices, frames);
// set label color 
if (bitDepth == 16){
	setColor(floor(4095/4*3));
} else {
	setColor(floor(255/4*3));
}
//set text positioning to left
setJustification("left");
// font set to 2/100 of image height
fontSize=2*(height/100);
// set 10 as minimum font size	
if (fontSize < 10 ){
	fontSize=10;
}
setFont("SansSerif", fontSize);
for (channel=1; channel<=channels; channel++){
	if (is("composite")) {
		Stack.setChannel(channel);
	}
	getMinAndMax(min, max);
	//print(toString(channel)+" "+toString(floor(min))+" "+toString(floor(max)));
	drawString("contrast:", fontSize, height-((1+channels)*fontSize));
	drawString(min+" - "+max, fontSize, height-(channel*fontSize));
}
// append application-specific suffix
if(indexOf(title, outSuff) == -1) {
	newName=bn+outSuff;
	debugger(newName, LOG);
	rename(newName);
}

debugger("end", LOG);