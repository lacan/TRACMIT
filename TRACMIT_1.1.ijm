
/* TRACMIT: an effective pipeline for tracking and analyzing cells on micropatterns
 *  through mitosis
 *  Olivier Burri, Benita Wolf, October 14 2014
 *  EPFL - SV - PTECH - PTBIOP
 *  http://biop.epfl.ch
 *   -------------------------
 *  For Benita Wolf, UPGON
 *  Last update: January 6th 2017
 *  
 * Copyright (c) 2017, Benita Wolf, Olivier Burri
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *   * Neither the name of the <organization> nor the
 *     names of its contributors may be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * 
 * Updates:
 * 28.04.2017:  Fixed a bug that did not allow for the pipeline to be run without 
 * 				a call to "Settings"
 * 
 * 30.05.2017:  Implemented the following functionalities as per Reviewer comments
 * 				Increased the amount of comments in the code
 * 				Added parameter wizards to help estimate initial settings
 * 				Separated settings from TRACMIT pipeline to a new ActionBar
 * 				Corrected a bug where a default threshold was not properly set
*/

// Install common functions
call("BIOP_LibInstaller.installLibrary", "BIOP"+File.separator+"BIOPLib.ijm");

// Basic ActionBar Setup
var barPath = "/plugins/ActionBar/TRACMIT/";

var barName = "TRACMIT_1.1.ijm";

if(isOpen(barName)) {
	run("Close AB", barName);
}

run("Action Bar",barPath+barName);

exit();

//Start of ActionBar

<codeLibrary>

// Function helps you set the name of the Parameters Window


// helper functions

/*
 * To avoid reading each and every file (tens of thousands) in a high throughput experiment, we
 * use knowledge of the expected strucutre of the file name to find out which series are available
 * Structure of a file is:
 * ROW - COL(fld FIELD - time TIME - TIMESTAMP ms).tif"
 * Where 
 * 	ROW is the row number (A-H)
 * 	COL is the column number (1-12)
 * 	FIELD is in this case either 1 or 2, which is the nth image per well
 * 	TIME is an integer (1-t) marking the current timepoint number
 * 	TIMESTAMP is the number of milliseconds since the start of the experiment.
 * 	
 * 	This function is made to check if there are two fields from a 96 well plate image
 * 	by checking the existence of the first timepoint. 
 * 	It can be adapted to other plate types or filenaming conventions, however this is left to the user
 * 	
 * 	Otherwise, there is a simpler function, TODO
 */
function detectWells(folder) {
	// Parsing the folder makes no sense as we KNOW the file name format
	// D - 1(fld 1- time 1
	rows = getRowNames();
	present = newArray(0);
	for (r=1; r<=8; r++) {
		for (c=1; c<=12; c++) {
			for (f=1; f<=2;f++) {
				if (File.exists(folder+rows[r-1]+ " - "+c+"(fld "+f+"- time 1 - 0 ms).tif")) {
					tmp = ""+r+";"+c+";"+f;
					present = Array.concat(present,tmp);
				}
			}
		}
	}
	return present;
}

/* 
 * ParseRowName is used to return the rows as a number rather than a letter in the results table, 
 * as originally ImageJ could not have columns with strings other than
 * the Label.
 */
function parseRowName(name) {
	rows = getRowNames();
	for (i=0; i<rows.length;i++) {
			if (name == rows[i]) 
				return (i+1);
	}
	return -1;	
}

function getRowNames() {
	rows = newArray("A", "B", "C", "D", "E", "F", "G", "H");
	return rows;
}

/*
 * selectImageDialog()
 *
*/
function openImages() {
	folder = getImageFolder();

	// Check if they have the original naming convention
	data = detectWells(folder);
	
	if (data.length > 0) {
		// Use the functions build for the original data
		selectWellDialog(data);
	} else {
		// Use a simpler method that simply lists all images in the folder
		selectImageDialog(); //BIOPLIB Function
	}
	
}

/*
 * Creates a dialog to open specifically formatted image files consistently
 * See the detectWells() function
 */
function selectWellDialog(data) {
	rows = getRowNames();
	choices = newArray(data.length);
	for (i=0; i<data.length; i++) {
		file = split(data[i], ";");
		row = parseInt(file[0]);
		col = parseInt(file[1]);
		field = parseInt(file[2]);
		
		choices[i] = "Well "+rows[row-1]+col+" - Field "+field+" ["+data[i]+"]";	
	}

	
	Dialog.create("Open Images");
	Dialog.addChoice("File", choices, choices[0]);
	Dialog.addCheckbox("Use virtual stack", true);
	Dialog.show();

	file = Dialog.getChoice();
	isVirtual = Dialog.getCheckbox();

	file = substring(file, lastIndexOf(file, "[")+1, lastIndexOf(file, "]"));
	
	openWellImage(folder, file, isVirtual);

}

