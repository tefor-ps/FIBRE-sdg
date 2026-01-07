dbg=1;// debugging; actvie, when greater that 0
dbgName="scalebar";

getDimensions(width, height, channels, slices, frames);
getVoxelSize(vwidth, vheight, vdepth, unit);
//width=call("ij.Prefs.get", "fsdb.sdg.stack.width", "");
//vwidth=call("ij.Prefs.get", "fsdb.sdg.voxel.width", "");
if ( width+vwidth > 400 ){
	w=100;
 } else if ( width+vwidth > 100 ) {
	w=10;
} else { 
	w=1;
}
//run("Scale Bar...", "width="+w+" height=4 font=14 color=White background=None location=[Lower Right] bold overlay");
run("Scale Bar...", "width="+w+" height=4 font=14 color=White background=None location=[Lower Right] bold overlay label");
