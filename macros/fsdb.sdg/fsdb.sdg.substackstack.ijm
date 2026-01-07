param=getArgument();
print("\\Clear");
fs=File.separator;
dbg=1;// debugging; active, when greater that 0
dbgName="sssGen";

// get macro-directory from global variables or from imagej

//MACROSDIR=call("ij.Prefs.get", "fsdb.getVar.static.macrosdir", getDirectory("macros")); 
// windows screws up path when getDirectory("macros") is located in users home directory.
MACROSDIR=call("ij.Prefs.get", "fsdb.getVar.static.macrosdir", File.getDirectory(getInfo("ij.executable"))+"macros/");
// get directory of core function macros from global variable (or from here (hardcoded)
COREMACROS=call("ij.Prefs.get", "fsdb.core.dir.coremacros", MACROSDIR+fs+"fsdb.core");
// get all variables defined in the fsdb scripts.config
INITFSDB_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initfsdb", COREMACROS+fs+"fsdb.core.initFsdb.ijm");  
runMacro(INITFSDB_FMAC);
SECDATAMACROS=call("ij.Prefs.get", "fsdb.core.dir.secdatamacros", MACROSDIR+fs+"fsdb.sdg");

// get ImageID
IID=call("ij.Prefs.get", "fsdb.sdg.stack.id", getImageID());
call("ij.Prefs.set", "fsdb.sdg.stack.id", IID);
if(isOpen(IID) == 0){
	IID=getImageID();
}
// clean up
selectImage(IID);
close("\\Others");

// prepare parameters for logging
INITLOG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initlog", COREMACROS+fs+"fsdb.core.initLOG.ijm");
LOG=runMacro(INITLOG_FMAC, dbgName);
debugger("start", LOG);

// get metadata of image
getDimensions(width, height, channels, slices, frames);
getVoxelSize(vwidth, vheight, vdepth, vunit);
// get toggle values (by default 'on')
ia_tog=call("ij.Prefs.get", "fsdb.sdg.iatog.global", "1");
sc_tog=call("ij.Prefs.get", "fsdb.sdg.iptog.setcontrast", "1");
wc_tog=call("ij.Prefs.get", "fsdb.sdg.iatog.writecontrast", "1");
WRITESCALEBAR_IATOG=call("ij.Prefs.get", "fsdb.sdg.iatog.writescalebar", "1");

ip_tog=call("ij.Prefs.get", "fsdb.sdg.iptog.global", "1");
oc_tog=call("ij.Prefs.get", "fsdb.sdg.iptog.optimizecontrast", "1");
cl_tog=call("ij.Prefs.get", "fsdb.sdg.iptog.clahe", "1");

pp_tog=call("ij.Prefs.get", "fsdb.sdg.pptog.global", "1"); 
cc_tog=call("ij.Prefs.get", "fsdb.sdg.pptog.colcorr", "1");

// define globally used macros
CLAHE_IPMAC=call("ij.Prefs.get", "fsdb.sdg.mac.clahe", SECDATAMACROS+fs+"fsdb.sdg.clahe.ijm");
MAKEDIR_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.makedir", COREMACROS+fs+"fsdb.core.makeDirRecursively.ijm"); 
// define treatment-specific suffixes
WRITESCALEBAR_IASUFF=call("ij.Prefs.get", "fsdb.sdg.iasuff.writescalebar", ".sb");
SETCONTRAST_IPSUFF=call("ij.Prefs.get", "fsdb.sdg.ipsuff.setcontrast", ".sc");
OPTIMIZECONTRAST_IPSUFF=call("ij.Prefs.get", "fsdb.sdg.ipsuff.optimizecontrast", ".oc");
cl_ipsuff=call("ij.Prefs.get", "fsdb.sdg.ipsuff.clahe", ".cl");
wc_suff=call("ij.Prefs.get", "fsdb.sdg.iasuff.writecontrast", ".wc");
cc_suff=call("ij.Prefs.get", "fsdb.sdg.ppsuff.colcorr", "-cc");
//opt_suff=call("ij.Prefs.get", "fsdb.sdg.ipsuff.global", "opt"); //DEPRECATED

// define label for output type
var suff=call("ij.Prefs.get", "fsdb.sdg.suff.substack", ".sss");
// define output file type
ft=call("ij.Prefs.get", "fsdb.sdg.ft.substack", ".tif");

call("ij.Prefs.set", "fsdb.sdg.voxel.width", vwidth);
call("ij.Prefs.set", "fsdb.sdg.voxel.height", vheight);
call("ij.Prefs.set", "fsdb.sdg.voxel.depth", vdepth);
call("ij.Prefs.set", "fsdb.sdg.voxel.unit", vunit);

title=getTitle();
//title=call("ij.Prefs.get", "fsdb.sdg.stack.title", getTitle());
//call("ij.Prefs.set", "fsdb.sdg.stack.title", getTitle());
debugger(title, LOG);
tmp=split(title,".");
//suff=tmp[lengthOf(tmp)-1];
//bn=tmp[0];
//bn=replace(title, "."+suff, "");
bn=title;

