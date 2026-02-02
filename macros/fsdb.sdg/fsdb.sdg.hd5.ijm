param=getArgument();
fs=File.separator;
dbg=1;// debugging; active, when greater that 0
dbgName="hd5Gen";

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
selectImage(IID);
close("\\Others");

// prepare parameters for logging
INITLOG_FMAC=call("ij.Prefs.get", "fsdb.core.fmac.initlog", COREMACROS+fs+"fsdb.core.initLOG.ijm");
LOG=runMacro(INITLOG_FMAC, dbgName);
debugger("start", LOG);

// get metadata of image
getDimensions(width, height, channels, slices, frames);
getVoxelSize(vwidth, vheight, depth, vunit);
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
wc_suff=call("ij.Prefs.get", "fsdb.sdg.iasuff.writecontrast", ".wc");
cl_suff=call("ij.Prefs.get", "fsdb.sdg.ipsuff.clahe", ".cl");
cc_suff=call("ij.Prefs.get", "fsdb.sdg.ppsuff.colcorr", "-cc");
// define label for output type
var suff=call("ij.Prefs.get", "fsdb.sdg.suff.hd5", ".bdv");
// define output file type
ft=call("ij.Prefs.get", "fsdb.sdg.ft.hd5", ".h5");

title=call("ij.Prefs.get", "fsdb.sdg.stack.title", getTitle());
//call("ij.Prefs.set", "fsdb.sdg.stack.title", getTitle());
debugger(title, LOG);
tmp=split(title,".");
bn=tmp[0];

// define output file
if (File.isDirectory(param)){
	dir=param;
	makeDir(dir);
} else {
	dir=call("ij.Prefs.get", "fsdb.sdg.stack.dir", replace(getDirectory("image"), File.separator, "/")); 
}
call("ij.Prefs.set", "fsdb.sdg.stack.dir", dir);
outFile=dir+fs+bn+".xml";
debugger(bn+suff+": "+IID, LOG);

selectImage(IID);
if (slices > 1) {
// write pyramidal hdf5 file and associated xml
	run("Export Current Image as XML/HDF5", "  subsampling_factors=[{ {1,1,1}, {2,2,2}, {4,4,4}, {8,8,8} }] hdf5_chunk_sizes=[{ {16,16,16}, {16,16,16}, {16,16,16}, {16,16,16} }] value_range=[Use values specified below] min=0 max=65535 timepoints_per_partition=0 setups_per_partition=0 use_deflate_compression export_path="+outFile);
}

// clean up for further steps/macros
selectImage(IID);
close("\\Others");
call("java.lang.System.gc");
call("java.lang.System.gc");
debugger(suff+": end", LOG);

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