/*
 * Opens and renames the well image as an image sequence
 */
function openWellImage(dir, id, isVirtual) {
	rows = getRowNames();
	
		file = split(id, ";");
		row = parseInt(file[0]);
		col = parseInt(file[1]);
		field = parseInt(file[2]);
	
	if (isVirtual) { isVirtual = "use";} else { isVirtual = "";}

	file = rows[row-1]+ " - "+col+"(fld "+field;
	print("Opening files with pattern: "+file);
	run("Image Sequence...", "open=["+dir+"] file=["+file+"] sort "+isVirtual);
	//Remove trailing \
	dir = substring(dir, 0 ,lengthOf(dir)-1);
	folder = substring(dir, lastIndexOf(dir, File.separator)+1, lengthOf(dir));
	rename(folder + " Well "+rows[row-1]+col+" - Field "+field);
}


function isHTImage(name) {
	if(matches(name, ".*Well [A-Z]\\d{1,3}.*Field \\d{1,3}.*"))
		return true;
	return false;
}

function preProcessing() {
	ori = getTitle();
	sanitizeImage();
	run("Set Measurements...", "area centroid center fit shape area_fraction stack limit display redirect=None decimal=3");
	getVoxelSize(vx,vy,vz,u);
	nS = nSlices;
	close("Detection Mask");
	doSIFT = getBoolD("Perform SIFT Registration", true);
	imgBlur    = getDataD("Pseudo Flatfield Blur",30);

	// start with SIFT alignment if needed
	if (!matches(ori, ".* Corrected.*")) {
		run("Z Project...", "start=20 projection=[Min Intensity]");
		ff = getTitle();
		run("32-bit");
		
		run("Gaussian Blur...", "sigma="+imgBlur);
		getStatistics(area, mean, min, max);
		run("Divide...", "value="+max);
		imageCalculator("Divide", ori,ff);
		ori = ori+" Corrected";
		rename(ori);
	}
	
	if (doSIFT && !matches(ori, ".* Registered.*")) {
		resetMinAndMax();
		run("Enhance Contrast", "saturated=20.0");
		run("Linear Stack Alignment with SIFT", "initial_gaussian_blur=1.60 steps_per_scale_octave=3 minimum_image_size=64 maximum_image_size=512 feature_descriptor_size=4 feature_descriptor_orientation_bins=8 closest/next_closest_ratio=0.96 maximal_alignment_error=10 inlier_ratio=0.05 expected_transformation=Rigid");
		siftID = getImageID();
		selectImage(ori);
		close();
		selectImage(siftID);
		ori = ori+" Registered";
		rename(ori);
		sanitizeImage();
		setVoxelSize(vx,vy,vz,u);
	}
	
	// Create an image to contain the detections
	getDimensions(xI,yI,zI,cI,tI);
	newImage("Detection Mask", "8-bit black", xI, yI, 1);
	setVoxelSize(vx,vy,vz,u);
	selectImage(ori);

	lapSmooth  = getDataD("Laplacian Smoothing", 2.5);
	lapThr     = getDataD("Laplacian Threshold",-40);
	closeIter  = getDataD("Closing Iterations", 2);
	closeCount = getDataD("Closing Count", 2);
	
	run("Select None");
	// Make sure that the right images are open, or run them
	
	// 1. Laplacian
	if (!isOpen(ori+ " Laplacian") ) {
		run("FeatureJ Laplacian", "compute smoothing="+lapSmooth);
		setVoxelSize(vx,vy,vz,u);
	}

	//Select Laplacian Image
	selectImage(ori+ " Laplacian");
	lap = getImageID();

	// 2. Mask from Laplacian
		if (!isOpen(ori+ " Mask"))  {
		run("Duplicate...","title=["+ori+" Mask] duplicate");
		setThreshold(-10000, lapThr);
		run("Convert to Mask", "stack");
		run("Options...", "iterations="+closeIter+" count="+closeCount+" edm=Overwrite do=Close");
		
		setAutoThreshold("Default");
		setVoxelSize(vx,vy,vz,u);
	}
	selectImage(ori+ " Mask");
	mask = getImageID();

	// Make the images look good
	// Put main image on top
	selectImage(ori);
	sH = 3*screenHeight/4;
	sW = 3*screenWidth/4;
	
	setLocation(0, 0, sH/2, sH/2);
	selectImage(lap);
	
	setLocation(sH/2 + 10, 0, sH/2, sH/2);

	selectImage(mask);
	
	setLocation(0, sH/2 + 10, sH/2, sH/2);
	
	selectImage("Detection Mask");
	
	setLocation(sH/2 + 10, sH/2 + 10, sH/2, sH/2);

	selectImage(ori);
}

