run("Select None");
outputDir=getDirectory("image");
IID=getImageID();
title=getTitle();
titleParts=split(title, ".");
bn=titleParts[0]
for (i = 1; i<(lengthOf(titleParts)-1); i++) {
	bn+="."+titleParts[i];
}

selectImage(IID);
if (bitDepth() == "24") {
	run("Split Channels");
	run("Merge Channels...", "c1=["+title+" (red)] c2=["+title+" (green)] c3=["+title+" (blue)] create");
	rename(title);
}

run("Split Channels");
n=nImages();
for (i=1; i<=n; i++) {
	ch=replace(getTitle(), title, "");
	run("Nrrd ... ", "nrrd="+outputDir+"/"+ch+bn+".nrrd");
	close();
}
// run("Quit");
