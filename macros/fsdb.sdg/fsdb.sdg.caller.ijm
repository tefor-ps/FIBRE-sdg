
if( nImages == 0 ) {
	run("Bio-Formats Importer", "open=/DATA/tps/labdata/imports/Dorian/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge.nd2 autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
}
IID=getImageID();

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.correctColors.ijm", "-cc");
IID=getImageID();

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/crop.ijm", "-cc-head");
IID=getImageID();

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.optimizeContrast.ijm", ".oc");
IID=getImageID();

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.mip.ijm", "-cc-head.oc.mip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeContrast.ijm", "-cc-head.oc.wc.sb.mip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeScalebar.ijm", "-cc-head.oc.wc.sb.mip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.savePng.ijm", "/DATA/tps/labdata/imports/Dorian/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-secData/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-cc-head.oc.wc.sb.mip.png");

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.aip.ijm", "-cc-head.oc.aip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeContrast.ijm", "-cc-head.oc.wc.sb.aip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeScalebar.ijm", "-cc-head.oc.wc.sb.aip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.savePng.ijm", "/DATA/tps/labdata/imports/Dorian/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-secData/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-cc-head.oc.wc.sb.aip.png");

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.cs.ijm", "-cc-head.oc.cs.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeContrast.ijm", "-cc-head.oc.wc.sb.cs.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeScalebar.ijm", "-cc-head.oc.wc.sb.cs.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.savePng.ijm", "/DATA/tps/labdata/imports/Dorian/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-secData/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-cc-head.oc.wc.sb.cs.png");

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.setContrast.ijm", ".sc");
IID=getImageID();

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.mip.ijm", "-cc-head.sc.mip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeContrast.ijm", "-cc-head.sc.wc.sb.mip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeScalebar.ijm", "-cc-head.sc.wc.sb.mip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.savePng.ijm", "/DATA/tps/labdata/imports/Dorian/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-secData/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-cc-head.sc.wc.sb.mip.png");

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.aip.ijm", "-cc-head.sc.aip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeContrast.ijm", "-cc-head.sc.wc.sb.aip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeScalebar.ijm", "-cc-head.sc.wc.sb.aip.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.savePng.ijm", "/DATA/tps/labdata/imports/Dorian/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-secData/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-cc-head.sc.wc.sb.aip.png");

selectImage(IID);
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.cs.ijm", "-cc-head.sc.cs.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeContrast.ijm", "-cc-head.sc.wc.sb.cs.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.writeScalebar.ijm", "-cc-head.sc.wc.sb.cs.png");
runMacro("/home/teforadmin/tps/gitlab/fsdb25//fsdb-sdg/macros/fsdb.sdg/fsdb.sdg.savePng.ijm", "/DATA/tps/labdata/imports/Dorian/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-secData/230628DCa_3074e_5dpf_TCF-462-DR_1024_Nh_merge-cc-head.sc.wc.sb.cs.png");
