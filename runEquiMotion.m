function runEquiMotion(ana)
fprintf('\n\n--->>> runEquiMotion Started: UUID = %s!\n',ana.uuid);

%============================use reward system?======================================
global rM
if ana.sendReward
	if ~exist('rM','var') || isempty(rM)
		 rM = arduinoManager;
	end
	open(rM) %open our reward manager
end

%===========================compatibility for windows================================
%if ispc; PsychJavaTrouble(); end
KbName('UnifyKeyNames');
%==========================Initiate out metadata=====================================
ana.date		= datestr(datetime);
ana.version		= Screen('Version');
ana.computer	= Screen('Computer');
ana.gpu			= opengl('data');
ana.colours		= {};

%==========================experiment parameters=====================================
if ana.debug
	ana.screenID = 0;
	ana.windowed = [0 0 1600 1000];
	ana.bitDepth = '8bit';
else
	ana.screenID = max(Screen('Screens'));%-1;
end

%=======================Make a name for this run=====================================
pf='EquiMotion_';
if ~ana.isMOC; pf = [pf 'Match_']; end
if ~isempty(ana.subject)
	nameExp			= [pf ana.subject];
	c				= sprintf(' %i',fix(clock()));
	nameExp			= [nameExp c];
	ana.nameExp		= regexprep(nameExp,' ','_');
else
	ana.nameExp		= 'debug';
end

cla(ana.plotAxis1);
cla(ana.plotAxis2);
cla(ana.plotAxis3);
drawnow;