// define output file
if (File.isDirectory(param)){
	dir=param;
	makeDir(dir);
} else {
	dir=call("ij.Prefs.get", "fsdb.sdg.stack.dir", replace(getDirectory("image"), File.separator, "/")); 
}
call("ij.Prefs.set", "fsdb.sdg.stack.dir", dir);
debugger(dir, LOG);
sdg_ext=call("ij.Prefs.get", "fsdb.sdg.ext.secdata", "-secData");
//outDir=dir+fs+bn+sdg_ext;
outDir=dir;
outBn=outDir+fs+bn;
debugger(bn+suff+": "+IID, LOG);

// create and store stacks of substacks of heavy data
// fix display
if(channels > 1 || bitDepth() == 24 ){
	if (is("composite") == 0) {
		run("Make Composite");
	}
}

// fix colors
correctColors();

// function calls

makeSubstack(IID, "xy");
// clean up for further steps
selectImage(IID);
	close("\\Others");
call("java.lang.System.gc");
call("java.lang.System.gc");

debugger("Reslicing", LOG);
run("Reslice [/]...", "output="+vwidth+" start=Left avoid");
YZID=getImageID();
makeSubstack(YZID, "yz");
// clean up for further steps
selectImage(IID);
	close("\\Others");
call("java.lang.System.gc");
call("java.lang.System.gc");

debugger("Reslicing", LOG);
//run("Reslice [/]...", "output="+vdepth+" start=Top flip avoid");
run("Reslice [/]...", "output="+vdepth+" start=Top avoid");
XZID=getImageID();
makeSubstack(XZID, "xz");
// clean up for further macros
selectImage(IID);
	close("\\Others");
call("java.lang.System.gc");
call("java.lang.System.gc");
debugger(suff+": end", LOG);

// function definitions

function makeSubstack(ID, ax) {
	debugger("makeSubstack", LOG);
	getDimensions(width, height, channels, slices, frames);
	debugger(toString(width)+" "+toString(height)+" "+toString(channels)+" "+toString(slices)+" "+toString(frames), LOG);
	getVoxelSize(vwidth, vheight, vdepth, unit);
	debugger(toString(vwidth)+" "+toString(vheight)+" "+toString(vdepth)+" "+toString(unit), LOG);
	if(channels >1){
		if (is("composite")) {
			Stack.setDisplayMode("composite");
		}
	}	
	tech=newArray("Max", "Average");
	sssuff=newArray("mx", "av");
	label=newArray("MAX", "AVG");
//	thicknesses=newArray(100, 50, 20, 10);
	thicknesses=newArray(100);
	for (t=0; t<lengthOf(tech); t++){
		selectImage(ID);
		close("\\Others");
		thickness=100;
		numOfSlices=floor(thickness/vdepth);
		debugger(toString(thickness)+" micron = "+toString(numOfSlices)+" slices.", LOG);
		debugger("start processing substacks", LOG);
	//	if (File.exists(dir+bn+".sss-"+ax+"."+sssuff[t]+"."+IJ.pad(thickness,3)+ft) < 1) {
			for (i=1;i<=slices; i+=numOfSlices){
//reset suffix for each substack				
				suff=call("ij.Prefs.get", "fsdb.sdg.suff.substack", ".sss");
				debugger(toString(i)+": "+tech[t], LOG);
				selectImage(ID);
				I=i+numOfSlices;
				debugger("i: "+i+", I: "+I+", slices: "+slices, LOG);
				selectImage(ID);
				if (slices < I){
					run("Make Substack...", "  slices="+i+"-"+slices);	
				} else {
					run("Make Substack...", "  slices="+i+"-"+I);
				}
// get imageID of substack (temporary image)
					TID=getImageID(); 
	// to prevent ending up with a single slide (which can not be processed as a 
	// (sub)stack) run the following only, if 'i' is lower than the number of slices				
				if( i < slices) {
// make maximum intensity projection of substack (ss-mip)
					run("Z Project...", "projection=["+tech[t]+" Intensity]");
				}
// If contrast enhancement is toggled on (globally)
				if (oc_tog == 1){
// ... apply more or less advanced contrast enhancement... 
					optimizeContrast();
				} else {	
// ... otherwise reset contrast of ss-mip.		
					setContrast();
				}
// write display values into image
				writeContrast();
// draw scalebar
				writeScalebar();
// convert to RGB
				run("RGB Color");
				wait(10);
				selectImage(TID);
//				close();
			}
// combine sub-stack-projections to stack
			if (oc_tog == 1){
				debugger("A",LOG);
				if (cl_tog ==1){
					debugger("Aa",LOG);
					labelString=cl_suff;
				} else {
					debugger("Ab",LOG);
					labelString=OPTIMIZECONTRAST_IPSUFF;
				}
//				labelString="Substack";
				run("Images to Stack", "name="+bn+"."+ax+suff+"."+sssuff[t]+"."+IJ.pad(thickness,3)+" title="+labelString+" use ");
			} else {
				debugger("B",LOG);
				run("Images to Stack", "name="+bn+"."+ax+suff+"."+sssuff[t]+"."+IJ.pad(thickness,3)+" title="+label[t]+"_ use ");
			}		
// save sack of substacks as tif
			saveAs("Tiff",   dir+fs+bn+"."+ax+suff+"."+sssuff[t]+"."+IJ.pad(thickness,3)+ft);
			run("AVI... ", "compression=JPEG frame=1 save="+dir+fs+bn+"."+ax+suff+"."+sssuff[t]+"."+IJ.pad(thickness,3)+".jpg.avi");
			run("AVI... ", "compression=PNG frame=1 save="+dir+fs+bn+"."+ax+suff+"."+sssuff[t]+"."+IJ.pad(thickness,3)+".png.avi");
			debugger("saved as "+bn+"."+ax+suff+"."+sssuff[t]+"."+IJ.pad(thickness,3)+ft, LOG);
			debugger("saved at "+dir, LOG);
			close(label[t]+"_*");
	}
}

