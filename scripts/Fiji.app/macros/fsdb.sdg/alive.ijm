IMG=getArgument();
LOGDIR=getDirectory("imagej")+"logs/";
File.makeDirectory(LOGDIR);
LOG=LOGDIR+"alive.log";
File.append("alive", LOG);
print("alive");
print(getDirectory("home"));
print(getInfo("os.name"));

if ( IMG != ""){
	//run("Bio-Formats Importer", "open=/DATA/tps/storage/imports/Fabrice/Bille5_Water_1-51_ZDrive-secData/Bille5_Water_1-51_ZDrive.nd2");
	//run("Bio-Formats Importer", "open=/mnt/c/Users/teforadmin/sandbox/Bille5_Water_1-51_ZDrive.nd2");  
	run("Bio-Formats Importer", "open="+IMG); 
	File.append(getTitle(), LOG);
	File.append("still alive", LOG);
}
print("EXIT");
//eval("script", "System.exit(0);");
run("Quit");