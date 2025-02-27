/* This macro iterates 
 *  As argument it currently accepts 
 *  - the absolute path to a single image file or
 *  - the absolute path to a directory containing image files
*/

param=getArgument();
mode="";
print(param);

//TODO: integrate fsdb-vars
	LOGDIR=getDirectory("imagej")+"logs/";
	print(LOGDIR);
	File.makeDirectory(LOGDIR);
	LOG=LOGDIR+"/iterate.log";
	if (File.exists(LOG) == 0){
		f=File.open(LOG);
		File.close(f);
	}
	getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
	print(IJ.pad(substring(year,2,4),2), IJ.pad(month,2), IJ.pad(dayOfMonth,2), IJ.pad(hour,2), IJ.pad(minute,2), IJ.pad(second,2), IJ.pad(msec,2));
	y=toString(IJ.pad(substring(year,2,4),2));
	m=toString(IJ.pad(month,2));
	d=toString(IJ.pad(dayOfMonth,2));
	h=toString(IJ.pad(hour,2));
	M=toString(IJ.pad(minute,2)); 
	s=toString(IJ.pad(second,2));
	ts=y+m+d+"-"+h+M+s;
	print(ts);
	File.append(ts, LOG);


if (param == "") {
	dir = getDirectory("Choose a Directory ");
	mode="dir";
} else {
	if (File.isDirectory(param)) {
		dir=param;
		mode="dir";
	} else {
		if (File.exists(param)) {
			fp=param;
			mode="file";
		}
	}
}

	File.append(mode+" "+ts, LOG);
	File.append(getInfo("os.name"), LOG);

if (getInfo("os.name") == "Linux" ) {
	MACRODIR=exec("bash", "-c", "dirname $(realpath $(find . -name iterate.ijm))");
} else {
	MACRODIR="K:/stageTheo/";
}
print(MACRODIR);
File.append(MACRODIR, LOG);

count = 1;
print("\\Clear");
selectWindow("Log");
if (mode == "dir"){
	print("Input is a directory");
	listFiles(dir+"/");
}
if (mode == "file"){
	print("Input is a file");
	process(fp);
}
print("done.");
run("Quit");

function listFiles(dir) {
	File.append("listFiles", LOG);
// --> https://imagej.net/ij/macros/ListFilesRecursively.txt
	list = getFileList(dir);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			listFiles(""+dir+list[i]);
		} else {
			if (endsWith(list[i], "merge.nd2")) {
				print((count++)+": "+dir+list[i]);
				process(dir+list[i]);
			}
		}
	}
}

function process(path){
	File.append("process", LOG);
	run("Bio-Formats Windowless Importer", "open="+path);
	File.append("loaded "+getTitle(), LOG);
// Bioformats sometimes assigns the complete path as title. This causes trouble downstream. 
// Therefore we strip the path off the image and rename it with its filename only.
	print(getTitle());
	tmp=split(getTitle(), "/");
	title=tmp[lengthOf(tmp)-1];
	rename(title);
	File.append("renamed to "+getTitle(), LOG);
// make non-isotropic images isotropic 
	//runMacro(MACRODIR+"/interpolateBetweenSlices.ijm");
// crop image
// - to the specimen (and rotate its head to the left)
// - to the head
	File.append(MACRODIR+"/crop.ijm", LOG);
	runMacro(MACRODIR+"/crop.ijm");
// Clean up and liberate the memory	
	run("Close All");
	run("Collect Garbage");
	run("Collect Garbage");
	run("Collect Garbage");
}
