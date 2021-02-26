///////////////////////////////////////////////////////////////////////////
// Created by: Anthony J. Burand Jr.
// Date: 2/26/2021
// Copyright (c) 2021 Anthony J. Burand Jr.
// Please acknowledge use of this ImageJ macro in any publications.
// Contact Anthony Burand at aburand@mcw.edu regarding any questions.
// 
// Language: ImageJ !J1 Macro
// Summary: This macro makes measurements of fluorescent intensity inside
// cell or axon boundaries. Users should have 3 fluorescent channels: two
// for measurement and the third that contains a stain to mark cell/axon
// boundaries. Users will be blinded automatically to the filename. The
// software allows users to threshold each image and approve the generated
// ROIs.
//
// Input: This program is designed to work with .lif images (Leica),
// however it can easily be modified to worth with other file types.
// Currently, image must be in the following format: 3 channels (2
// channels you want to make measurements in, 1 channel that defines your
// cell/axion boundary - must be channel 3). This macro does not handle
// z-stacks so images must be z-projected prior. All images to be processed
// must be in one folder.
//
// Example dyes: Channel 1: IB4 (to stain for Gb3), Channel 2: LAMP1
// (to stain for lysosomes), Channel 3: NF200 (to mark myelinated axons)
//
// Output: Excel files (named the same as the orginal image). See example.
//  Channel  Area1    Mean1     Min1    Max1   IntDen1     RawIntDen1
//  1       51.364    25.357    0       255    1302.459    176715
//	2       51.364    215.226   0       255    11054.929   1499910
//  3       51.364    255       255     255    13097.892   1777095
// Ignore channel 3 as this is quantifying the created mask and the
// intensity values are meaningless. The macro measures the ROI area,
// the mean/min/max fluorescent intensity of each channel within the ROI,
// the integrated density, and the raw integrated density. Note that the
// integrated density (IntDen)/Area = Mean. Note that the number following
// the measurement name indicates what ROI the data was pulled from.
//
// Post processing: It is recommended that users manually measure several
// cells that are "negative" for the probe of interest (for channels 1/2).
// Calculate the mean and standard deviation and decide on a threshold that
// is a user determined number of standard deviations above the mean. In
// the excel results label cell A5 as "Threshold" and cells A6-A7 as
// "channel 1"/"channel 2". Enter your thresolds for the respective
// channels in cells C6-C7. Enter "Above threshold?" in cell A8 and 
// "channel 1"/"channel 2" in cells A9-A10. If you are just thresholding
// the mean fluorescent intensity, paste the formula =IF(C2>C6,1,0) into C9
// and =IF(C3>C7,1,0) into C10. Copy these cells and paste into the "Mean"
// columns for all the other ROIs (note a "1" means you are above the
// threshold). You can then sum all the cells in row 9 and 10 respectively
// and divide by the total number of ROIs to get the fraction of positive
// cells. Additionally, if you want to determine if a cell is "positive"
// for both stains, enter "double positive" in cell A11 and enter the
// formula =IF(AND(C9=1,C10=1),1,0) in cell C12. You can copy/paste the
// formula and then calculate the fraction of the ROIs that are positive
// for both stains.
///////////////////////////////////////////////////////////////////////////

macro "CalculateColocalization" {
	dir=getDirectory("Choose a Directory"); // Prompts user to directory where images are saved
	filelist=getFileList(dir); // Pulls list of all files in specified directory
	
	filelistlif=newArray(1); // Creates array to place .lif files in.
	num=0; // Index for filelistlif
	for (i = 0; i < filelist.length; i++) { // Loops through all files and stores .lif files in filelistlif
		if (filelist[i].endsWith(".lif")) {
			filelistlif[num]=filelist[i];
			num++;		
		}
	}
	for (i = 0; i < filelistlif.length; i++) { // opens .lif files
	run("Bio-Formats Importer", "open=["+dir+filelistlif[i]+"] autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
	currentfile=File.getName(filelistlif[i]); // Gets current open file
	selectWindow(currentfile); // Selects current open file
	rename("(blinded image)"); // Renames file window to blind user to what sample they are looking at
	Stack.setChannel(3); // switches to the 3rd channel (i.e. NF200)
	run("Gaussian Blur...","simga=3"); // blurs NF200 channel to improve thresholding
	setAutoThreshold("Default dark");
	setOption("BlackBackground", false);
	run("Threshold..."); // Runs threshold on image with correct default settings
	waitForUser("Adjust Threshold and Press Apply Before Pressing Ok"); // Reminds user to manually set the threshold
	run("Convert to Mask", "method=Default background=Dark"); // Converts image to mask
	run("Fill Holes", "slice"); // Fills small holes not properly thresholded
	run("Watershed", "slice"); // Draws lines between axons to seperate them
	run("Analyze Particles...", "size=4000-50000 pixel circularity=0.20-1.00 display exclude clear include summarize add"); // Measures NF200 axons and stores their ROIs
	while (getBoolean("Revise mask?")) { // Allows the user to re-run analyze particles if they don't like what axons are being added to the ROI manager
		run("Analyze Particles...");
	}
	waitForUser("Make corrections to ROIs"); // Allows user to additionally remove ROIs from the manager as needed
	run("Clear Results"); // deletes all previous results
	run("Set Measurements...", "area mean min integrated redirect=None decimal=3"); // sets measurements to make
	roiManager("multi-measure one"); // measures all ROIs for all channels
	selectWindow("Results"); // selects results window
	saveAs("Measurements", dir+currentfile.replace("lif","csv")); // saves results with same filename as image

	while (nImages>0) { // closes all windows
          selectImage(nImages); 
          close(); 
      } 
	}
	while (nImages>0) { // closes all windows
          selectImage(nImages); 
          close(); 
	waitForUser("Image Processing is Complete"); // Lets the user know they have gotten through all the images
} // End macro