function findDivisions() {
	ori = getTitle();
	nR = roiManager("Count");
	isRedo = true;
	if (nR > 3) {
		isRedo = getBoolean("Re-run Division Detection?");
		
		if (isRedo) {deleteRois(3,nR-1); };
	}

	lap = ori+" Laplacian";
	mask = ori+" Mask";
	
	dnaMinSize = getDataD("DNA Min Area", 10);
	dnaMaxSize = getDataD("DNA Max Area", 40);
	
	arDelta    = getDataD("Division Area Tolerance", 5);
	anDelta    = getDataD("Division Angle Tolerance",15);
	dDelta     = getDataD("Division Max distance", 15);
	
	if (isRedo) {
		selectImage(lap);
		getVoxelSize(vx,vy,vz,u);
		nS = nSlices;
		//print("Slices: "+nS);
		k=0;
		for (f=1;f<nS;f++) {
			selectImage(mask);
			setSlice(f);
			// Detect Small nearby DNA.
			run("Analyze Particles...", "size="+dnaMinSize+"-"+dnaMaxSize+" show=Nothing display exclude clear slice");
			
			for (i=0; i<nResults; i++) {
				for (j=(i+1); j<nResults; j++) {
					ar1 = getResult("Area", i);
					ar2 = getResult("Area", j);
					an1 = getResult("Angle", i);
					an2 = getResult("Angle", j);
					x1 = getResult("XM", i);
					x2 = getResult("XM", j);
					y1 = getResult("YM", i);
					y2 = getResult("YM", j);
		
					d = sqrt(pow(x1-x2,2)+pow(y1-y2,2));
							
					if (abs(ar1-ar2) < arDelta && abs(getAngleDelta(an1,an2)) < anDelta && d < dDelta ) {
						selectImage(lap);
						x = newArray(2);
						x[0] = (x1/vx);
						x[1] = (x2/vx);
						y = newArray(2);
						y[0] = (y1/vy);
						y[1] = (y2/vy);

						// Check we are inside the mask.
						roiManager("Select", 2); // Select mask
						if (Roi.contains((x[0]+x[1])/2, (y[0]+y[1])/2)) {
							
							// TODO We could check here that we only keep the division closest to the beggining, and avoid duplicates already?
							k++;
							setSlice(f);
							makeSelection("points", x,y);
							Roi.setName("Potential Division #"+k);
							roiManager("Add");
							print("Found Division #"+k);
							
						} else {
							print("Not in mask");
						}
					}
				}
			}
		}
	}
	selectImage(ori);
}


