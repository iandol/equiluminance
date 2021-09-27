function trainColourCuedCore(ana)

if ~exist('ana','var') || isempty(ana) 
	ana = readstruct('~/Desktop/ana.xml');
	fn = fieldnames(ana);
	for i = 1:length(fn)
		if isstring(ana.(fn{i})) && strcmp(ana.(fn{i}),"false")
			ana.(fn{i}) = false;
		elseif isstring(ana.(fn{i})) && strcmp(ana.(fn{i}),"true")
			ana.(fn{i}) = true;
		end
	end
end

global rM %#ok<*GVMIS> 
if ~exist('rM','var') || isempty(rM)
	rM = arduinoManager();
end
if ~ana.useArduino
	rM.silentMode = true; 
	ana.rewardDuring=false;
	ana.rewardEnd=false;
	ana.rewardStart=false;
else
	rM.reset;
	rM.silentMode = false;
end
if ~rM.isOpen; open(rM); end %open our reward manager

global aM
if ~exist('aM','var') || isempty(aM)
	aM = audioManager;
end
if ~aM.isOpen; open(aM); end %open our audio manager

fixColour = [1 1 1];
if isstring(ana.colours)||ischar(ana.colours);ana.colours = eval(ana.colours);end

commandwindow;
fprintf('\n--->>> trainColourCued Started: ana UUID = %s!\n',ana.uuid);

%===================Initiate out metadata===================
ana.date		= datestr(datetime);
ana.version		= Screen('Version');
ana.computer	= Screen('Computer');
ana.gpu			= opengl('data');
thisVerbose		= false;

%===================Make a name for this run===================
pf='ColorCued_';
if ~isempty(ana.subject)
	nameExp = [pf ana.subject];
	c = sprintf(' %i',fix(clock()));
	nameExp = [nameExp c];
	ana.nameExp = regexprep(nameExp,' ','_');
else
	ana.nameExp = 'debug';
end

cla(ana.plotAxis1);
cla(ana.plotAxis2);
cla(ana.plotAxis3);
cla(ana.plotAxis4);

