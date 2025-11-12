IMG=getArgument();
LOGDIR=getDirectory("imagej")+"logs/";
print(LOGDIR);
File.makeDirectory(LOGDIR);
LOG=LOGDIR+"alive.log";
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

File.append("alive "+ts, LOG);
print("alive");
print(getDirectory("home"));
print(getInfo("os.name"));
if ( IMG != "") {
    //run("Bio-Formats Importer", "open=/DATA/tps/storage/imports/Fabrice/Bille5_Water_1-51_ZDrive-secData/Bille5_Water_1-51_ZDrive.nd2");
    //run("Bio-Formats Importer", "open=/mnt/c/Users/teforadmin/sandbox/Bille5_Water_1-51_ZDrive.nd2");  
    run("Bio-Formats Importer", "open="+IMG); 
    File.append(getTitle(), LOG);
    File.append("still alive", LOG);
}
print("EXIT");
//eval("script", "System.exit(0);");
run("Quit");