function confirmDivisions() {
	ori = getTitle();
	lap = ori+" Laplacian";
	mask = ori+" Mask";
	nR = roiManager("Count");
	
	if (nR <= 3) {
		print("Image "+ori+": No Candidates for division confirmation");
		return;
	}

	candidateIdx = findRoiWithName("Selected Candidates");
	roiManager("Select", candidateIdx);
	getSelectionCoordinates(xp,yp);
	
	
	maxreturn = getDataD("Max Frames Until First Mitotic Plate", 2);
	
	minLapThr = getDataD("Mitotic Plate Minimal Laplacian", -60);
	maxAr     = getDataD("Max Total Area of single cell",180);
	nThr     = getDataD("ROI Threshold","Intermodes");
	minA     = getDataD("Min Single Cell Area",100);

	//Set the bounding box
	div_box_w = getDataD("Division Detection Box Width",40);
	div_box_h = getDataD("Division Detection Box Height",40 );
	div_box_x = getDataD("Division Detection Box X offset",5 );
	div_box_y = getDataD("Division Detection Box Y offset",38 );
	//SetData for pattern
	pattern_box_w = getDataD("Pattern Detection Box Width", 80 );
	pattern_box_h = getDataD("Pattern Detection Box Height", 80);

	
	
	isRedo = true;
	idx = findRoiWithName("Division Event.*");
	if (idx > 0) {
		isRedo = getBoolean("Re-run Detection Confirmation?");
		
		if (isRedo) {deleteRois(idx,nR-1); };
	}
	if (isRedo) {
		nR = roiManager("Count");
		getVoxelSize(vx,vy,vz,u);
		k=0;
		selectImage(ori);
		Overlay.clear;
		
		for (i=3;i<nR;i++) {
			selectImage(lap);
			roiManager("Select", i);
			getSelectionCoordinates(xc,yc);
			Stack.getPosition(channel, slice, frame) ;
			x1 = xc[0];
			y1 = yc[0];
			x2 = xc[1];
			y2 = yc[1];
	
			x = (x1 + x2) / 2;
			y = (y1 + y2) / 2;

			selectImage(mask);
			// Check it's where we would expect it
			roiManager("Select", 2); // Select mask
			if (!Roi.contains(x, y)) {
				print("Not in Mask");
			} else {
				// Check if we already found it
				if (wasDetected(x, y)) {
					print("Already found at this position.");
				} else {
					//Find neighbors
					idx = getNearestPattern(x,y, xp, yp);
					selectImage(ori);
					
					setSlice(frame) ;
					makeRectangle(xp[idx], yp[idx]-pattern_box_h,pattern_box_w,pattern_box_h);
					totAr = getTotalArea(nThr);
					
					if (totAr > maxAr) {
						print("Things are too big, Area: "+totAr);
					} else {
						nNeigh = getNeighbors(nThr, minA);
						if (!(nNeigh <= 2) ) {
							
							print("Bad neighbors ("+nNeigh+")");
						} else {
							// Look for mitotic Plate
							// Number of frames to look back
							fMin = getTMin(frame,maxreturn);
							lapValue = -1;
							minVal = 0;
							tInd = 0;
							selectImage(lap);
							makeLine(x1, y1, x2, y2);
							for (fr=frame-1; fr>=fMin; fr--) {
								Stack.setPosition(channel, slice, fr);
								data = getProfile();
								Array.getStatistics(data, min, max, mean, stdDev);
								if (min < minVal) {
									minVal = min;
									tInd = fr;
								}
							}
							
							print("Mitotic Plate Laplacian Value: "+minVal);
							print("Min threshold: "+minLapThr);
					
					
							if (minVal > minLapThr) {
								print("...Could not find mitotic plate");
							} else {
								k++;
								// We made it, it's a division!
								// Draw the ROI
								selectImage(ori);
								Stack.setPosition(channel, slice, tInd);
								makePoint(x,y);
								
								Roi.setName("Division Event #"+k);
								roiManager("Add");
						       	selectImage("Detection Mask");
						       	makePoint(x,y);
						       	run("Enlarge...", "enlarge=10");
						       	run("Fill");
						       	
							}
						}
					}
				}
			}
			selectImage(ori);
			setSlice(frame);
			
			
		}
	}

	// Make image viewable
	selectImage(ori);
	resetThreshold();
}