try
	%=======================open our screen==========================================
	PsychDefaultSetup(2);
	sM = screenManager();
	if ana.debug || ismac || ispc || ~isempty(regexpi(ana.gpu.Vendor,'NVIDIA','ONCE'))
		sM.disableSyncTests = true; 
	end
	sM.screen = ana.screenID;
	sM.windowed = ana.windowed;
	sM.pixelsPerCm = ana.pixelsPerCm;
	sM.distance = ana.distance;
	sM.photoDiode = true;
	sM.debug = ana.debug;
	sM.blend = true;
	sM.bitDepth = ana.bitDepth;
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
	screenVals = sM.open; % OPEN THE SCREEN
	ana.gpuInfo		= Screen('GetWindowInfo',sM.win);
	ana.screenVals = screenVals;
	fprintf('\n--->>> runEquiMotion Opened Screen %i : %s\n', sM.win, sM.fullName);
	disp(screenVals);
	
	if IsLinux
		Screen('Preference', 'TextRenderer', 1);
		Screen('Preference', 'DefaultFontName', 'DejaVu Serif');
	end
	
	%===========================SETUP STIMULI========================================
	grating1			= colourGratingStimulus;
	grating1.size		= ana.size;
	grating1.colour		= ana.colorFixed;
	grating1.colour2	= ana.colorStart;
	grating1.contrast	= 1;
	grating1.type		= ana.type;
	grating1.mask		= ana.mask;
	grating1.tf			= 0;
	grating1.sf			= ana.sf;
	
	ana.offsetBlend	= true;
	if ana.offsetBlend
		blend = (ana.colorFixed + ana.colorStart) / 2;
	else
		blend = (ana.colorFixed + ( (ana.colorStart + ana.colorEnd) / 2 ) ) / 2;
	end
	grating2			= colourGratingStimulus;
	grating2.size		= ana.size;
	grating2.colour		= (1+ana.contrastMultiplier) * blend;
	grating2.colour2	= (1-ana.contrastMultiplier) * blend;
	grating2.colour		= [grating2.colour(1:3) 1]; 
	grating2.colour2	= [grating2.colour2(1:3) 1];
	grating2.contrast	= 1;
	grating2.type		= ana.type;
	grating2.mask		= ana.mask;
	grating2.tf			= 0;
	grating2.sf			= ana.sf;
	
	setup(grating1,sM); setup(grating2,sM);
	
	%============================SETUP VARIABLES=====================================
	len = 0;
	r = cell(3,1);
	for i = 1:length(r)
		step = (ana.colorEnd(i) - ana.colorStart(i)) / (ana.colorStep-1);
		r{i} = [ana.colorStart(i) : step : ana.colorEnd(i)]';
		if length(r{i}) > len; len = length(r{i}); end
	end
	for i = 1:length(r)
		if isempty(r{i})
			r{i} = zeros(len,1);
		end
	end
	vals = cell(len,1);
	for i = 1:len
		vals{i} = [r{1}(i) r{2}(i) r{3}(i)];
	end
	fixC = find(ana.colorFixed == max(ana.colorFixed));
	switch fixC
		case 1
			fixLabel='Red';
		case 2
			fixLabel='Green';
		case 3
			fixLabel='Blue';
	end
	fixV			= ana.colorFixed(fixC); 
	varC			= find(ana.colorEnd == max(ana.colorEnd));
	varC			= varC(1);
	varColour		= grating1.colour;
	variableVals	= r{ana.colorEnd > 0}'; ana.variableVals = variableVals;
	responseVals	= zeros(size(variableVals));
	totalVals		= responseVals;
	varLabels		= arrayfun(@(a) num2str(a,3),variableVals,'UniformOutput',false);
	
	% to plot the psychometric function
	PF				= @PAL_Weibull;
	space.alpha		= linspace(min(variableVals), max(variableVals), 100);
	space.beta		= linspace(1, 100, 100);
	space.gamma		= 0;
	space.lambda	= 0.02;
	pfx				= linspace(min(variableVals),max(variableVals),100);
	
	%============================SETUP SEQUENCE======================================
	seq					= stimulusSequence;
	seq.nVar(1).name	= 'colour';
	seq.nVar(1).stimulus = 1;
	seq.nVar(1).values	= vals;
	seq.nBlocks			= ana.trialNumber;
	seq.initialise();
	ana.nTrials			= seq.nRuns;
	ana.onFrames		= round(((1/ana.frequency) * sM.screenVals.fps) / 4); % video frames for each color
	fprintf('--->>> runEquiMotion # Trials: %i; # Freq/frames: %i:%i; FPS: %i \n',seq.nRuns, ana.frequency, ana.onFrames, sM.screenVals.fps);
	
	%==============================SETUP EYELINK=====================================
	ana.strictFixation = true;
	eL = eyelinkManager('IP',[]);
	fprintf('--->>> runEquiMotion eL setup starting: %s\n', eL.fullName);
	eL.isDummy = ana.isDummy; %use dummy or real eyelink?
	eL.name = ana.nameExp;
	eL.saveFile = [ana.nameExp '.edf'];
	eL.recordData = true; %save EDF file
	eL.sampleRate = ana.sampleRate;
	eL.remoteCalibration = false; % manual calibration?
	eL.calibrationStyle = ana.calibrationStyle; % calibration style
	eL.modify.calibrationtargetcolour = [1 1 1];
	eL.modify.calibrationtargetsize = 1.75;
	eL.modify.calibrationtargetwidth = 0.1;
	eL.modify.waitformodereadytime = 500;
	eL.modify.devicenumber = -1; % -1 = use any keyboard
	% X, Y, FixInitTime, FixTime, Radius, StrictFix
	updateFixationValues(eL, ana.fixX, ana.fixY, ana.firstFixInit,...
		ana.firstFixTime, ana.firstFixDiameter, ana.strictFixation);
	%sM.verbose = true; eL.verbose = true; sM.verbosityLevel = 10; eL.verbosityLevel = 4; %force lots of log output
	initialise(eL, sM); %use sM to pass screen values to eyelink
	ListenChar(-1); setup(eL); ListenChar(0); % do setup and calibration
	fprintf('--->>> runEquiMotion eL setup complete: %s\n', eL.fullName);
	WaitSecs('YieldSecs',0.5);
	getSample(eL); %make sure everything is in memory etc.
	
	%================================================================================
	%-------------prepare variables needed for task loop-----------------------------
	LEFT = 1; 	RIGHT = 2; UNSURE = 3; YES = 4; REDO = -10; BREAKFIX = -1; INVALID = -100;
	map				= analysisCore.optimalColours(seq.minBlocks);	
	tL				= timeLogger();
	tL.screenLog.beforeDisplay = GetSecs();
	tL.screenLog.stimTime(1) = 1;
	breakLoop		= false;
	ana.trial		= struct();
	ana.leftCount	= 0;
	ana.rightCount	= 0;
	ana.unsureCount = 0;
	tick			= 1;
	nresponse		= 0;
	colours			= {};
	keyHold			= 0;
	keyTicks		= keyHold;
	fInc			= 5;
	halfisi			= sM.screenVals.halfisi;
	if ~ana.debug; ListenChar(-1); end
	Priority(MaxPriority(sM.win));
	
	%================================================================================
	%-------------------------------------TASK LOOP----------------------------------
	while breakLoop == false
	
		%=================Define stimulus colours for this run=======================
		fprintf('\n===>>> runEquiMotion START Run = %i / %i (%i:%i) | %s, %s\n', seq.totalRuns, seq.nRuns, seq.thisBlock, seq.thisRun, sM.fullName, eL.fullName);
		modColor			= [seq.outValues{seq.totalRuns}(1:3) 1];
		fixedColor			= [ana.colorFixed(1:3) 1];
		grating1.colourOut	= modColor;
		grating1.colour2Out = fixedColor;
		grating2.colourOut	= ((1+ana.contrastMultiplier) * (fixedColor + modColor)) / 2.0; 
		grating2.colourOut	= [grating2.colourOut(1:3) 1];
		grating2.colour2Out = ((1-ana.contrastMultiplier) * (fixedColor + modColor)) / 2.0; 
		grating2.colour2Out = [grating2.colour2Out(1:3) 1];
		varColour			= grating1.colourOut;
		update(grating1); update(grating2);
		fprintf('===>>> MOD=%s | FIX=%s\n',num2str(grating1.colourOut(1:3), '%.2f '),num2str(grating1.colour2Out(1:3),'%.2f'));
		fprintf('===>>> B=%s | D=%s\n',num2str(grating2.colourOut(1:3),'%.2f'),num2str(grating2.colour2Out(1:3),'%.2f'));
		
		%======================prepare eyelink for this trial ==============
		resetFixation(eL);
		trackerClearScreen(eL);
		trackerDrawFixation(eL); %draw fixation window on eyelink computer
		trackerMessage(eL,'V_RT MESSAGE END_FIX END_RT');  %this 3 lines set the trial info for the eyelink
		trackerMessage(eL,['TRIALID ' num2str(seq.outIndex(seq.totalRuns))]);  %obj.getTaskIndex gives us which trial we're at
		trackerMessage(eL,['MSG:fixColor=' num2str(fixedColor)]);
		trackerMessage(eL,['MSG:modColor=' num2str(modColor)]);
		trackerMessage(eL,['MSG:variable=' num2str(seq.outIndex(seq.totalRuns))]);
		trackerMessage(eL,['MSG:totalRuns=' num2str(seq.totalRuns)]);
		startRecording(eL);
		statusMessage(eL,'INITIATE FIXATION...');
		fixated = '';
		
		%=======================Prepare for the stimulus loop========================
		response				= INVALID;
		ii						= 1;
		stroke					= 1; %motion is 4-stroke start at stroke 1
		tr						= seq.totalRuns;
		ana.trial(tr).n			= tr;
		ana.trial(tr).variable	= seq.outIndex(tr);
		ana.trial(tr).value		= variableVals(ana.trial(tr).variable);
		ana.trial(tr).mColor	= grating1.colour;
		ana.trial(tr).fColor	= grating1.colour2;
		ana.trial(tr).blendColor1 = grating2.colour;
		ana.trial(tr).blendColor2 = grating2.colour2;
		ana.trial(tr).pupil		= [];
		ana.trial(tr).frameN	= [];
		vbl						= Screen('Flip',sM.win);
		%================================initiate fixation===========================
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix') && breakLoop == false
			drawCross(sM, 0.75, [1 1 1 1], ana.fixX, ana.fixY, 0.1, true,0.2);
            drawPhotoDiode(sM,[0 0 0 1]);
			finishDrawing(sM);
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			%flip(sM); %flip the buffer
			[tL.vbl(tick), tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
            tL.stimTime(tick) = 0;
			tick = tick + 1;
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown
				rchar = KbName(keyCode);
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> runEquiMotion recalibrate pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs', 1);
					case {'d'}
						fprintf('===>>> runEquiMotion drift correct pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs', 1);
					case {'q'}
						fprintf('===>>> runEquiMotion Q pressed!!!\n');
						fixated = 'breakfix';
						breakLoop = true;
				end
			end
		end
		if strcmpi(fixated,'breakfix')
			fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', seq.totalRuns);
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
		startTick = tick; 
		keepRunning = true;
		ii = 1;
		tStart = GetSecs;
		vbl = tStart;
		if isempty(tL.vbl);tL.vbl(1) = tStart;tL.startTime = tStart; end
		while keepRunning
			switch stroke
				case 1
					grating1.driftPhase = 180; %see Cavanagh 1987 Fig. 1,darker red=left
					draw(grating1)
				case 2
					grating2.driftPhase = 270;
					draw(grating2)
				case 3
					grating1.driftPhase = 0;
					draw(grating1)
				case 4
					grating2.driftPhase = 90;
					draw(grating2)
			end
			if mod(ii,ana.onFrames) == 0 
				stroke = stroke + 1;
				if stroke > 4; stroke = 1; end
			end

			drawCross(sM, 0.75, [1 1 1 1], ana.fixX, ana.fixY, 0.1, true,0.2);
            drawPhotoDiode(sM,[1 1 1 1]);
			finishDrawing(sM);
			
			[vbl, tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
			if tick == startTick; trackerMessage(eL,'END_FIX'); end
			tL.vbl(tick) = vbl; tL.stimTime(tick) = 1 + (stroke/10);
			tick = tick + 1;
			ii = ii + 1;
			
			if ana.isMOC
				getSample(eL);
				if ~isFixated(eL)
					fixated = 'breakfix';
					break %break the while loop
				end
				keepRunning = vbl < tStart + ana.trialDuration;
			else
				matchingKeys();
			end
			
		end
		%============================================================================
		
		tEnd=Screen('Flip',sM.win);
		
		if strcmp(fixated,'breakfix')
			fprintf('===>>> BROKE FIXATION Trial = %i (%i secs)\n\n', seq.totalRuns, tEnd-tStart);
			response = BREAKFIX;
			statusMessage(eL,'Subject Broke Fixation!');
			trackerMessage(eL,['TRIAL_RESULT ' response]);
			trackerMessage(eL,'MSG:BreakFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			continue;
		end
		
		tL.tick = tick;
		ana.trial(seq.totalRuns).totalFrames = ii-1;
		
		if ana.isMOC
			getResponse();
			updateResponse();
			if seq.taskFinished == true; breakLoop = true; end
		else
			updateResponse();
			ana.colours = colours;
			if nresponse >= ana.trialNumber 
				breakLoop = true;
			end
		end
		
	end % while ~breakLoop
	
	%===============================Clean up============================
	fprintf('===>>> runEquiMotion Finished Trials: %i\n',seq.totalRuns);
	Screen('DrawText', sM.win, '===>>> FINISHED!!!',50,50);
	Screen('Flip',sM.win);
	WaitSecs('YieldSecs', 2);
	reset(grating1);reset(grating2);
	close(sM); breakLoop = true;
	ListenChar(0);ShowCursor;Priority(0);RestrictKeysForKbCheck([]);
	
	if exist(ana.ResultDir,'dir') > 0
		cd(ana.ResultDir);
	end
	trackerClearScreen(eL);
	stopRecording(eL);
	setOffline(eL);
	close(eL);
	if ~isempty(ana.nameExp) || ~strcmpi(ana.nameExp,'debug')
		ana.plotAxis1 = [];
		ana.plotAxis2 = [];
		ana.plotAxis3 = [];
		fprintf('==>> SAVE %s, to: %s\n', ana.nameExp, pwd);
		save([ana.nameExp '.mat'],'ana', 'seq', 'eL', 'sM', 'tL');
	end
	tL.printRunLog;
	clear ana seq eL sM tL

catch ME
	if exist('eL','var'); close(eL); end
	reset(grating1);reset(grating2);
	if exist('sM','var'); close(sM); end
	ListenChar(0);ShowCursor;Priority(0);Screen('CloseAll');
	getReport(ME)
end

	function matchingKeys()
		keyTicks = keyTicks + 1;
		[keyIsDown, ~, keyCode] = KbCheck(-1);
		rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
		if keyIsDown
			switch lower(rchar)
				case {'downarrow','down'}
					if keyTicks > keyHold
						varColour(varC) = varColour(varC) - 0.01;
						if varColour(varC) < 0; varColour(varC) = 0; end
						grating1.colourOut = varColour; 
						grating2.colourOut	= ((1+ana.contrastMultiplier) * (grating1.colour2Out + grating1.colourOut)) / 2.0; 
						grating2.colourOut	= [grating2.colourOut(1:3) 1];
						grating2.colour2Out = ((1-ana.contrastMultiplier) * (grating1.colour2Out + grating1.colourOut)) / 2.0; 
						grating2.colour2Out = [grating2.colour2Out(1:3) 1];
						update(grating1); update(grating2)
						fprintf('Variable Colour is: %s; Mod Colour is: %s %s\n',...
							num2str(grating1.colourOut,'%.3f '), num2str(grating2.colourOut,'%.3f '), num2str(grating2.colour2Out,'%.3f '));
						keyHold = keyTicks + fInc;
					end
				case {'uparrow','up'}
					if keyTicks > keyHold
						varColour(varC) = varColour(varC) + 0.01;
						if varColour(varC) > 1; varColour(varC) = 1; end
						grating1.colourOut = varColour; 
						grating2.colourOut	= ((1+ana.contrastMultiplier) * (grating1.colour2Out + grating1.colourOut)) / 2.0; 
						grating2.colourOut	= [grating2.colourOut(1:3) 1];
						grating2.colour2Out = ((1-ana.contrastMultiplier) * (grating1.colour2Out + grating1.colourOut)) / 2.0; 
						grating2.colour2Out = [grating2.colour2Out(1:3) 1];
						update(grating1); update(grating2)
						fprintf('Variable Colour is: %s; Mod Colour is: %s %s\n',...
							num2str(grating1.colourOut,'%.3f '), num2str(grating2.colourOut,'%.3f '), num2str(grating2.colour2Out,'%.3f '));
						keyHold = keyTicks + fInc;
					end
				case {'space'}
					keepRunning = false;
					response = YES;
				case {'c'}
					fprintf('===>>> runEquiFlicker recalibrate pressed!\n');
					response = INVALID;
					stopRecording(eL);
					setOffline(eL);
					trackerSetup(eL);
					keepRunning = false;
					WaitSecs('YieldSecs',2);
				case {'d'}
					fprintf('===>>> runEquiFlicker drift correct pressed!\n');
					response = INVALID;
					stopRecording(eL);
					driftCorrection(eL);
					keepRunning = false;
					WaitSecs('YieldSecs',2);
				case {'q'}
					fprintf('===>>> runEquiFlicker Q pressed!!!\n');
					response = INVALID;
					fixated = 'breakfix';
					breakLoop = true;
					keepRunning = false; 
			end
		end
	end

	function getResponse()
		drawPhotoDiode(sM,[0 0 0 1]);
		DrawFormattedText2(['Which Direction (press arrow button)?:\n  [<b>LEFT<b>] = LEFT MOTION'...
			'\n  [<b>RIGHT<b>]=RIGHT MOTION \n  [<b>UP<b>]=REDO'],...
			'win',sM.win,'sx','center','sy','center','xalign','center','yalign','center');
		Screen('Flip',sM.win);
		statusMessage(eL,'Waiting for Subject Response!');
		edfMessage(eL,'Subject Responding')
		edfMessage(eL,'END_RT'); 
		response = -1;
		[~, keyCode] = KbWait(-1);
		rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
		switch lower(rchar)
			case {'leftarrow','left'}
				response = LEFT;
				trackerDrawText(eL,'Subject Pressed LEFT!');
				edfMessage(eL,'Subject Pressed LEFT');
				fprintf('Response: LEFT\n');
			case {'rightarrow','right'}
				response = RIGHT;
				trackerDrawText(eL,'Subject Pressed RIGHT!');
				edfMessage(eL,'Subject Pressed RIGHT')
				fprintf('Response: RIGHT\n');
% 			case {'downarrow','down'}
% 				response = UNSURE;
% 				updateResponse();
% 				trackerDrawText(eL,'Subject Pressed UNSURE!');
% 				edfMessage(eL,'Subject Pressed UNSURE')
% 				fprintf('Response: UNSURE\n');
			case {'downarrow','down','uparrow','up'}
				response = REDO;
				trackerDrawText(eL,'Subject Pressed REDO!');
				edfMessage(eL,'Subject Pressed REDO')
				fprintf('Response: REDO\n');
			case {'c'}
				fprintf('===>>> runEquiMotion recalibrate pressed!\n');
				response = INVALID;
				stopRecording(eL);
				setOffline(eL);
				trackerSetup(eL);
				WaitSecs('YieldSecs',2);
			case {'d'}
				fprintf('===>>> runEquiMotion drift correct pressed!\n');
				response = INVALID;
				stopRecording(eL);
				driftCorrection(eL);
				WaitSecs('YieldSecs',2);
			case {'q'}
				fprintf('===>>> runEquiMotion quit pressed!!!\n');
				response = INVALID;
				trackerClearScreen(eL);
				stopRecording(eL);
				setOffline(eL);
				breakLoop = true;
		end
		drawPhotoDiode(sM,[0 0 0 1]);flip(sM);
		WaitSecs('YieldSecs',ana.trialInterval);
	end
	
	%==================================================================updateResponse
	function updateResponse()
		switch response
			case {1, 2, 3, 4}
				fprintf('===>>> SUCCESS: Trial = %i, response = %i (%.2f secs)\n\n', seq.totalRuns, response, tEnd-tStart);
				if ana.sendReward; rM.timedTTL(2,150); end
				edfMessage(eL,['TRIAL_RESULT ' num2str(response)]);
				if ana.isMOC
					ana.trial(seq.totalRuns).success = true;
					ana.trial(seq.totalRuns).response = response;
					v=ana.trial(seq.totalRuns).variable;
					totalVals(v) = totalVals(v) + 1;
					if response == LEFT
						isLeft = 1;
						ana.leftCount = ana.leftCount + 1;
						responseVals(v) = responseVals(v) + 1;
					elseif response == RIGHT
						isLeft = 0;
						ana.rightCount = ana.rightCount + 1;
					elseif response == UNSURE
						isLeft = 0;
						ana.unsureCount = ana.unsureCount + 1;
					elseif response == REDO
						isLeft = 0;
					end
					ana.trial(seq.totalRuns).responseIsLeft = isLeft;
					ana.trial(seq.totalRuns).responseVals = responseVals;
					ana.trial(seq.totalRuns).totalVals = totalVals;
					responseInfo.response = response;
					responseInfo.N = seq.totalRuns;
					responseInfo.times = [tStart tEnd];
					responseInfo.fixedColor = fixedColor;
					responseInfo.responseIsLeft = isLeft;
					updatePlot(seq.totalRuns);
					updateTask(seq,response,tEnd,responseInfo); %updates our current run number
				elseif ~ana.isMOC && response == YES
					nresponse = nresponse + 1;
					colours{end+1,1} = grating1.colourOut;
					disp(cell2mat(colours));
					disp(['Isoluminant flicker point = ' num2str(mean(cell2mat(colours)))]);
				end
			case -10
				fprintf('===>>> REDO: Trial = %i (%i secs)\n\n', seq.totalRuns, tEnd-tStart);
				edfMessage(eL,['TRIAL_RESULT ' num2str(response)]);
				trackerMessage(eL,'MSG:Redo');
			otherwise
				fprintf('===>>> UNKNOWN: Trial = %i (%i secs)\n\n', seq.totalRuns, tEnd-tStart);
				edfMessage(eL,['TRIAL_RESULT ' num2str(response)]);
				trackerMessage(eL,'MSG:UNKNOWN');
		end
		resetFixation(eL);
		stopRecording(eL);
		setOffline(eL);
	end

	%==================================================================updatePlot
	function updatePlot(thisTrial)
		v = ana.trial(thisTrial).variable;
		r = ana.trial(thisTrial).response;
		p = [];
		if r == LEFT
			p = 'k-<';
		elseif r == RIGHT
			p = 'k->';
		elseif r == UNSURE
			p = 'k-x';
		end
		if ~isempty(p)
			hold(ana.plotAxis1,'on');
			plot(ana.plotAxis1,v,thisTrial,p,'Color',map(v,:),'MarkerSize',8,'MarkerFaceColor', map(v,:));
			title(ana.plotAxis1, [fixLabel ' Fixed Value: ' num2str(fixV)]);
			xticks(ana.plotAxis1,1:length(varLabels));
			xlim(ana.plotAxis1, [0 length(varLabels)+1]);
			xlabel(ana.plotAxis1,'Varying Color Value');
			xticklabels(ana.plotAxis1,varLabels);
			
			try
				hold(ana.plotAxis2,'off');
				try scatter(ana.plotAxis2,variableVals,(responseVals./totalVals),(totalVals+1).*20,...
					'filled','MarkerFaceAlpha',0.5); end
				xlim(ana.plotAxis2, [min(variableVals)-0.05 max(variableVals)+0.05]);
				ylim(ana.plotAxis2, [-0.05 1.05]);
				hold(ana.plotAxis2,'on');
				pv = PAL_PFML_Fit(variableVals,responseVals,totalVals,space,[1 1 0 0],PF);
				if isinf(pv(1)); pv(1) = max(variableVals); end
				if isinf(pv(2)); pv(2) = 30; end
				pfvals = PF(pv,pfx);
				plot(ana.plotAxis2,pfx,pfvals,'k-');
			catch ME
				fprintf('===>>> Cannot plot psychometric curve yet...\n');
			end
			
			bar(ana.plotAxis3, [ana.leftCount ana.rightCount ana.unsureCount]);
			xticklabels(ana.plotAxis3, {'Left','Right','Unsure'});
			
			drawnow;
		end
	end


	%==================================================================findNearest
	function [idx,val,delta]=findNearest(in,value)
		%find nearest value in a vector, if more than 1 index return the first	
		[~,idx] = min(abs(in - value));
		val = in(idx);
		delta = abs(value - val);
	end
		
end