try
	PsychDefaultSetup(2);
	Screen('Preference', 'SkipSyncTests', 0);
	%===================open our screen====================
	sM						= screenManager();
	sM.name					= ana.nameExp;
	sM.screen				= max(Screen('Screens'));
	sM.verbose				= thisVerbose;
	sM.bitDepth				= ana.bitDepth;
	if ana.debug || ismac || ispc || ~isempty(regexpi(ana.gpu.Vendor,'NVIDIA','ONCE'))
		sM.disableSyncTests = true; 
	end
	if ana.debug
		%sM.windowed		= [0 0 1400 1000]; 
		sM.visualDebug		= true;
		sM.debug			= true;
		sM.verbosityLevel	= 4;
	else
		sM.debug			= false;
		sM.verbosityLevel	= 3;
	end
	sM.backgroundColour		= ana.backgroundColour;
	sM.pixelsPerCm			= ana.pixelsPerCm;
	sM.distance				= ana.distance;
	sM.photoDiode			= true;
	sM.blend				= true;
	if isfield(ana,'screenCal') && exist(ana.screenCal, 'file')
		load(ana.screenCal);
		if exist('c','var') && isa(c,'calibrateLuminance')
			sM.gammaTable	= c;
		end
		clear c;
	end
	sM.open;
	ana.gpuInfo				= Screen('GetWindowInfo',sM.win);
	ana.ppd = sM.ppd;
	fprintf('\n--->>> ColourTrainCued Opened Screen %i : %s\n', sM.win, sM.fullName);
	
	%===========================set up stimuli====================
	circle1 = discStimulus;
	circle2 = discStimulus;
	circle3 = discStimulus;
	circle4 = discStimulus;
	circle1.name = 'target';
	circle2.name = 'circle2';
	circle3.name = 'circle3';
	circle4.name = 'circle4';
	circle1.sigma = ana.sigma1;
	circle2.sigma = ana.sigma2;
	circle3.sigma = ana.sigma2;
	circle4.sigma = ana.sigma2;
	circle1.size = ana.circle1Diameter;
	circle2.size = ana.circle2Diameter;
	circle3.size = ana.circle2Diameter;
	circle4.size = ana.circle2Diameter;
	
	if ana.DKL
		cM = colourManager();
		cM.backgroundColour = ana.backgroundColor;
		cM.verbose = true;
		disp(circle1.fullName);
		ana.rgb1 = cM.DKLtoRGB([ana.colour1(1) ana.colour1(2) ana.contrast1]);
		disp(circle2.fullName);
		ana.rgb1b = cM.DKLtoRGB([ana.colour1(1)/ana.radiusDivisor ana.colour1(2) ana.contrast2]);
		ana.rgb1c = cM.DKLtoRGB([ana.colour1(1)/ana.radiusDivisor ana.colour1(2) ana.contrast3]);
		disp(circle3.fullName);
		ana.rgb2 = cM.DKLtoRGB([ana.colour2(1) ana.colour2(2) ana.contrast1]);
		disp(circle4.fullName);
		ana.rgb2b = cM.DKLtoRGB([ana.colour2(1)/ana.radiusDivisor ana.colour2(2) ana.contrast2]);
		ana.rgb2c = cM.DKLtoRGB([ana.colour2(1)/ana.radiusDivisor ana.colour2(2) ana.contrast3]);
		circle1.colour = ana.rgb1;
		circle2.colour = ana.rgb2b;
		circle3.colour = ana.rgb2c;
		circle4.colour = ana.rgb1b;
	else
		circle1.colour = ana.colour1;
		circle2.colour = ana.colour2;
		circle3.colour = ana.colour2;
		circle4.colour = ana.colour2;
		circle1.alpha  = 1.0;
		circle2.alpha  = ana.alpha2;
		circle3.alpha  = ana.alpha3;
		circle4.alpha  = ana.alpha4;
	end
	
	vals = {ana.pos1, ana.pos2, ana.pos3, ana.pos4};
	circle1.xPosition = ana.pos1(1);
	circle2.xPosition = ana.pos2(1);
	circle3.xPosition = ana.pos3(1);
	circle4.xPosition = ana.pos4(1);
	circle1.yPosition = ana.pos1(2);
	circle2.yPosition = ana.pos2(2);
	circle3.yPosition = ana.pos3(2);
	circle4.yPosition = ana.pos4(2);
	
	if ana.show34
		show(circle3);
		show(circle4);
	else
		hide(circle3);
		hide(circle4);
	end
	
	metaStim = metaStimulus('stimuli',{circle1,circle2,circle3,circle4},'screen',sM);
	
	setup(metaStim);
	
	%============================SET UP VARIABLES=====================================
	colours = ana.colours;
	seq = taskSequence();
	seq.nVar(1).name = 'xyPosition';
	seq.nVar(1).stimulus = 1;
	seq.nVar(1).values = vals;
	seq.nVar(2).name = 'colour';
	seq.nVar(2).stimulus = 1;
	seq.nVar(2).values = colours;
	seq.nBlocks = ana.trialNumber;
	seq.fps = sM.screenVals.fps;
	seq.initialise();
	ana.nTrials = seq.nRuns;
	fprintf('--->>> Train # Trials: %i; # FPS: %i \n',seq.nRuns, sM.screenVals.fps);
	WaitSecs('YieldSecs',0.25);
	
	%==============================setup eyelink==========================
	eL = eyelinkManager('IP',[]);
	eL.name = ana.nameExp;
	fprintf('--->>> Train eL setup starting: %s\n', eL.fullName);
	eL.isDummy = ana.isDummy; %use dummy or real eyelink?
	eL.saveFile = [ana.nameExp '.edf'];
	eL.recordData = true; %save EDF file
	eL.calibrationProportion = ana.calibprop;
	eL.sampleRate = ana.sampleRate;
	eL.verbose	= true;
	eL.remoteCalibration = ana.manualCalibration; % manual calibration?
	eL.calibrationStyle = ana.calibrationStyle; % calibration style
	eL.modify.calibrationtargetcolour = [1 1 1];
	eL.modify.calibrationtargetsize = 1.5;
	eL.modify.calibrationtargetwidth = 0.08;
	eL.modify.waitformodereadytime = 500;
	eL.modify.devicenumber = -1; % -1 = use any keyboard
	% X, Y, FixInitTime, FixTime, Radius, StrictFix
	targetFixModifier = 1.6;
	updateFixationValues(eL, ana.fixX, ana.fixY, ana.firstFixInit,...
		ana.firstFixTime, ana.firstFixDiameter, ana.strictFixation);
	
	%sM.verbose = true; eL.verbose = true; sM.verbosityLevel = 10; eL.verbosityLevel = 4; %force lots of log output
	
	initialise(eL, sM); %use sM to pass screen values to eyelink
	setup(eL); % do setup and calibration
	fprintf('--->>> Train eL setup complete: %s\n', eL.fullName);
	WaitSecs('YieldSecs',0.5);
	getSample(eL); %make sure everything is in memory etc.
	
	%=======================set up the triggers===========================
	if ana.sendTrigger == true
		dPP = plusplusManager;
		dPP.sM = sM;
		dPP.open();
		WaitSecs(0.2);
		dPP.sendStrobe(0);
		flip(sM); flip(sM);
	end
	
	%====================initialise our trial variables====================
	plotVals.t1 = [];
	plotVals.p1 = [];
	plotVals.p2 = [];
	plotVals.t2 = [];
	plotVals.p3 = [];
	ana.trialDuration = 1;
	ana.nSuccess = 0;
	ana.nFixBreak = 0;
	ana.nInitiateBreak = 0;
	ana.nTotal = 0;
	ana.runningPerformance = [];
	tReaction = 0;
	tL = timeLogger();
	tL.screenLog.beforeDisplay = GetSecs();
	tL.screenLog.stimTime(1) = 1;
	powerValues = [];
	breakLoop = false;
	ana.trial = struct();
	excludedN = 0;
	tick = 1;
	halfisi = sM.screenVals.halfisi;
	if ~ana.debug;ListenChar(-1);end
	Priority(MaxPriority(sM.win));
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%=====================START HERE====================
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	while ~seq.taskFinished && ~breakLoop
		
		xyPos = seq.outValues{seq.totalRuns,1};
		xPos = xyPos(1); yPos = xyPos(2);
		fpos = cellfun(@isequal,vals,repmat({xyPos},1,4));
		nvals = vals(~fpos);
		rList = randsample(3,3);
		nvals = nvals(rList); % shuffled
		circle1.xPositionOut = ana.fixX;
		circle1.yPositionOut = ana.fixY;
		circle2.xPositionOut = nvals{1}(1);
		circle2.yPositionOut = nvals{1}(2);
		circle3.xPositionOut = nvals{2}(1);
		circle3.yPositionOut = nvals{2}(2);
		circle4.xPositionOut = nvals{3}(1);
		circle4.yPositionOut = nvals{3}(2);
		
		thisColour = seq.outValues{seq.totalRuns,2};
		circle1.colourOut = thisColour;
		colourNumber = seq.outMap(seq.totalRuns,2);
		maxC = length(colours);
		
		if ana.sendTrigger == true;sendStrobe(dPP,0);flip(sM);flip(sM);end
		resetFixation(eL,true); resetExclusionZones(eL);
		updateFixationValues(eL, ana.fixX, ana.fixY, ana.firstFixInit,...
			ana.firstFixTime, ana.firstFixDiameter, ana.strictFixation);
		eL.fixInit = struct('X',[],'Y',[],'time',0.1,'radius',ana.firstFixDiameter);
		trackerClearScreen(eL);
		trackerDrawFixation(eL); %draw fixation window on eyelink computer
		edfMessage(eL,'V_RT MESSAGE END_FIX END_RT');  %this 3 lines set the trial info for the eyelink
		edfMessage(eL,['TRIALID ' num2str(seq.outIndex(seq.totalRuns))]);  %obj.getTaskIndex gives us which trial we're at
		startRecording(eL);
		
		n1 = NaN;	n2 = NaN;	n3 = NaN;
		while any(isnan([n1 n2 n3]))
			x = randi([1 maxC],1,1);
			if x == colourNumber || x == n1 || x == n2 || x == n3
				continue
			end
			if isnan(n1); n1 = x; continue; end
			if isnan(n2); n2 = x; continue; end
			if isnan(n3); n3 = x; continue; end
		end
		
		circle2.colourOut = colours{n1};
		circle3.colourOut = colours{n2};
		circle4.colourOut = colours{n3};
		update(circle1); update(circle2); update(circle3); update(circle4);
		
		ana.nTotal = ana.nTotal + 1;
		ana.trial(ana.nTotal).n = seq.totalRuns;
		ana.trial(ana.nTotal).variable = seq.outIndex(seq.totalRuns);
		ana.trial(ana.nTotal).thisColour = thisColour;
		ana.trial(ana.nTotal).colourNumber = colourNumber;
		ana.trial(ana.nTotal).maxC = maxC;
		ana.trial(ana.nTotal).colour1 = circle1.colourOut;
		ana.trial(ana.nTotal).colour2 = circle2.colourOut;
		ana.trial(ana.nTotal).colour3 = circle3.colourOut;
		ana.trial(ana.nTotal).colour4 = circle4.colourOut;
		ana.trial(ana.nTotal).x1 = xPos;
		ana.trial(ana.nTotal).y1 = yPos;
		ana.trial(ana.nTotal).x2 = nvals{1}(1);
		ana.trial(ana.nTotal).y2 = nvals{1}(2);
		ana.trial(ana.nTotal).x3 = nvals{2}(1);
		ana.trial(ana.nTotal).y3 = nvals{2}(2);
		ana.trial(ana.nTotal).x4 = nvals{3}(1);
		ana.trial(ana.nTotal).y4 = nvals{3}(2);
		
		fprintf('\n===>>> Train START Trial = %i : %i / %i | %s, %s\n', ana.nTotal,...
			seq.totalRuns, seq.nRuns, sM.fullName, eL.fullName);
		
		
		%=========================MAINTAIN INITIAL FIXATION==========================
		statusMessage(eL,'INITIATE FIXATION...');
		fixated = '';
		drawPhotoDiode(sM,[0 0 0]);
		if ana.sendTrigger == true;sendStrobe(dPP,248);flip(sM);end
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix') && ~strcmpi(fixated,'EXCLUDED!')
			drawCross(sM,0.4,fixColour,ana.fixX,ana.fixY);
			drawPhotoDiode(sM,[0 0 0]);
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> Recalibrate pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> Drift correct pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'q'}
						fprintf('===>>> Train quit pressed!!!\n');
						fixated = 'breakfix';
						breakLoop = true;
				end
			end
			flip(sM); %flip the buffer
		end
		
		if ~strcmpi(fixated,'fix')
			sM.drawBackground;
			drawPhotoDiodeSquare(sM,[0 0 0]);
			flip(sM);
			if ana.sendTrigger == true;sendStrobe(dPP,249);flip(sM);end
			if ana.sendTrigger == true;sendStrobe(dPP,255);flip(sM);flip(sM);end %STIM OFF
			statusMessage(eL,'Subject Broke Initial Fixation!');
			edfMessage(eL,'MSG:BreakInitialFix');
			ana.runningPerformance(ana.nTotal) = -1;
			ana.nInitiateBreak = ana.nInitiateBreak + 1;
			ana.trial(ana.nTotal).success = false;
			ana.trial(ana.nTotal).xAll = eL.xAll;
			ana.trial(ana.nTotal).yAll = eL.yAll;
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', seq.totalRuns);	
			updatePlot(seq.totalRuns);
			aM.beep(150,0.5,1);
			WaitSecs('YieldSecs',ana.punishDelay);
			continue
		end
		
		if ana.fixOnly
			tStart = GetSecs;
		else
		%=========================CUE TIME!==========================
		
		%sM.verbose = false; eL.verbose = false; sM.verbosityLevel = 4; eL.verbosityLevel = 4; %force lots of log output
		fprintf('===>>> Show Cue for: %.2f s\n',ana.cueTime);
		statusMessage(eL,'Show Cue...');
		drawCross(sM,0.4,[1 1 1 1],ana.fixX,ana.fixY); drawPhotoDiode(sM,[0 0 0]);
		vbl = flip(sM); tStart = vbl;
		while vbl <= tStart + ana.cueTime
			draw(circle1);
			drawCross(sM,0.4,[1 1 1 1],ana.fixX,ana.fixY,[],true,0.5);drawPhotoDiode(sM,[1 1 1]);
			vbl = Screen('Flip',sM.win, vbl + halfisi);
			getSample(eL);
			if ~isFixated(eL)
				fixated = 'breakfix';
				break %break the while loop
			end
		end
		if strcmpi(fixated,'breakfix')
			sM.drawBackground;
			if ana.sendTrigger == true;sendStrobe(dPP,249);flip(sM);end
			if ana.sendTrigger == true;sendStrobe(dPP,255);flip(sM);flip(sM);end %STIM OFF
			statusMessage(eL,'Subject Broke CUE Fixation!');
			edfMessage(eL,'MSG:BreakCueFix');
			edfMessage(eL,'TRIAL_RESULT -1');
			
			ana.runningPerformance(ana.nTotal) = -1;
			ana.nInitiateBreak = ana.nInitiateBreak + 1;
			ana.trial(ana.nTotal).success = false;
			ana.trial(ana.nTotal).xAll = eL.xAll;
			ana.trial(ana.nTotal).yAll = eL.yAll;
			
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			
			fprintf('===>>> BROKE CUE FIXATION Trial = %i\n', seq.totalRuns);
			drawPhotoDiode(sM,[0 0 0]);
			flip(sM);
			aM.beep(250,1,1);
			updatePlot(seq.totalRuns);
			WaitSecs('YieldSecs',ana.punishDelay);
			continue
		end
		
		%=========================DELAY TIME!==========================
		if length(ana.delayToChoice) == 2
			delayToChoice = (rand * (ana.delayToChoice(2)-ana.delayToChoice(1))) + ana.delayToChoice(1);
		else
			delayToChoice = ana.delayToChoice;
		end
		fprintf('===>>> Delay to Choice is: %.2g\n',delayToChoice);
		statusMessage(eL,['Delay is ' num2str(delayToChoice)]);
		drawCross(sM,0.4,[1 1 1 1],ana.fixX,ana.fixY); drawPhotoDiode(sM,[0 0 0]);
		vbl = flip(sM); tStart = vbl;
		while vbl <= tStart + delayToChoice
			drawCross(sM,0.4,[1 1 1 1],ana.fixX,ana.fixY,[],true,0.5); drawPhotoDiode(sM,[0 0 0]);
			vbl = Screen('Flip',sM.win, vbl + halfisi);
			getSample(eL);
			if ~isFixated(eL)
				fixated = 'breakfix';
				break %break the while loop
			end
		end
		if strcmpi(fixated,'breakfix')
			drawPhotoDiode(sM,[0 0 0]);
			if ana.sendTrigger == true;sendStrobe(dPP,249);flip(sM);end
			if ana.sendTrigger == true;sendStrobe(dPP,255);flip(sM);flip(sM);end %STIM OFF
			statusMessage(eL,'Subject Broke Delay Fixation!');
			edfMessage(eL,'MSG:BreakDelayFix');
			edfMessage(eL,'TRIAL_RESULT -1');
			
			ana.runningPerformance(ana.nTotal) = -1;
			ana.nInitiateBreak = ana.nInitiateBreak + 1;
			ana.trial(ana.nTotal).success = false;
			ana.trial(ana.nTotal).xAll = eL.xAll;
			ana.trial(ana.nTotal).yAll = eL.yAll;
			
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			
			fprintf('===>>> BROKE DELAY FIXATION Trial = %i\n', seq.totalRuns);
			
			aM.beep(250,1,1);
			updatePlot(seq.totalRuns);
			WaitSecs('YieldSecs',ana.punishDelay);
			continue
		end
		
		%=========================Our actual stimulus drawing loop==========================
		
		circle1.xPositionOut = xPos;
		circle1.yPositionOut = yPos;
		
		if ana.DKL
			if thisColour == ana.colour1
				circle1.colourOut = ana.rgb1;
				circle2.colourOut = ana.rgb2b;
				circle3.colourOut = ana.rgb2c;
				circle4.colourOut = ana.rgb1b;
			else
				circle1.colourOut = ana.rgb2;
				circle2.colourOut = ana.rgb1b;
				circle3.colourOut = ana.rgb1c;
				circle4.colourOut = ana.rgb2b;
			end
		else
			%circle1.colourOut = thisColour;
		end
		
		%this allows the tracker to draw the stimulus positions
		stimulusPositions(1).x = xPos;
		stimulusPositions(1).y = yPos;
		stimulusPositions(1).size = circle1.size;
		stimulusPositions(1).selected = true;
		stimulusPositions(2).x = nvals{1}(1);
		stimulusPositions(2).y = nvals{1}(2);
		stimulusPositions(2).size = circle2.size;
		stimulusPositions(2).selected = false;
		stimulusPositions(3).x = nvals{2}(1);
		stimulusPositions(3).y = nvals{2}(2);
		stimulusPositions(3).size = circle3.size;
		stimulusPositions(3).selected = false;
		stimulusPositions(4).x = nvals{3}(1);
		stimulusPositions(4).y = nvals{3}(2);
		stimulusPositions(4).size = circle4.size;
		stimulusPositions(4).selected = false;
		
		if ana.exclusion
			exc(1,:) = [stimulusPositions(2).x - (stimulusPositions(2).size/targetFixModifier) ...
				stimulusPositions(2).x + (stimulusPositions(2).size/targetFixModifier) ...
				stimulusPositions(2).y - (stimulusPositions(2).size/targetFixModifier) ...
				stimulusPositions(2).y + (stimulusPositions(2).size/targetFixModifier)];
			exc(2,:) = [stimulusPositions(3).x - (stimulusPositions(3).size/targetFixModifier) ...
				stimulusPositions(3).x + (stimulusPositions(3).size/targetFixModifier) ...
				stimulusPositions(3).y - (stimulusPositions(3).size/targetFixModifier) ...
				stimulusPositions(3).y + (stimulusPositions(3).size/targetFixModifier)];
			exc(3,:) = [stimulusPositions(4).x - (stimulusPositions(4).size/targetFixModifier) ...
				stimulusPositions(4).x + (stimulusPositions(4).size/targetFixModifier) ...
				stimulusPositions(4).y - (stimulusPositions(4).size/targetFixModifier) ...
				stimulusPositions(4).y + (stimulusPositions(4).size/targetFixModifier)];
		else
			exc = [];
		end
		eL.exclusionZone = exc;
		
		if ana.fixinit
			eL.fixInit = struct('X',ana.fixX,'Y',ana.fixY,'time',ana.fixInitTime,'radius',ana.firstFixDiameter);
		else
			eL.fixInit = struct('X',[],'Y',[],'time',0.1,'radius',2);
		end
		eL.verbose = true;
		fprintf('===>>> Target Position = %s\n',num2str(xyPos,'%.2f '));
		edfMessage(eL,['MSG:variable=' num2str(seq.outIndex(seq.totalRuns))]);
		edfMessage(eL,['MSG:thisRun=' num2str(seq.totalRuns)]);
		edfMessage(eL,'END_FIX');
		
		% X, Y, FixInitTime, FixTime, Radius, StrictFix
		updateFixationValues(eL, xPos, yPos,...
			ana.initiateChoice, ana.maintainChoice,...
			ana.circle1Diameter/targetFixModifier, false);
		fprintf('===>>> FIX X = %d | FIX Y = %d\n',eL.fixation.X, eL.fixation.Y);
		trackerDrawStimuli(eL,stimulusPositions,true);
		trackerDrawExclusion(eL);
		trackerDrawFixation(eL);
		statusMessage(eL,'Saccade to Target...');

		if ana.sendTrigger == true;sendStrobe(dPP,seq.outIndex(seq.totalRuns));end
		drawPhotoDiode(sM,[0 0 0]);
		vbl = flip(sM);
		startTick = tick;
		tStart = vbl; if isempty(tL.vbl);tL.vbl(1) = tStart;tL.startTime = tStart; end
		while vbl < tStart + 2

			circle1.draw();
			circle2.draw();
			if ana.show34
				circle3.draw();
				circle4.draw();
			end
			drawPhotoDiode(sM,[1 1 1]);
			finishDrawing(sM);
			getSample(eL);

			[tL.vbl(tick),tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
			if tick == startTick; syncTime(eL); end
			tL.stimTime(tick) = 1;
			tL.tick = tick;
			vbl = tL.vbl(tick);
			tick = tick + 1;

			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			if strcmpi(fixated,'breakfix') 
				if ana.sendTrigger == true;sendStrobe(dPP,253);flip(sM);end %BREAK CHOICE
				fprintf('!!!>>> Exclusion = %i Fail Init = %i\n',eL.isExclusion,eL.isInitFail);
				tFix = GetSecs; tReaction =  tFix - tStart;
				break %break the while loop
			elseif strcmpi(fixated,'fix')
				tFix = GetSecs; tReaction =  tFix - tStart;
				break %break the while loop
			elseif strcmpi(fixated,'EXCLUDED!')
				tFix = GetSecs; 	tReaction =  tFix - tStart;
				fprintf('!!!>>> Exclusion = %i Fail Init = %i\n',eL.isExclusion,eL.isInitFail);
				break %break the while loop
			end
		end
		if ana.sendTrigger == true
			sendStrobe(dPP,255);
			drawPhotoDiode(sM,[0 0 0]);flip(sM);
			drawPhotoDiode(sM,[0 0 0]);flip(sM);
		end %STIM OFF

		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		end
		
		drawPhotoDiode(sM,[0 0 0]);
		[tL.vbl(tick),tL.show(tick),tL.flip(tick),tL.miss(tick)]=Screen('Flip',sM.win);
		tL.stimTime(tick) = -1;
		tL.tick = tick;
		tick = tick + 1;
		tEnd = tL.vbl(end);
		ana.trial(ana.nTotal).reactionTime = tReaction;
		ana.trial(ana.nTotal).isExclusion = eL.isExclusion;
		ana.trial(ana.nTotal).isInitFail = eL.isInitFail;
		ana.trial(ana.nTotal).xAll = eL.xAll;
		ana.trial(ana.nTotal).yAll = eL.yAll;
		
		%=========================================check if we got fixation
		if strcmpi(fixated,'fix')
			drawPhotoDiode(sM,[0 0 0]);
			if ana.sendTrigger == true;sendStrobe(dPP,251);end %CORRECT
			rM.timedTTL(2, ana.Rewardms);
			aM.beep(1000,0.1,0.2);
			trackerDrawText(eL,'CORRECT!');
			fprintf('===>>> SUCCESS: Trial = %i (total:%.3g | reaction:%.3g)\n', seq.totalRuns, tEnd-tStart, tReaction);
			
			ana.nSuccess = ana.nSuccess + 1;
			ana.runningPerformance(ana.nTotal) = 1;
			ana.trial(ana.nTotal).success = true;
			ana.trial(ana.nTotal).message = '';
			
			stopRecording(eL);
			edfMessage(eL,'TRIAL_RESULT 1');
			setOffline(eL);
			updatePlot(seq.totalRuns);
			updateTask(seq,true); %updates our current run number
			iii = seq.totalRuns;
			if ana.debug
				Screen('DrawText', sM.win, '===>>> CORRECT!!!', 0, 0);drawPhotoDiode(sM,[0 0 0]);
				flip(sM);
			end
			waitTime = 0.75;
		else
			if ana.sendTrigger == true;sendStrobe(dPP,252);end %INCORRECT
			if strcmpi(fixated,'breakfix')
				fprintf('===>>> BROKE FIXATION Trial = %i (total:%.3g | reaction:%.3g)\n', seq.totalRuns, tEnd-tStart, tReaction);
				trackerDrawText(eL,'BREAK FIX!');
				edfMessage(eL,'TRIAL_RESULT -1');
				edfMessage(eL,'MSG:BreakFix');
			elseif strcmp(fixated,'EXCLUDED!')
				excludedN = excludedN + 1;
				if eL.isInitFail
					fprintf('===>>> SACCADE TOO FAST Trial = %i > %i (total:%.3g | reaction:%.3g)\n', seq.totalRuns, excludedN, tEnd-tStart, tReaction);
					trackerDrawText(eL,'BREAK FIX (FIX INIT)!');
					edfMessage(eL,'MSG:BreakFixFixInit');
				else
					fprintf('===>>> EXCLUSION ZONE Trial = %i > %i (total:%.3g | reaction:%.3g)\n', seq.totalRuns, excludedN, tEnd-tStart, tReaction);
					trackerDrawText(eL,'BREAK FIX (EXCLUSION)!');
					edfMessage(eL,'MSG:BreakFixExclusion');
				end
				edfMessage(eL,'TRIAL_RESULT -1');
			end
			stopRecording(eL);
			setOffline(eL);
 			aM.beep(250,1,1);
			
			ana.nFixBreak = ana.nFixBreak + 1;
			ana.runningPerformance(ana.nTotal) = 0;
			ana.trial(ana.nTotal).success = false;
			
			seq.verbose = true;
			[~,message] = resetRun(seq); %randomise within block
			ana.trial(ana.nTotal).message = message;
			seq.verbose = false;
			updatePlot(seq.totalRuns);
			if ana.debug
				Screen('DrawText', sM.win, '===>>> BREAK FIX!!!', 0, 0);drawPhotoDiode(sM,[0 0 0]);
				flip(sM);
			end
			waitTime = ana.punishDelay;
			if strcmp(fixated,'EXCLUDED!')
				waitTime = waitTime + 2;
			end
		end
		
		while GetSecs < (tEnd + waitTime) && ~breakLoop
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> Train recalibrate pressed!\n');
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> Train drift correct pressed!\n');
						stopRecording(eL);
						setOffline(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'q'}
						fprintf('===>>> Train escape pressed!!!\n');
						trackerClearScreen(eL);
						stopRecording(eL);
						setOffline(eL);
						breakLoop = true;
				end
			end
			drawPhotoDiode(sM,[0 0 0]);
			[tL.vbl(tick),tL.show(tick),tL.flip(tick),tL.miss(tick)]=Screen('Flip',sM.win);
			tL.stimTime(tick) = -1;
			tL.tick = tick;
			tick = tick + 1;
		end
		
	end % while ~breakLoop
	
	%===============================Clean up============================
	fprintf('===>>> Train Finished Trials: %i\n',seq.totalRuns);
	Screen('DrawText', sM.win, '===>>> FINISHED!!!', 0, 0);
	Screen('Flip',sM.win);
	WaitSecs('YieldSecs', 1);
	close(sM); breakLoop = true;
	ListenChar(0);ShowCursor;Priority(0);
	close(aM);
	if exist('dPP','var'); close(dPP); end
	if exist(ana.ResultDir,'dir') > 0
		cd(ana.ResultDir);
	end
	trackerClearScreen(eL);
	stopRecording(eL);
	setOffline(eL);
	close(eL);
	if ~isempty(ana.nameExp)
		ana.plotAxis1 = [];
		ana.plotAxis2 = [];
		ana.plotAxis3 = [];
		fprintf('==>> SAVE DATA %s, to: %s\n', ana.nameExp, pwd);
		save([ana.nameExp '.mat'],'ana', 'seq', 'eL', 'sM', 'tL');
	end
	clear ana seq eL sM tL
	
catch ME
	if exist('eL','var'); close(eL); end
	if exist('sM','var'); close(sM); end
	if exist('aM','var'); close(aM); end
	ListenChar(0);ShowCursor;Priority(0);Screen('CloseAll');
	getReport(ME)
end

	function updatePlot(thisTrial)
		c = categorical({'BreakInit','BreakFix','Success'});
		bar(ana.plotAxis1,c,[ana.nInitiateBreak, ana.nFixBreak, ana.nSuccess]);
		
		p1 = 100 * (ana.nSuccess / (ana.nSuccess + ana.nInitiateBreak + ana.nFixBreak));
		p2 = 100 * (ana.nSuccess / (ana.nSuccess + ana.nFixBreak));
		if isinf(p1);p1 = 1; end; if isinf(p2);p2 = 1; end
		plotVals.t1(end+1) = thisTrial;
		plotVals.p1(end+1) = p1;
		plotVals.p2(end+1) = p2;
		plot(ana.plotAxis2,plotVals.t1,plotVals.p1,'go-');
		hold(ana.plotAxis2,'on');
		plot(ana.plotAxis2,plotVals.t1,plotVals.p2,'ko-','MarkerFaceColor',[1,0,0]);
		hold(ana.plotAxis2,'off');
		ylim(ana.plotAxis2,[0 100]);
		
		if ana.nTotal >= 10
			recentList = ana.runningPerformance(end-9:end);
			bI = sum(recentList == -1);
			bF = sum(recentList == 0);
			cT = sum(recentList == 1);
			performance = 100 * ( cT / (cT+bF+bI) );
			plotVals.t2(end+1) = ana.nTotal;
			plotVals.p3(end+1) = performance;
			plot(ana.plotAxis3,plotVals.t2,plotVals.p3,'ko-','MarkerFaceColor',[1,0,0]);
			ylim(ana.plotAxis3,[0 100]);
		end
		
		if ~isempty(ana.trial(ana.nTotal).xAll)
			plot(ana.plotAxis4,ana.trial(ana.nTotal).xAll,ana.trial(ana.nTotal).yAll,'k-');
			hold(ana.plotAxis4,'on');
			plot(ana.plotAxis4,ana.trial(ana.nTotal).xAll(1),ana.trial(ana.nTotal).yAll(1),'go');
			plot(ana.plotAxis4,ana.trial(ana.nTotal).xAll(end),ana.trial(ana.nTotal).yAll(end),'bo');
			xlim(ana.plotAxis4,[-12 12]);
			ylim(ana.plotAxis4,[-12 12]);
		end
		
		drawnow limitrate nocallbacks
	end

end
