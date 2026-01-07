//fsdb-rev-date: 240801
arg=getArgument();

getDimensions(width, height, channels, slices, frames);
// set color 
if (bitDepth == 16){
	setColor(floor(4095/4*3));
} else {
	setColor(floor(255/4*3));
}
//set text positioning to left
setJustification("left");
if (arg == "") {
// font set to 2/100 of image height
	fontSize=height/100;
// set 10 as minimum font size	
	if (fontSize < 10 ){
		fontSize=10;
	}
}else{
	fontSize=24;
}
setFont("SansSerif", fontSize);
for (channel=1; channel<=channels; channel++){
	if (is("composite")) {
		Stack.setChannel(channel);
	}
	getMinAndMax(min, max);
	//print(toString(channel)+" "+toString(floor(min))+" "+toString(floor(max)));
	drawString("contrast:", fontSize, height-((1+channels)*fontSize));
	drawString(min+" - "+max, fontSize, height-(channel*fontSize));
}

