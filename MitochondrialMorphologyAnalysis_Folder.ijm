/*
Advanced Optical Microscopy Unit
Centres Científics i Tecnològics. Campus Clínic
Universitat de Barcelona
C/ Casanova 143
Barcelona 08036 
Tel: 34 934037159
Fax: 34 934024484
mail: confomed@ccit.ub.edu
------------------------------------------------
Anna Bosch, Maria Calvo
------------------------------------------------
Name of Macro: Macro_Mitochondria_Folder

Date: 25/05/18

Objective: the macro segments cells (with Cell Mask staining) and mitochondria, and measures:
			- cell area 
			- mitochondria area and mitochondria morphology cell by cell

Input: The macro asks to choose a folder with images to analyze

Output: The macro creates a "Results" folder in the same folder of the images.
		The macro saves automatically 
			-the ROIs of each image 
			-a results file with the results of all images in the folder
			-a summary file with all summaries of all images in the folder

Changes from last version: 

Install macro: The first time: Create a "PersonalMacros" folder in your ImageJ's plugins folder. Copy this macro file, and place it in the "PersonalMacros" folder.
*/
//Select Images Folder
dir = getDirectory("Choose images folder");
list=getFileList(dir);
//Create a Results Folder inside the Images Folder
dirRes=dir+"Results"+File.separator;
File.makeDirectory(dirRes);
roiManager("reset"); //to delete previous ROIs
//Start
for(i=0;i<list.length;i=i+2){
	open(dir+list[i]);
	open(dir+list[i+1]);//we open two channels
	//automatic selection of channels
	for (j=1; j<=nImages; j++) {
			selectImage(j);
			t=getTitle();
			if (matches(t,".*C=2.*")==1){  // .*  to accept any value
			cellMask=getImageID();
		}
			if (matches(t,".*C=1.*")==1){  
			mito=getImageID();
		}
	}
	//Rename original images
	selectImage(cellMask);
	rename("CellMaskOriginal");
	selectImage(mito);
	rename("MitoOriginal");
	//Part 1: Cell Mask segmentation***************************************
	cellSegmentation();
	//Part 2: Mitochondria segmentation************************************
	selectWindow("MitoOriginal");
	mitoSegmentation();
	//Part 3: Analysis (Measurements cell by cell)*************************
	analysis();
	//Part 4: Visualization************************************************
	visualization();
	//Save ROIs
	selectWindow("ROI Manager");
	roiManager("Deselect");
	roiManager("Save", dirRes+t+"-RoiSet.zip");
	//close images and Delete ROI Manager
	run("Close All");
	roiManager("reset");
}
//Save Results
saveResults(dirRes);
//End
waitForUser("Macro has finished", "Close all windows?");
closeImagesAndWindows();
//
//
//FUNCTIONS
function cellSegmentation(){
	selectWindow("CellMaskOriginal");
	run("Gamma...", "value=0.40");
	run("Duplicate...", "title=CellMask");
	run("Mean...", "radius=7");
	//
	selectWindow("MitoOriginal");
	run("Duplicate...", "title=MitoMsk");
	run("Gamma...", "value=0.40");
	run("Mean...", "radius=20");
	imageCalculator("Add", "CellMask","MitoMsk");
	rename("TotMask");
	//
	run("Find Maxima...", "noise=60 output=[Segmented Particles]");
	
	count=roiManager("Count");imageCalculator("Min create", "TotMask","TotMask Segmented");
	selectWindow("Result of TotMask");
	setAutoThreshold("Huang dark");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Analyze Particles...", "size=10000-Infinity pixel show=Masks add");
	for(j=0;j<count;j++){
		roiManager("Select", j);
		roiManager("Rename", "Cell_"+j+1);
	}
}
function mitoSegmentation(){
	run("Duplicate...", "title=[Mito Flat Field] duplicate range=[]");
	run("Median...", "radius=7 stack");
	imageCalculator("Subtract create stack", "MitoOriginal","Mito Flat Field");
	run("Median...", "radius=1 stack");
	setAutoThreshold("Triangle dark");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	//Delete signal out of the segmented cells:
	imageCalculator("AND", "Result of MitoOriginal","Mask of Result of TotMask");
	mitoMask=getImageID();
	//we create a new mask to obtain particles >4px:
	run("Analyze Particles...", "size=4-Infinity pixel show=Masks");
	rename("Mito Mask");
	//close unnecessary images
	selectImage(mitoMask);
	close();	
	selectWindow("Mito Flat Field");
	close();
	selectWindow("Mask of Result of TotMask");
	close();
	//We create a selection of all mito and we add it to ROI Manager:
	selectWindow("Mito Mask");
	run("Create Selection");
	roiManager("Add");
	//Rename mitochondria ROI
	count=roiManager("Count");
	roiManager("Select", count-1);
	roiManager("Rename", "MitoSelection");
}	
function analysis(){
	run("Set Measurements...", "area perimeter shape display redirect=None decimal=5");
	selectWindow("Mito Mask");
	rename(t);//to obtain the original name into the results table
	count=roiManager("Count");
	for(k=0;k<count-1;k++){
		roiManager("Select", k);
		roiManager("Measure");
		row=nResults();
		setResult("Label", row-1, t+" / Total Cell "+k+1);
		run("Analyze Particles...", "size=4-Infinity pixel show=Nothing display summarize");
	}
	//Organize Results & Summary tables
	IJ.renameResults("Results","ResultsWindow");
	IJ.renameResults("Summary","Results");
	rowSummary=nResults();
	count=count-1;//ROIs except mitochondria ROI
	ini=rowSummary-count;
	iter=count;
	cell=1;
	do{
		setResult("Slice", ini, t+" / Summary of Cell "+cell); 
		ini++;
		cell++;
		iter--;
	}while(iter>0);
	IJ.renameResults("Results","Summary");
	IJ.renameResults("ResultsWindow","Results");
}
function visualization(){
	//Visualize Original Merged Image with all ROIs
	selectWindow("CellMaskOriginal");
	run("Merge Channels...", "c1=CellMaskOriginal c2=MitoOriginal keep ignore");
	roiManager("Show All without labels");
	waitForUser("Check Results", "Click OK to continue");
}
function saveResults(dir){
	selectWindow("Results");
	saveAs("measurements", dir+"Results.txt");
	selectWindow("Summary");
	saveAs("measurements", dir+"Summary.txt");
}
function closeImagesAndWindows(){
	run("Close All");
	if(isOpen("Results")){
		selectWindow("Results");
		run("Close");
	}
	if(isOpen("ROI Manager")){
		selectWindow("ROI Manager");
		run("Close");
	}
	if(isOpen("Threshold")){
		selectWindow("Threshold");
		run("Close");
	}
	if(isOpen("Summary.txt")){
		selectWindow("Summary.txt");
		run("Close");
	}
	if(isOpen("B&C")){
		selectWindow("B&C");
		run("Close");
	}
	if(isOpen("Log")){
		selectWindow("Log");
		run("Close");
	}
}