function writeScalebar() {
	if ( ia_tog == 1 && WRITESCALEBAR_IATOG  == 1 ){
		WRITESCALEBAR_IAMAC=call("ij.Prefs.get", "fsdb.sdg.mac.writescalebar", SECDATAMACROS+fs+"fsdb.sdg.writeScalebar.ijm");
		debugger("writeScalebar: "+WRITESCALEBAR_IAMAC, LOG);
		runMacro(WRITESCALEBAR_IAMAC);
		suff=suff+WRITESCALEBAR_IASUFF;
	} else {
		debugger("writeScalebar toggled off", LOG);
	}
}

function setContrast() {
	if ( ip_tog == 1 && sc_tog == 1){
		SETCONTRAST_IPMAC=call("ij.Prefs.get", "fsdb.sdg.mac.setcontrast", SECDATAMACROS+fs+"fsdb.sdg.setContrast.ijm");
		debugger("setContrast: "+SETCONTRAST_IPMAC, LOG);
		runMacro(SETCONTRAST_IPMAC);
		suff=suff+SETCONTRAST_IPSUFF;
	} else {
		debugger("setContrast toggled off", LOG);
	}
}

function optimizeContrast() {
	if ( ip_tog == 1 && oc_tog == 1){
		OPTIMIZECONTRAST_IPMAC=call("ij.Prefs.get", "fsdb.sdg.mac.optimizecontrast", SECDATAMACROS+fs+"fsdb.sdg.optimizeContrast.ijm");
		CLAHE_IPMAC=call("ij.Prefs.get", "fsdb.sdg.mac.clahe", SECDATAMACROS+fs+"fsdb.sdg.clahe.ijm");
//		opt_suff=call("ij.Prefs.get", "fsdb.sdg.ipsuff.opt", "opt"); //DEPRECATED
		debugger("optimizeContrast: "+OPTIMIZECONTRAST_IPMAC, LOG);
//		suff=suff+opt_suff; //DEPRECATED
		if( cl_tog == 1) {
			runMacro(CLAHE_IPMAC);
			suff=suff+cl_suff;
		} else {
			suff=suff+OPTIMIZECONTRAST_IPSUFF;
		}
		runMacro(OPTIMIZECONTRAST_IPMAC);
	} else {
		debugger("optimizeContrast toggled off", LOG);
	}		
}

function writeContrast(){
	if ( ia_tog == 1 && wc_tog == 1){
		WRITECONTRAST_IAMAC=call("ij.Prefs.get", "fsdb.sdg.mac.writecontrast", SECDATAMACROS+fs+"fsdb.sdg.writeContrast.ijm");
		debugger("writeContrast: "+WRITECONTRAST_IAMAC, LOG);
		runMacro(WRITECONTRAST_IAMAC);
		suff=suff+wc_suff;
	} else {
		debugger("writeContrast toggled off", LOG);
	}
}

function correctColors(){
	if ( pp_tog == 1 && cc_tog == 1){
		COLCORR_IPMAC=call("ij.Prefs.get", "fsdb.sdg.mac.colcorr", SECDATAMACROS+fs+"fsdb.sdg.correctColors.ijm");
		cc_suff=call("ij.Prefs.get", "fsdb.sdg.ppsuff.colcorr", "-cc");
		debugger("correctColors: "+COLCORR_IPMAC, LOG);
		runMacro(COLCORR_IPMAC);
	//	suff=suff+cc_suff;
	} else {
		debugger("writeContrast toggled off", LOG);
	}	
}	

function makeDir(dir){
	debugger("makeDir: "+MAKEDIR_FMAC+" "+dir, LOG);
	runMacro(MAKEDIR_FMAC, dir);
}

function debugger(str, LOG){
	if (dbg > 0){
		DEBUG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.debug", COREMACROS+fs+"fsdb.core.logger.ijm");
		str=File.getName(dbgName)+dbg+": "+str+" "+LOG;
		runMacro(DEBUG_FMAC, str);
	}
	dbg++;
}