function findMitoticPlates() {
	ori = getTitle();
	
	idx = findRoiWithName("Division Event.*");

	if (idx < = 3) {
		print("No division events detected!");
		return;
	}

	run("Remove Overlay");
	
	
	mask = ori+" Mask";
	
	areaMin    = getDataD("Mitotic Plate Min Area",30);
	areaMax    = getDataD("Mitotic Plate Max Area",80);
	majorMin   = getDataD("Mitotic Plate Min Major Axis",11); 
	majorMax   = getDataD("Mitotic Plate Max Major Axis",17.1);
	minorMin   = getDataD("Mitotic Plate Min Minor Axis",2);
	minorMax   = getDataD("Mitotic Plate Max Minor Axis",6.8);
	arMin      = getDataD("Mitotic Plate Min Axis Ratio",3);
	arMax      = getDataD("Mitotic Plate Max Axis Ratio",6);
	dMax       = getDataD("Mitotic Plate Max Distance",5);
	maxFrames  = getDataD("Mitotic Plate Max Frames to seek", 3);
	
	nR = roiManager("Count");
	getVoxelSize(vx,vy,vz,u);
	// find all mitotic plates
	for(i=idx; i<nR;i++) {
		//print("Hey");
		// For each position, look for the mitotic plates in time
		selectImage(mask);
		
		roiManager("Select", i);
		rName = Roi.getName;
		divID = substring(rName,indexOf(rName,"#")+1,lengthOf(rName));
		getSelectionBounds(xStart, yStart, w, h);
		run("Enlarge...", "enlarge=15");
		
		fr = getSliceNumber();
		lostF = 0;
		//um
		lastX = xStart*vx;
		lastY = yStart*vy;
		
		angle = newArray(0);
		slice = newArray(0);
		posX  = newArray(0);
		posY  = newArray(0);
		maj   = newArray(0);
		min   = newArray(0);
		are   = newArray(0);
	
		nFound = 0;
		lostF = 0;
		// Analyse going backwards
		while(lostF < maxFrames && fr > 0) {
			
			
			roiManager("Select", i);
			setSlice(fr);
			run("Enlarge...", "enlarge=15");
			run("Analyze Particles...", "size="+areaMin+"-"+areaMax+" display clear slice");
			found = false;
			for(r=0;r<nResults;r++) {
				ar = getResult("Area", r);
				in = getResult("Mean", r);
				ma = getResult("Major", r);
				mi = getResult("Minor", r);
				an = getResult("Angle", r);
				s  = getResult("Slice", r);
				px  = getResult("XM", r);
				py  = getResult("YM", r);
				aratio = getResult("AR", r);
				d = distance(lastX,lastY, px, py);
				if (d < dMax) {
					
					print("Distance OK: "+d);
					print("Major: "+ma+" vs. ["+majorMin+","+majorMax+"]");
					print("Minor: "+mi+" vs. ["+minorMin+","+minorMax+"]");
					print("Ratio: "+aratio+" vs. ["+arMin+","+arMax+"]");
					
					
					if (inRange(ma, majorMin, majorMax) && inRange(mi,  minorMin, minorMax) && inRange(aratio, arMin,arMax)) {
						// Found plate, keep angle data.
						r=nResults; // exit for loop
						angle = Array.concat(angle, an);
						slice = Array.concat(slice, s);
						posX = Array.concat(posX, px);
						posY = Array.concat(posY, py);
						maj = Array.concat(maj, ma);
						min = Array.concat(min, mi);
						are = Array.concat(are, ar);
						nFound++;
						found = true;
						lastX = px;
						lastY = py;
					}
				}
			}
			
			if (!found) { lostF++; } else { lostF = 0; }
			
			
			// Go to the next frame
			fr--;
		}

		print("Mitotic Plates found, (IDX="+divID+"): "+nFound);
		if(angle.length > 0) {
			// Save Results
			//run("Clear Results");
			//prepareTable("Angle Measurements");
			//closeTable("Angle Measurements");
			prepareTable("Angle Measurements");
			updateResults();
			n = nResults;
			//Rows
			label = ori;
			if(isHTImage(ori)) {
				well = substring(ori, lastIndexOf(ori, "Well ")+5, indexOf(ori, "-"));
				r = substring(well, 0,1);
				c = parseInt(substring(well, 1,lengthOf(well)));
				f = parseInt(substring(ori, lastIndexOf(ori,"Field ")+6,lengthOf(ori)));
				label = File.directory;

			}
			
			
			for (b=n; b<n+angle.length; b++) {

				// Draw a rectangle and add it to the overlay?
				
				//print(i);
				setResult("Label", b, label);
				setResult("Division ID", b, divID);
				if(isHTImage(ori)) {
					setResult("Row", b, parseRowName(r));
					setResult("Col", b, c);
					setResult("Field", b, f);
				}
				
				setResult("Area", b, are[b-n]);
				setResult("Major", b ,maj[b-n]);
				setResult("Minor", b, min[b-n]);
				setResult("Angle", b, angle[b-n]);
				setResult("Slice", b, slice[b-n]);
				setResult("XM", b, posX[b-n]);
				setResult("YM", b, posY[b-n]);
				setResult("Area", b, are[b-n]);
			}
			updateResults();
			closeTable("Angle Measurements");
			selectWindow("Angle Measurements");
			updateResults();

			
			//run("Clear Results");
			//prepareTable("Angles Summary");
			//closeTable("Angles Summary");
			prepareTable("Angles Summary");
			updateResults();
			n = nResults;
			
			
			Array.getStatistics(angle, amin, amax, amean, asdev);
			
			setResult("Label", n, label);
			setResult("Division ID", n, divID);
			if(isHTImage(ori)) {
				rName = parseRowName(r);
				setResult("Row", n, rName);
				setResult("Col", n, c);
				setResult("Field", n, f);
			}
			setResult("Last Angle", n, angle[0]);
			setResult("Angle StdDev", n, asdev);
			setResult("Angle Mean", n, amean);
			setResult("Number of Frames", n, nFound);
			updateResults();
			
			closeTable("Angles Summary");
			selectWindow("Angles Summary");

		}
	}
	selectImage(ori);
	
}
function segmentPatterns(start, medianR) {
	ori=getTitle();
	
	run("Select None");
	run("Z Project...", "start="+start+" projection=[Min Intensity]");
	run("32-bit");
	run("Smooth");
	minI = getTitle();
		
	getStatistics(area, mean, min, max);
	setThreshold(15, max);
	run("NaN Background");
	setAutoThreshold("Huang dark");
	run("Convert to Mask");
	rename(ori+" Traps Mask");
	run("Median...", "radius="+medianR);
	
}

