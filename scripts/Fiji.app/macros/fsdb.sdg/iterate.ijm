/* This macro iterates 
 *  As argument it currently accepts 
 *  - the absolute path to a single image file or
 *  - the absolute path to a directory containing image files
*/

param=getArgument();
mode="";
print(param);

//TODO: integrate fsdb-vars

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

if (getInfo("os.name") == "Linux" ) {
	MACRODIR=exec("bash", "-c", "dirname $(realpath $(find . -name iterate.ijm))");
} else {
	MACRODIR="K:/stageTheo/";
}


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
	run("Bio-Formats Windowless Importer", "open="+path);
// Bioformats sometimes assigns the complete path as title. This causes trouble downstream. 
// Therefore we strip the path off the image and rename it with its filename only.
	print(getTitle());
	tmp=split(getTitle(), "/");
	title=tmp[lengthOf(tmp)-1];
	rename(title);
// make non-isotropic images isotropic 
	runMacro(MACRODIR+"/interpolateBetweenSlices.ijm");
// crop image
// - to the specimen (and rotate its head to the left)
// - to the head				
	runMacro(MACRODIR+"/crop.ijm");
// Clean up and liberate the memory	
	run("Close All");
	run("Collect Garbage");
	run("Collect Garbage");
	run("Collect Garbage");
}
