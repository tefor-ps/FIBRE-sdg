// Recursively lists the files in a user-specified directory.
// Open a file on the list by double clicking on it.
// --> https://imagej.net/ij/macros/ListFilesRecursively.txt

dir = getDirectory("Choose a Directory ");
//MACRODIR="E:/stageTheo/fsdb-module-registration/registration/scripts/Fiji.app/macros/fsdb.registration/";
if (getInfo("os.name") == "Linux" ) {
	MACRODIR="/DATA/stageTheo/";
	//MACRODIR="E:/stageTheo/fsdb-module-registration/registration/scripts/Fiji.app/macros/fsdb.registration/";
} else {
	MACRODIR="K:/stageTheo/";
}
count = 1;
print("\\Clear");
selectWindow("Log");
listFiles(dir);
print("done.");
//run("Quit");

function listFiles(dir) {
	list = getFileList(dir);
	for (i=0; i<list.length; i++) {
		if (endsWith(list[i], "/")) {
			listFiles(""+dir+list[i]);
		} else {
			if (endsWith(list[i], "merge.nd2")) {
				print((count++)+": "+dir+list[i]);
	//			open(dir+list[i]);
				run("Bio-Formats Windowless Importer", "open="+dir+list[i]);
				print(getTitle());
				tmp=split(getTitle(), "/");
				title=tmp[lengthOf(tmp)-1];
				rename(title);
				//waitForUser;
				runMacro(MACRODIR+"interpolateBetweenSlices.ijm");
				runMacro(MACRODIR+"crop.ijm");
				run("Close All");
				run("Collect Garbage");
				run("Collect Garbage");
				run("Collect Garbage");
			}
		}
	}
}