function getStartSlice() {
	getDimensions(x,y,c,z,t);
	start = 20;
	if(start >= (t-10) ) start = 0;

	return start;
}

function detectPatterns() {
	
	preProcessing();
	ori = getTitle();

	startSlice = getStartSlice();
	
	idx = findRoiWithName("Detected Traps");
	isRedo = true;
	
	if (idx != -1) {
		isRedo = getBoolean("Traps were detected. Re-run detection?");
	}
	close(ori+" Traps Mask");
	
	    medianR = getDataD("Pattern Mask Median Filter", 6);
	patternMinA = getDataD("Pattern Min Area",350); 
	patternMaxA = getDataD("Pattern Max Area", "Infinity");

	if (isRedo) {
		roiManager("Reset");
		
		segmentPatterns(startSlice, medianR);
		seg= getTitle();
		run("Analyze Particles...", "size="+patternMinA+"-"+patternMaxA+" display exclude clear add");		
		// Update all ROIs, keep only bottom left area
		nR = roiManager("Count");
		pointsX = newArray(nR);
		pointsY = newArray(nR);
		
		for(i=nR-1; i>=0; i--) {
			roiManager("Select",i);
			getSelectionBounds(x,y,w,h);
			roiManager("Delete");
			pointsX[i] = x;
			pointsY[i] = y+h;	
		}
		makeSelection("points", pointsX, pointsY);
		Roi.setName("Detected Traps");
		roiManager("Add");

	} 
		close(seg);
		selectImage(ori);
}

function makeSTDImage(ori, start) {
		
		run("Z Project...", "start="+start+" projection=[Standard Deviation]");
		stdevi = getImageID();
		
		selectImage(ori);
		run("Z Project...", "start="+start+" projection=[Average Intensity]");
		avgi = getImageID();
		
		imageCalculator("Divide 32-bit create", stdevi, avgi);
		id = getImageID;
		
		selectImage(stdevi);
		close();
		selectImage(avgi);
		close();
		selectImage(id);
		
}
function filterPatterns() {

	ori = getTitle();
	
	start = getStartSlice();
	
	idx = findRoiWithName("Selected Candidates");
	isRedo = true;
	if (idx != -1) {
		isRedo = getBoolean("Traps were already filtered. Re-run filtering?");
	}

	minSD 	   = getDataD("Pattern Min SD", 0.10); 
	maxSD 	   = getDataD("Pattern Max SD", 0.45);
	
		//Set the bounding box
	div_box_w = getDataD("Division Detection Box Width",40);
	div_box_h = getDataD("Division Detection Box Height",40 );
	div_box_x = getDataD("Division Detection Box X offset",5 );
	div_box_y = getDataD("Division Detection Box Y offset",38 );
	//SetData for pattern
	pattern_box_w = getDataD("Pattern Detection Box Width", 80 );
	pattern_box_h = getDataD("Pattern Detection Box Height", 80);
	

	if (isRedo) {
		
		if(roiManager("Count") == 2) {
			roiManager("Select", idx);
			roiManager("Delete");
			roiManager("Select", idx+1);
			roiManager("Delete");
		}		

		makeSTDImage(ori, start);
		res = getImageID();
		
		roiManager("Select", 0);
		
		getSelectionCoordinates(x,y);
		ind = newArray(0);
		
		k=0;
		xc = newArray(0);
		yc = newArray(0);
		
		for (i=0; i<x.length; i++) {
			makeRectangle(x[i], y[i]-pattern_box_h,pattern_box_w,pattern_box_h);
			//waitForUser;
			//roiManager("Add");
			getStatistics(area, mean);
			if ( inRange(mean, minSD, maxSD)) {
				//keep point
		
				xc = Array.concat(xc,x[i]);
				yc = Array.concat(yc,y[i]);
				makeRectangle(x[i]+div_box_x, y[i]-div_box_y, div_box_w,div_box_h);
				roiManager("Add");
				k++;
				ind = Array.concat(ind, k);
				
			}
		
		}

		makeSelection("point",xc,yc);
		Roi.setName("Selected Candidates");
		roiManager("Add");
		
		roiManager("Select", ind);
		roiManager("OR");
		Roi.setName("Position Masks");
		roiManager("Add");
		roiManager("Select", ind);
		roiManager("Delete");

		selectImage(res);
		rename(ori+" Relative STDDEV");
		run("Enhance Contrast", "saturated=0.65");
		close();
		
		selectImage(ori);
	}
}

