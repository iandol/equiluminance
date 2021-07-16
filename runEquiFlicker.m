function runEquiFlicker(ana)
fprintf('\n\n--->>> runEquiFlicker Started: UUID = %s!\n',ana.uuid);

%============================use reward system?======================================
global rM
if ana.sendReward
	if ~exist('rM','var') || isempty(rM)
		 rM = arduinoManager;
	end
	open(rM) %open our reward manager
end

%=================================general bits=======================================
%if ispc; PsychJavaTrouble(); end
KbName('UnifyKeyNames');
PsychDefaultSetup(2);
%==========================Initiate out metadata=====================================
ana.date		= datestr(datetime);
ana.version		= Screen('Version');
ana.computer	= Screen('Computer');
ana.gpu			= opengl('data');

%==========================experiment parameters=====================================
if ana.debug
	ana.screenID = 0;
	ana.windowed = [0 0 1000 1000];
	ana.bitDepth = '8bit';
else
	ana.screenID = max(Screen('Screens'));%-1;
end

%=======================Make a name for this run=====================================
pf='EquiFlicker_';
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
drawnow;

try
	%=======================open our screen==========================================
	sM = screenManager();
	if ana.debug || ismac || ispc || ~isempty(regexpi(ana.gpu.Vendor,'NVIDIA','ONCE'))
		sM.disableSyncTests = true; 
	end
	sM.screen		= ana.screenID;
	sM.debug		= ana.debug;
	sM.windowed		= ana.windowed;
	sM.pixelsPerCm	= ana.pixelsPerCm;
	sM.distance		= ana.distance;
	sM.photoDiode	= true;
	sM.blend		= true;
	sM.bitDepth		= ana.bitDepth;
	sM.verbosityLevel = 4;
	if exist(ana.gammaTable, 'file')
		load(ana.gammaTable);
		if isa(c,'calibrateLuminance')
			sM.gammaTable = c;
		end
		clear c;
		if ana.debug
			sM.gammaTable.plot
		end
	end
	sM.backgroundColour = ana.backgroundColor;
	screenVals		= sM.open; % OPEN THE SCREEN
	ana.gpuInfo		= Screen('GetWindowInfo',sM.win);
	ana.screenVals	= screenVals;
	fprintf('\n--->>> runEquiFlicker Opened Screen %i : %s\n', sM.win, sM.fullName);
	disp(screenVals);
	
	if IsLinux
		Screen('Preference', 'TextRenderer', 1);
		Screen('Preference', 'DefaultFontName', 'Liberation Sans');
	end
	
	%===========================SETUP STIMULI========================================
	grating				= colourGratingStimulus();
	grating.size		= ana.size;
	grating.colour		= ana.colorFixed;
	grating.colour2		= ana.colorStart;
	grating.contrast	= 1;
	grating.type		= ana.type;
	grating.mask		= ana.mask;
	grating.tf			= 0;
	grating.sf			= ana.sf;
	
	setup(grating,sM); 
		
	%============================SETUP VARIABLES=====================================
	varC			= find(ana.colorEnd == max(ana.colorEnd));
	varC			= varC(1);
	varColour		= grating.colour2;
	
	%==============================SETUP EYELINK=====================================
	ana.strictFixation = false;
	eL = eyelinkManager();
	fprintf('--->>> runEquiFlicker eL setup starting: %s\n', eL.fullName);
	eL.isDummy = ana.isDummy; %use dummy or real eyelink?
	eL.name = ana.nameExp;
	eL.saveFile = [ana.nameExp '.edf'];
	eL.recordData = true; %save EDF file
	eL.sampleRate = ana.sampleRate;
	eL.remoteCalibration = false; % manual calibration?
	eL.calibrationProportion = [0.5 0.5];
	eL.calibrationStyle = ana.calibrationStyle; % calibration style
	eL.modify.calibrationtargetcolour = [1 1 1];
	eL.modify.calibrationtargetsize = 1.75;
	eL.modify.calibrationtargetwidth = 0.03;
	eL.modify.waitformodereadytime = 500;
	eL.modify.devicenumber = -1; % -1 = use any keyboard
	% X, Y, FixInitTime, FixTime, Radius, StrictFix
	updateFixationValues(eL, ana.fixX, ana.fixY, ana.firstFixInit,...
		ana.firstFixTime, ana.firstFixDiameter, ana.strictFixation);
	%sM.verbose = true; eL.verbose = true; sM.verbosityLevel = 10; eL.verbosityLevel = 4; %force lots of log output
	initialise(eL, sM); %use sM to pass screen values to eyelink
	setup(eL); % do setup and calibration
	fprintf('--->>> runEquiFlicker eL setup complete: %s\n', eL.fullName);
	WaitSecs('YieldSecs',0.5);
	getSample(eL); %make sure everything is in memory etc.
	
	%================================================================================
	%-------------prepare variables needed for task loop-----------------------------
	NO = 1; YES = 2; UNSURE = 3; REDO = -10; BREAKFIX = -1;
	tL				= timeLogger();
	tL.screenLog.beforeDisplay = GetSecs();
	tL.screenLog.stimTime(1) = 1;
	breakLoop		= false;
	ana.trial		= struct();
	ana.onFrames	= round((ana.screenVals.fps/ana.frequency));
	thisTrial		= 0;
	tick			= 1;
	fInc			= 6;
	response		= BREAKFIX;
	nresponse		= 0;
	halfisi			= sM.screenVals.halfisi;
	commandwindow
	if ~ana.debug; ListenChar(-1); end
	Priority(MaxPriority(sM.win));
	colours = {};
	
	%================================================================================
	%-------------------------------------TASK LOOP----------------------------------
	while breakLoop == false
		thisTrial = thisTrial + 1;
		%=================Define stimulus colours for this run=======================
		if mod(thisTrial, 2) == 0
			grating.colour2Out = [ana.colorStart(1:3) 1]; 
		else
			grating.colour2Out = [ana.colorEnd(1:3) 1]; 
		end
		varColour = grating.colour2Out;
		update(grating);
		fprintf('===>>> FIX=%s | MOD=%s\n',num2str(grating.colourOut(1:3)),num2str(grating.colour2Out(1:3)));
		
		%======================prepare eyelink for this trial ==============
		resetFixation(eL);
		trackerClearScreen(eL);
		trackerDrawFixation(eL); %draw fixation window on eyelink computer
		trackerMessage(eL,'V_RT MESSAGE END_FIX END_RT');  %this 3 lines set the trial info for the eyelink
		trackerMessage(eL,['TRIALID ' thisTrial]);  %obj.getTaskIndex gives us which trial we're at
		startRecording(eL);
		statusMessage(eL,'INITIATE FIXATION...');
		fixated = '';
		
		%=======================Prepare for the stimulus loop========================
		vbl		= Screen('Flip',sM.win);
		tFix	= vbl;
		%================================initiate fixation===========================
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
			drawCross(sM, 0.75, [1 1 1 1], ana.fixX, ana.fixY, 0.1, true, 0.5);
			finishDrawing(sM);
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			[tL.vbl(tick), tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
            tL.stimTime(tick) = 0;
			tick = tick + 1;
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown
				rchar = KbName(keyCode);
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> runEquiFlicker recalibrate pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs', 1);
					case {'d'}
						fprintf('===>>> runEquiFlicker drift correct pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs', 1);
					case {'q'}
						fprintf('===>>> runEquiFlicker Q pressed!!!\n');
						fixated = 'breakfix';
						breakLoop = true;
				end
			end
		end
		
		if strcmpi(fixated,'breakfix')
			fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', thisTrial);
			statusMessage(eL,'Subject Broke Initial Fixation!');
			trackerMessage(eL,'MSG:BreakInitialFix');
			response = BREAKFIX;
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
            Screen('Flip',sM.win); %flip the buffer
			WaitSecs('YieldSecs',0.2);
			continue
		end
		
		statusMessage(eL,'Show Stimulus...');
		%=======================Our actual stimulus drawing loop=====================
		startTick = tick; keepRunning = true; stroke = 1; ii = 1; keyTicks = 0; keyHold = 0;
		tStart = GetSecs; vbl = tStart;if isempty(tL.vbl);tL.vbl(1) = tStart;tL.startTime = tStart; end
		while keepRunning
			switch stroke
				case 1
					grating.driftPhase = 0; %see Cavanagh 1987 Fig. 1,darker red=left
					draw(grating)
				case 2
					grating.driftPhase = 180;
					draw(grating)
			end
			if mod(tick,ana.onFrames) == 0 
				stroke = stroke + 1;
				if stroke > 2; stroke = 1; end
			end

			drawCross(sM, 0.75, [1 1 1 1], ana.fixX, ana.fixY, 0.1, true, 0.2);
			finishDrawing(sM);
			
			[vbl, tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
			if tick == startTick; trackerMessage(eL,'END_FIX'); end
			tL.vbl(tick) = vbl; tL.stimTime(tick) =  1 + (stroke/10);
			tick = tick + 1; 
			ii = ii + 1;

			keyTicks = keyTicks + 1;
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
			if keyIsDown
				switch lower(rchar)
					case {'downarrow','down'}
						if keyTicks > keyHold
							varColour(varC) = varColour(varC) - 0.005;
							if varColour(varC) < 0; varColour(varC) = 0; end
							grating.colour2Out = varColour; 
							update(grating);
							fprintf('Variable Colour is: %s\n',num2str(grating.colour2Out,'%.3f '));
							keyHold = keyTicks + fInc;
						end
					case {'uparrow','up'}
						if keyTicks > keyHold
							varColour(varC) = varColour(varC) + 0.005;
							if varColour(varC) > 1; varColour(varC) = 1; end
							grating.colour2Out = varColour; 
							update(grating);
							fprintf('Variable Colour is: %s\n',num2str(grating.colour2Out,'%.3f '));
							keyHold = keyTicks + fInc;
						end
					case {'space'}
						keepRunning = false;
						response = YES;
					case {'c'}
						fprintf('===>>> runEquiFlicker recalibrate pressed!\n');
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						keepRunning = false;
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> runEquiFlicker drift correct pressed!\n');
						stopRecording(eL);
						driftCorrection(eL);
						keepRunning = false;
						WaitSecs('YieldSecs',2);
					case {'q'}
						fprintf('===>>> runEquiFlicker Q pressed!!!\n');
						fixated = 'breakfix';
						breakLoop = true;
						keepRunning = false; 
				end
			end
		end
		%============================================================================
		
		tEnd=Screen('Flip',sM.win);
		
		if strcmp(fixated,'breakfix')
			fprintf('===>>> BROKE FIXATION Trial = %i (%i secs)\n\n', thisTrial, tEnd-tStart);
			response = BREAKFIX;
		end
		
		if response == YES
			nresponse = nresponse + 1;
			colours{end+1,1} = grating.colour2Out;
			disp(cell2mat(colours));
			disp(['Isoluminant flicker point = ' num2str(mean(cell2mat(colours)))]);
		end
		
		trackerMessage(eL,['TRIAL_RESULT ' response]);
		trackerMessage(eL,'MSG:BreakFix');
		resetFixation(eL);
		stopRecording(eL);
		setOffline(eL);
		
		tL.tick = tick;
		
		if nresponse >= ana.trialNumber 
			breakLoop = true; 
		else
			WaitSecs('YieldSecs',ana.trialInterval);
		end
		
	end % while ~breakLoop
	
	%===============================Clean up============================
	Screen('DrawText', sM.win, '===>>> FINISHED!!!',50,50);
	Screen('Flip',sM.win);
	WaitSecs('YieldSecs', 2);
	reset(grating);
	close(sM); breakLoop = true;
	ListenChar(0);ShowCursor;Priority(0);RestrictKeysForKbCheck([]);
	
	
	disp(colours);
	disp(['Isoluminant flicker point = ' num2str(mean(cell2mat(colours)))]);
	fprintf('===>>> runEquiFlicker Finished Trials: %i\n',thisTrial);
	
	if exist(ana.ResultDir,'dir') > 0
		cd(ana.ResultDir);
	end
	trackerClearScreen(eL);
	stopRecording(eL);
	setOffline(eL);
	close(eL);
	if ~isempty(ana.nameExp) || ~strcmpi(ana.nameExp,'debug')
		ana.colours = colours;
		ana.plotAxis1 = [];
		ana.plotAxis2 = [];
		ana.plotAxis3 = [];
		fprintf('==>> SAVE %s, to: %s\n', ana.nameExp, pwd);
		save([ana.nameExp '.mat'],'ana', 'eL', 'sM', 'tL', 'colours');
	end
	tL.printRunLog;
	clear ana eL sM tL
catch ME
	if exist('eL','var'); close(eL); end
	if exist('grating','var');reset(grating);end
	if exist('sM','var'); close(sM); end
	ListenChar(0);ShowCursor;Priority(0);Screen('CloseAll');RestrictKeysForKbCheck([]);
	getReport(ME)
end

	
	%==================================================================updateResponse
	function updateResponse
		switch response
			case {1, 2, 3}
				
			case -10
				
		end
	end

	%==================================================================updatePlot
	function updatePlot(thisTrial)
		
	end


	%==================================================================findNearest
	function [idx,val,delta]=findNearest(in,value)
		%find nearest value in a vector, if more than 1 index return the first	
		[~,idx] = min(abs(in - value));
		val = in(idx);
		delta = abs(value - val);
	end
		
end
