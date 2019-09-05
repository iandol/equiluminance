function runEquiMotion(ana)

global rM
if ana.sendReward
	if ~exist('rM','var') || isempty(rM)
		 rM = arduinoManager;
	end
	open(rM) %open our reward manager
end

fprintf('\n--->>> runEquiMotion Started: ana UUID = %s!\n',ana.uuid);

%----------compatibility for windows
%if ispc; PsychJavaTrouble(); end
KbName('UnifyKeyNames');

%===================Initiate out metadata===================
ana.date = datestr(datetime);
ana.version = Screen('Version');
ana.computer = Screen('Computer');

%===================experiment parameters===================
if ana.debug
	ana.screenID = 0;
else
	ana.screenID = max(Screen('Screens'));%-1;
end

%===================Make a name for this run===================
pf='IsoLum_';
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

try
	PsychDefaultSetup(2);
	Screen('Preference', 'SkipSyncTests', 0);
	%===================open our screen====================
	sM = screenManager();
	sM.screen = ana.screenID;
	sM.windowed = ana.windowed;
	sM.pixelsPerCm = ana.pixelsPerCm;
	sM.distance = ana.distance;
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
	fprintf('\n--->>> runEquiMotion Opened Screen %i : %s\n', sM.win, sM.fullName);
	
	if IsLinux
		Screen('Preference', 'DefaultFontName', 'DejaVu Sans');
	end
	
	%===========================set up stimuli====================
	
	grating1 = colourGratingStimulus;
	grating1.size = ana.size;
	grating1.colour = ana.colorFixed;
	grating1.colour2 = ana.colorStart;
	grating1.contrast = 1;
	grating1.type = ana.type;
	grating1.mask = ana.mask;
	grating1.tf = 0;
	grating1.sf = ana.sf;
	
	grating2 = colourGratingStimulus;
	grating2.size = ana.size;
	grating2.colour = (1+ana.contrastMultiplier) * (ana.colorFixed + ana.colorStart) / 2;
	grating2.colour2 = (1-ana.contrastMultiplier) * (ana.colorFixed + ana.colorStart) / 2;
	grating2.colour = [grating2.colour(1:3) 1]; grating2.colour2 = [grating2.colour2(1:3) 1];
	grating2.contrast = 1;
	grating2.type = ana.type;
	grating2.mask = ana.mask;
	grating2.tf = 0;
	grating2.sf = ana.sf;
	
	setup(grating1,sM); setup(grating2,sM);
	%============================SET UP VARIABLES=====================================
	
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
	
	seq = stimulusSequence;
	seq.nVar(1).name = 'colour';
	seq.nVar(1).stimulus = 1;
	seq.nVar(1).values = vals;
	seq.nBlocks = ana.trialNumber;
	seq.initialise();
	ana.nTrials = seq.nRuns;
	ana.onFrames = round(((1/ana.frequency) * sM.screenVals.fps)); % video frames for each color
	fprintf('--->>> runEquiMotion # Trials: %i; # Frames Flip: %i; FPS: %i \n',seq.nRuns, ana.onFrames, sM.screenVals.fps);
	WaitSecs('YieldSecs',0.25);
	
	%==============================setup eyelink==========================
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
	eL.modify.calibrationtargetsize = 1;
	eL.modify.calibrationtargetwidth = 0.05;
	eL.modify.waitformodereadytime = 500;
	eL.modify.devicenumber = -1; % -1 = use any keyboard
	% X, Y, FixInitTime, FixTime, Radius, StrictFix
	updateFixationValues(eL, ana.fixX, ana.fixY, ana.firstFixInit,...
		ana.firstFixTime, ana.firstFixDiameter, ana.strictFixation);
	%sM.verbose = true; eL.verbose = true; sM.verbosityLevel = 10; eL.verbosityLevel = 4; %force lots of log output
	initialise(eL, sM); %use sM to pass screen values to eyelink
	setup(eL); % do setup and calibration
	fprintf('--->>> runEquiMotion eL setup complete: %s\n', eL.fullName);
	WaitSecs('YieldSecs',0.5);
	getSample(eL); %make sure everything is in memory etc.
	
	%-------------------response values, linked to left, up, down
	LEFT = 1; 	RIGHT = 2; UNSURE = 3; BREAKFIX = -1;

	map = analysisCore.optimalColours(seq.minBlocks);
		
	% initialise our trial variables
	tL				= timeLogger();
	tL.screenLog.beforeDisplay = GetSecs();
	tL.screenLog.stimTime(1) = 1;
	powerValues		= [];
	powerValuesV	= cell(1,seq.minBlocks);
	breakLoop		= false;
	ana.trial		= struct();
	tick			= 1;
	halfisi			= sM.screenVals.halfisi;
	Priority(MaxPriority(sM.win));
	
	while ~seq.taskFinished && ~breakLoop
		%=========================MAINTAIN INITIAL FIXATION==========================
		fprintf('\n===>>> runEquiMotion START Run = %i / %i (%i:%i) | %s, %s\n', seq.totalRuns, seq.nRuns, seq.thisBlock, seq.thisRun, sM.fullName, eL.fullName);
		modColor			= [seq.outValues{seq.totalRuns}(1:3) 1];
		fixedColor			= [ana.colorFixed(1:3) 1];
		grating1.colourOut	= modColor;
		grating1.colour2Out = fixedColor;
		grating2.colourOut	= ((1+ana.contrastMultiplier) * (fixedColor + modColor)) / 2.0; 
		grating2.colourOut	= [grating2.colourOut(1:3) 1];
		grating2.colour2Out = ((1-ana.contrastMultiplier) * (fixedColor + modColor)) / 2.0; 
		grating2.colour2Out = [grating2.colour2Out(1:3) 1];
		
		update(grating1); update(grating2);
		fprintf('===>>> MOD=%s | FIX=%s\n',num2str(grating1.colourOut),num2str(grating1.colour2Out));
		fprintf('===>>> B=%s | D=%s\n',num2str(grating2.colourOut),num2str(grating2.colour2Out));
		
		resetFixation(eL);
		trackerClearScreen(eL);
		trackerDrawFixation(eL); %draw fixation window on eyelink computer
		trackerMessage(eL,'V_RT MESSAGE END_FIX END_RT');  %this 3 lines set the trial info for the eyelink
		trackerMessage(eL,['TRIALID ' num2str(seq.outIndex(seq.totalRuns))]);  %obj.getTaskIndex gives us which trial we're at
		trackerMessage(eL,['MSG:modColor=' num2str(modColor)]);
		trackerMessage(eL,['MSG:variable=' num2str(seq.outIndex(seq.totalRuns))]);
		trackerMessage(eL,['MSG:totalRuns=' num2str(seq.totalRuns)]);
		startRecording(eL);
		statusMessage(eL,'INITIATE FIXATION...');
		fixated = '';
		ListenChar(2);
		fprintf('===>>> runEquiMotion initiating fixation...\n');
		%syncTime(eL);
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix') && breakLoop == false
			drawCross(sM, 0.3, [1 1 1 1], ana.fixX, ana.fixY);
            drawPhotoDiodeSquare(sM,[0 0 0 1]);
			finishDrawing(sM);
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			flip(sM); %flip the buffer
            [keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> runEquiMotion recalibrate pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> runEquiMotion drift correct pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'q'}
						fprintf('===>>> runEquiMotion Q pressed!!!\n');
						fixated = 'breakfix';
						breakLoop = true;
				end
			end
		end
		ListenChar(0);
		if strcmpi(fixated,'breakfix')
			fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', seq.totalRuns);
			statusMessage(eL,'Subject Broke Initial Fixation!');
			trackerMessage(eL,'MSG:BreakInitialFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
            Screen('Flip',sM.win); %flip the buffer
			WaitSecs('YieldSecs',0.2);
			continue
		end
		
		%sM.verbose = false; eL.verbose = false; sM.verbosityLevel = 4; eL.verbosityLevel = 4; %force lots of log output
		
		%=========================Our actual stimulus drawing loop==========================
		ii = 1;
		toggle = 0;
		thisPupil = [];
		stroke = 1;
		ana.trial(seq.totalRuns).n = seq.totalRuns;
		ana.trial(seq.totalRuns).variable = seq.outIndex(seq.totalRuns);
		ana.trial(seq.totalRuns).mColor = modColor;
		ana.trial(seq.totalRuns).fColor = fixedColor;
		ana.trial(seq.totalRuns).pupil = [];
		ana.trial(seq.totalRuns).frameN = [];
		
		statusMessage(eL,'Show Stimulus...');
		tStart = GetSecs; vbl = tStart;if isempty(tL.vbl);tL.vbl(1) = tStart;tL.startTime = tStart; end
		trackerMessage(eL,'END_FIX');
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while GetSecs < tStart + ana.trialDuration
			if mod(ii,ana.onFrames) == 0
				stroke = stroke + 1;
				if stroke > 4; stroke = 1; end
			end
			switch stroke
				case 1
					grating1.driftPhase = 0;
					draw(grating1)
				case 2
					grating2.driftPhase = -90;
					draw(grating2)
				case 3
					grating1.driftPhase = -180;
					draw(grating1)
				case 4
					grating2.driftPhase = -270;
					draw(grating2)
			end
			drawCross(sM, 0.3, [1 1 1 1], ana.fixX, ana.fixY);
            drawPhotoDiodeSquare(sM,[1 1 1 1]);
			finishDrawing(sM);
			
			[tL.vbl(tick),tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
			tL.stimTime(tick) = toggle;
			tL.tick = tick;
			tick = tick + 1;

			getSample(eL);
			thisPupil(ii) = eL.pupil;
			ii = ii + 1;
			if ~isFixated(eL)
				fixated = 'breakfix';
				break %break the while loop
			end
		end
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		
		tEnd=Screen('Flip',sM.win);
		
		ana.trial(seq.totalRuns).pupil = thisPupil;
		ana.trial(seq.totalRuns).totalFrames = ii-1;
		
		drawBackground(sM);
		Screen('DrawText',sM.win,['Motion Direction: [LEFT]=LEFT [DOWN]=UNSURE [RIGHT]=RIGHT'],0,0);
		Screen('Flip',sM.win);
		statusMessage(eL,'Waiting for Subject Response!');
		edfMessage(eL,'Subject Responding')
		edfMessage(eL,'END_RT'); ...
		response = -1;
		ListenChar(2);
		[secs, keyCode] = KbWait(-1);
		rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
		switch lower(rchar)
			case {'leftarrow','left'}
				response = LEFT;
				trackerDrawText(eL,'Subject Pressed LEFT!');
				edfMessage(eL,'Subject Pressed LEFT');
				fprintf('Response: LEFT\n');
				doPlot();
			case {'righttarrow','right'}
				response = RIGHT;
				trackerDrawText(eL,'Subject Pressed RIGHT!');
				edfMessage(eL,'Subject Pressed RIGHT')
				fprintf('Response: RIGHT\n');
				doPlot();
			case {'downarrow','down'}
				response = UNSURE;
				trackerDrawText(eL,'Subject Pressed UNSURE!');
				edfMessage(eL,'Subject Pressed UNSURE')
				fprintf('Response: UNSURE\n');
				doPlot();
			case {'c'}
				fprintf('===>>> runEquiMotion recalibrate pressed!\n');
				stopRecording(eL);
				setOffline(eL);
				trackerSetup(eL);
				WaitSecs('YieldSecs',2);
			case {'d'}
				fprintf('===>>> runEquiMotion drift correct pressed!\n');
				stopRecording(eL);
				driftCorrection(eL);
				WaitSecs('YieldSecs',2);
			case {'q'}
				fprintf('===>>> runEquiMotion quit pressed!!!\n');
				trackerClearScreen(eL);
				stopRecording(eL);
				setOffline(eL);
				breakLoop = true;
		end
		ListenChar(0);
		
		WaitSecs('YieldSecs',ana.trialInterval);
		
		% check if we lost fixation
		if ~strcmpi(fixated,'fix')
			fprintf('===>>> BROKE FIXATION Trial = %i (%i secs)\n\n', seq.totalRuns, tEnd-tStart);
			statusMessage(eL,'Subject Broke Fixation!');
			trackerMessage(eL,'TRIAL_RESULT -1');
			trackerMessage(eL,'MSG:BreakFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
		else
			fprintf('===>>> SUCCESS: Trial = %i (%i secs)\n\n', seq.totalRuns, tEnd-tStart);
			if ana.sendReward; rM.timedTTL(2,150); end
			ana.trial(seq.totalRuns).success = true;
			ana.trial(seq.totalRuns).response = response;
			edfMessage(eL,['TRIAL_RESULT ' num2str(response)]);
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			%updatePlot(seq.totalRuns);
			updateTask(seq,true); %updates our current run number
			iii = seq.totalRuns;
		end
		
	end % while ~breakLoop
	
	%===============================Clean up============================
	fprintf('===>>> runEquiMotion Finished Trials: %i\n',seq.totalRuns);
	Screen('DrawText', sM.win, '===>>> FINISHED!!!');
	Screen('Flip',sM.win);
	WaitSecs('YieldSecs', 2);
	reset(grating1);reset(grating2);
	close(sM); breakLoop = true;
	ListenChar(0);ShowCursor;Priority(0);
	
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
	if IsWin	
		tL.printRunLog;
	end
	clear ana seq eL sM tL

catch ME
	if exist('eL','var'); close(eL); end
	reset(grating1);reset(grating2);
	if exist('sM','var'); close(sM); end
	ListenChar(0);ShowCursor;Priority(0);Screen('CloseAll');
	getReport(ME)
end

	function updatePlot(thisTrial)
		v = ana.trial(thisTrial).variable;
		ifi = sM.screenVals.ifi;
		t = 0:ifi:ifi*(ana.trial(thisTrial).totalFrames-1);
		hold(ana.plotAxis1,'on');
		plot(ana.plotAxis1,t,ana.trial(thisTrial).pupil,'Color',map(v,:));
		xlim(ana.plotAxis1,[ 0 ana.trialDuration]);
		calculatePower(thisTrial)
		hold(ana.plotAxis2,'on');
		plot(ana.plotAxis2,thisTrial,powerValues(thisTrial),'k-o','MarkerSize',8,...
			'MarkerEdgeColor',map(v,:),'MarkerFaceColor',map(v,:),...
			'DisplayName',num2str(ana.trial(thisTrial).variable));
		plot(ana.plotAxis3,cellfun(@mean,powerValuesV),'k-o','MarkerSize',8)
        drawnow
		
	end

	function calculatePower(thisTrial)
		v = ana.trial(thisTrial).variable;
		Fs = sM.screenVals.fps;            % Sampling frequency                  
		T  = sM.screenVals.ifi;            % Sampling period       
		P  = ana.trial(thisTrial).pupil;
		L  = length(P);
		t  = (0:L-1)*T;
		P1 = fft(P);
		P2 = abs(P1/L);
		P3 = P2(1:L/2+1);
		P3(2:end-1) = 2*P3(2:end-1);
		f  = Fs*(0:(L/2))/L;
		idx = findNearest(f, ana.frequency);
		powerValues(thisTrial) = P3(idx);
		powerValuesV{v} = [powerValuesV{v} powerValues(thisTrial)];
	end

	function [idx,val,delta]=findNearest(in,value)
		%find nearest value in a vector, if more than 1 index return the first	
		[~,idx] = min(abs(in - value));
		val = in(idx);
		delta = abs(value - val);
	end
		
end