function wasDetected(x,y) {
	selectImage("Detection Mask");
	if (getPixel(x,y) > 0) {
		return true;
	} else {
		return false;
	}
}

function getAngleDelta(angle1, angle2) {
	a = angle1 - angle2;
	if (a > 180)
		a -= 360;
	if (a < -180)
		a += 360;
	return a;
		
}
function getNearestPattern(x,y,xp,yp) {

	dmin = 1000;
	ip = -1;
	for(i=0; i<xp.length; i++) {
		d = distance(x,y,xp[i],yp[i]);
		if (d < dmin) {
			dmin = d;
			ip = i;
		}
	}

	return ip;
}

function distance(x1,y1,x2,y2) {
	d = sqrt(pow(x1-x2,2)+pow(y1-y2,2));
	return d;
}

function deleteRois(startI, endI) {
	toDel = newArray(endI-startI+1);
	for(i=startI;i<=endI;i++) {
			toDel[i-startI] = i;
	}
		roiManager("Select", toDel);
		roiManager("Delete");
}

function getTMin(frame, maxreturn) {
	tMin = frame-maxreturn;
	if (tMin <=0) {
		tMin = 0;
	}
	return tMin;
}

function findRoiWithName(roiName) {
	nR = roiManager("Count");

	for (i=0; i<nR; i++) {
		roiManager("Select", i);
		rName = Roi.getName();
		if (matches(rName, roiName)) {
			return i;
		}
	}
	return -1;
}

function getNeighbors(nThr, nMin) {
	// Check for neighbors
	// 1 find nearest pattern
	// 2 check neighbors
	setAutoThreshold(nThr+" dark");
	
	run("Analyze Particles...", "size="+nMin+"-Infinity show=Nothing display clear slice");
	nNeigh = nResults;
	
	return nNeigh;
	
}


function sanitizeImage() {
	getDimensions(x,y,c,z,t);
	if (z > 1 && t == 1) {
		run("Properties...", "channels="+c+" slices=1 frames="+z);
	}
	
	
}
function getTotalArea(nThr) {
	setAutoThreshold(nThr+" dark");
	run("Measure");
	ar = getResult("Area", nResults-1); 
	return ar;

}

function inRange(val, min, max) {
	if (val > min && val < max) {
		return true;
	} else {
		return false;
	}
}

 function toolName() {
 	return "Mitotic Division Analysis Tool";
 }

function saveResults(dir) {
	// Save both tables
	if (dir == "") {
		dir = getImageFolder();
	}
	
	name = getTitle();
	print("Saving to "+dir);
	if (isOpen("Angle Measurements")) {
		prepareTable("Angle Measurements");
		saveAs("Results", dir+name+"_Angles.txt");
		closeTable("Angle Measurements");
	}
	if (isOpen("Angles Summary")) {
		prepareTable("Angles Summary");
		saveAs("Results", dir+name+"_Summary.txt");
		closeTable("Angles Summary");
	}

	
	// Save all ROIs
	roiManager("Deselect");
	if (roiManager("Count") > 0) {
		roiManager("Save", dir+name+".zip");
	}
}


function measureCurrentImage() {
	sanitizeImage();

	ori = getTitle();

	// Get Laplacian Image, get Mask Image and arrange images.
	
	preProcessing();

	detectPatterns();
	
	filterPatterns();

	// find all division-like events
	findDivisions();
	
	// confirm those divisions
	confirmDivisions();

	// Find the mitotic plates
	findMitoticPlates();
}

</codeLibrary>
<text><html><font size=4 color=#0C2981> Image Selection
<line>
<button>
label=Select Folder
icon=noicon
arg=<macro>
//Open the file and parse the data
openParamsIfNeeded();
setImageFolder("Select Working Folder");
</macro>
</line>

<line>
<button>
label=Select Image
icon=noicon
arg=<macro>
openImages();
</macro>
</line>

<line>
<button>
label=Save image (+ ROI)
icon=noicon
arg=<macro>

saveCurrentImage();
//Saves the ROI Set with the name of the current image
saveRois("Open");
</macro>
</line>


<text><html><font size=4 color=#0C2981> TRACMIT Configuration
<line>
<button>
label=Settings
icon=noicon
arg=<macro>
var barPath = "/plugins/ActionBar/TRACMIT/";

run("Action Bar",barPath+"TRACMIT_Settings_1.1.ijm");
</macro>
</line>

<line>
<button>
label=Save Settings
icon=noicon
arg=<macro>
saveParameters();
</macro>

<button>
label=Load Settings
icon=noicon
arg=<macro>
loadParameters();
</macro>
</line>

<text><html><font size=4 color=#0C2981> TRACMIT Pipeline
<line>
<button>
label=Measure Current Image
icon=noicon
arg=<macro>
measureCurrentImage();
</macro>
</line>
<line>
<button>
label=Batch Process Folder
icon=noicon
arg=<macro>
folder = getImageFolder();
data = detectWells(folder);
if (data.length > 0) {
	data = getImagesList();
	is_simple_mode = true;
}
for(i=0; i<data.length;i++) {
	if(is_simple_mode) {
		open(folder+data[i]);
	} else {
		openWellImage(folder, data[i], false);
	}
	
	measureCurrentImage();
	saveResults("");
	run("Close All");
	selectWindow("Log");
	run("Close");
	if (isOpen("Angles Summary")) {
		selectWindow("Angles Summary");
		run("Close");
	}
	if (isOpen("Results")) {
		selectWindow("Results");
		run("Close");
	}
	if (isOpen("Angle Measurements")) {
		selectWindow("Angle Measurements");
		run("Close");
	}
	
	roiManager("Reset");
	
	
}

</macro>
</line>


<text><html><font size=4 color=#0C2981> Run Individual Steps
<line>
<button>
label=Detect Traps
icon=noicon
arg=<macro>

detectPatterns();
</macro>

<button>
label=Filter Traps
icon=noicon
arg=<macro>

filterPatterns();
</macro>

</line>


<line>
</macro>
<button>
label=Detect Divisions
icon=noicon
arg=<macro>

// find all division-like events
findDivisions();
</macro>

</macro>
<button>
label=Filter Divisions
icon=noicon
arg=<macro>
	
	// confirm those divisions
	confirmDivisions();


</macro>

</line>
<line>
<button>
label=Find Mitotic Plates
icon=noicon
arg=<macro>

	// Find the mitotic plates
	findMitoticPlates();


</macro>
</line>

<text><html><font size=4 color=#0C2981> Division Visualization
<line>
<button>
label=Inspect Division
icon=noicon
arg=<macro>
roiName = Roi.getName;
if(matches(roiName, "Potential.*")) {
	s = getSliceNumber();
	ss = s-4;
	se = s+4;
	nS = nSlices;
	if(se > nS) se = nS;
	if(ss < 1) ss = 1;

	run("Enlarge...", "enlarge=22 pixel");
	run("To Bounding Box");
	run("Duplicate...", "duplicate range="+ss+"-"+se);
	rename(roiName);
	
} else {
	divID = substring(roiName, indexOf(roiName, "#")+1, lengthOf(roiName));
	
	
	
	setForegroundColor(255, 255, 255);
	run("Enlarge...", "enlarge=22 pixel");
	run("To Bounding Box");
	run("Duplicate...", "duplicate");
	prepareTable("Angle Measurements");
	minSlice = 10000;
	maxSlice = 0;
	setLineWidth(2);
	run("Select All");
	getSelectionBounds(x, y, width, height);
	for (i=0; i<nResults; i++) {
		id = getResult("Division ID", i);
		//print(name, roiName);
		
		if (divID == id) {
			a = getResult("Angle", i);
			s = getResult("Slice", i);
			
			setSlice(s);
	
			if(minSlice > s) minSlice = s;
			if(maxSlice < s) maxSlice = s;
			
			
			makeText("A: "+d2s(a,1), 3, 1);
			run("Fill", "slice");
			makeText("S: "+d2s(s,0), 22, 40);
			run("Fill", "slice");
			
			drawRect(x, y, width, height);
			
		}
		
	}
	id = getImageID();
	
	if (maxSlice+5 > nSlices) {stop=nSlices;} else { stop = maxSlice+5;}
	if (minSlice-5 < 1) {start=1;} else { start = minSlice-5;}
	
	nC = 5;
	nR = floor((stop - start +1) / 5)+1;
	
	//print(divID,start,stop,nC,nR);
	run("Make Montage...", "columns="+nC+" rows="+nR+" scale=1 first="+start+" last="+stop+" increment=1 border=0");
	id2 = getImageID();
	selectImage(id);
	close();
	
	
	run("Select None");
	closeTable("Angle Measurements");
	selectWindow("Angle Measurements");
}
</macro>

</line>


<text><html><font size=4 color=#0C2981> Misc Tools
<line>
<button>
label=Close All but Current Image
icon=noicon
arg=<macro>
close("\\Others");
</macro>
</line>

<line>
<button>
label=Save table & (ROIs Current Image)
icon=noicon
arg=<macro>
dir = getDirectory("Where to save");
saveResults(dir);
</macro>
</line>
