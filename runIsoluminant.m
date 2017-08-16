function runIsoluminant(ana)

global lJ

if ~exist('lJ','var') || isempty(lJ)
    lJ = arduinoManager;
    lJ.open 
end

fprintf('\n--->>> runIsoluminant Started: ana UUID = %s!\n',ana.uuid);

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
	sM.blend = 1;
	sM.bitDepth = 'FloatingPoint32BitIfPossible';
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
	sM.open; % OPEN THE SCREEN
	fprintf('\n--->>> runIsoluminant Opened Screen %i : %s\n', sM.win, sM.fullName);
	
	if IsLinux
		Screen('Preference', 'TextRenderer', 1);
		Screen('Preference', 'DefaultFontName', 'DejaVu Sans');
	end
	
	%===========================set up stimuli====================
	circle1 = discStimulus;
	circle2 = discStimulus;
	circle1.sigma = ana.sigma1;
	circle2.sigma = ana.sigma2;
	circle1.size = ana.circleDiameter;
	circle2.size = ana.backgroundDiameter;
	setup(circle1,sM);
	setup(circle2,sM);
	
	%============================SET UP VARIABLES=====================================
	
	len = 0;
	r = cell(3,1);
	for i = 1:length(r)
		step = (ana.colorEnd(i) - ana.colorStart(i)) / ana.colorStep;
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
	ana.onFrames = round(((1/ana.frequency) * sM.screenVals.fps) / 2); % video frames for each color
	fprintf('--->>> runIsoluminant # Trials: %i; # Frames Flip: %i; FPS: %i \n',seq.nRuns, ana.onFrames, sM.screenVals.fps);
	WaitSecs('YieldSecs',0.25);
	
	%==============================setup eyelink==========================
	ana.strictFixation = true;
	eL = eyelinkManager('IP',[]);
	fprintf('--->>> runIsoluminant eL setup starting: %s\n', eL.fullName);
	eL.isDummy = ana.isDummy; %use dummy or real eyelink?
	eL.name = ana.nameExp;
	eL.saveFile = [ana.nameExp '.edf'];
	eL.recordData = true; %save EDF file
	eL.sampleRate = 1000;
	eL.remoteCalibration = false; % manual calibration?
	eL.calibrationStyle = 'HV5'; % calibration style
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
	fprintf('--->>> runIsoluminant eL setup complete: %s\n', eL.fullName);
	WaitSecs('YieldSecs',0.5);
	getSample(eL); %make sure everything is in memory etc.
	
	% initialise our trial variables
	tL = timeLogger();
	tL.screenLog.beforeDisplay = GetSecs();
	tL.screenLog.stimTime(1) = 1;
	powerValues = [];
	breakLoop = false;
	ana.trial = struct();
	tick = 1;
	halfisi = sM.screenVals.halfisi;
	Priority(MaxPriority(sM.win));
	
	while seq.thisRun <= seq.nRuns && ~breakLoop
		%=========================MAINTAIN INITIAL FIXATION==========================
		fprintf('===>>> runIsoluminant START Trial = %i / %i | %s, %s\n', seq.thisRun, seq.nRuns, sM.fullName, eL.fullName);
		%testWindowOpen(sM);
		resetFixation(eL);
		trackerClearScreen(eL);
		trackerDrawFixation(eL); %draw fixation window on eyelink computer
		edfMessage(eL,'V_RT MESSAGE END_FIX END_RT');  %this 3 lines set the trial info for the eyelink
		edfMessage(eL,['TRIALID ' num2str(seq.outIndex(seq.thisRun))]);  %obj.getTaskIndex gives us which trial we're at
		startRecording(eL);
		statusMessage(eL,'INITIATE FIXATION...');
		fixated = '';
		ListenChar(2);
		fprintf('===>>> runIsoluminant initiating fixation to start run...\n');
		syncTime(eL);
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
			drawCross(sM,0.3,[1 1 1 1],ana.fixX,ana.fixY);
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> runIsoluminant recalibrate pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> runIsoluminant drift correct pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'escape'}
						fprintf('===>>> runIsoluminant escape pressed!!!\n');
						fixated = 'breakfix';
						breakLoop = true;
				end
			end
			Screen('Flip',sM.win); %flip the buffer
		end
		ListenChar(0);
		if strcmpi(fixated,'breakfix')
			fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', seq.thisRun);
			statusMessage(eL,'Subject Broke Initial Fixation!');
			edfMessage(eL,'MSG:BreakInitialFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			WaitSecs('YieldSecs',0.1);
			continue
		end
		
		%sM.verbose = false; eL.verbose = false; sM.verbosityLevel = 4; eL.verbosityLevel = 4; %force lots of log output
		
		%=========================Our actual stimulus drawing loop==========================
		edfMessage(eL,'END_FIX');
		statusMessage(eL,'Show Stimulus...');
		
		i=1;
		ii = 1;
		toggle = 0;
		thisPupil = [];
		modColor = seq.outValues{seq.thisRun}{1};
		modColor(modColor < 0) = 0; modColor(modColor > 1) = 1;
		fixedColor = ana.colorFixed;
		backColor = modColor;
		centerColor = fixedColor;
		fprintf('===>>> modColor=%s | fixColor=%s\n',num2str(modColor),num2str(fixedColor));
		edfMessage(eL,['MSG:modColor=' num2str(modColor)]);
		edfMessage(eL,['MSG:variable=' num2str(seq.outIndex(seq.thisRun))]);
		edfMessage(eL,['MSG:thisRun=' num2str(seq.thisRun)]);
		
		ana.trial(seq.thisRun).n = seq.thisRun;
		ana.trial(seq.thisRun).variable = seq.outIndex(seq.thisRun);
		ana.trial(seq.thisRun).mColor = modColor;
		ana.trial(seq.thisRun).fColor = fixedColor;
		ana.trial(seq.thisRun).pupil = [];
		ana.trial(seq.thisRun).frameN = [];
		
		tStart = GetSecs; vbl = tStart;if isempty(tL.vbl);tL.vbl(1) = tStart;tL.startTime = tStart; end
		
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while GetSecs < tStart + ana.trialDuration
			if i > ana.onFrames
				toggle = mod(toggle+1,2); %switch the toggle 0 or 1
				ana.trial(seq.thisRun).frameN = [ana.trial(seq.thisRun).frameN i];
				i = 1; %reset out counter
				if toggle
					backColor = fixedColor; centerColor = modColor;
				else
					backColor = modColor; centerColor = fixedColor;
				end
			end
			
			circle1.colourOut = centerColor;
			circle2.colourOut = backColor;
			circle2.draw(); %background circle draw first!
			circle1.draw();
			
			%Screen('FillRect', sM.win, backColor, sM.winRect);
			%Screen('FillOval', sM.win, centerColor, circleRect);
			drawCross(sM,0.3,[1 1 1 1], ana.fixX, ana.fixY);
			finishDrawing(sM);
			
			[tL.vbl(tick),tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
			tL.stimTime(tick) = toggle;
			tL.tick = tick;
			tick = tick + 1;
			i = i + 1;

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
		
		sM.drawBackground();
		tEnd=Screen('Flip',sM.win);
		
		ana.trial(seq.thisRun).pupil = thisPupil;
		ana.trial(seq.thisRun).totalFrames = ii-1;
		
		% check if we lost fixation
		if ~strcmpi(fixated,'fix')
			fprintf('===>>> BROKE FIXATION Trial = %i (%i secs)\n\n', seq.thisRun, tEnd-tStart);
			statusMessage(eL,'Subject Broke Fixation!');
			edfMessage(eL,'TRIAL_RESULT -1');
			edfMessage(eL,'MSG:BreakFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
		else
			fprintf('===>>> SUCCESS: Trial = %i (%i secs)\n\n', seq.thisRun, tEnd-tStart);
            lJ.timedTTL(2,150)
			ana.trial(seq.thisRun).success = true;
			stopRecording(eL);
			edfMessage(eL,'TRIAL_RESULT 1');
			setOffline(eL);
			updatePlot(seq.thisRun);
			updateTask(seq,true); %updates our current run number
			iii = seq.thisRun;
		end
		
		ListenChar(2);
		while GetSecs < tEnd + 0.5
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> runIsoluminant recalibrate pressed!\n');
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> runIsoluminant drift correct pressed!\n');
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'escape'}
						fprintf('===>>> runIsoluminant escape pressed!!!\n');
						trackerClearScreen(eL);
						stopRecording(eL);
						setOffline(eL);
						breakLoop = true;
				end
			end
			WaitSecs('YieldSecs',sM.screenVals.ifi);
		end
		ListenChar(0);
		
	end % while ~breakLoop
	
	%===============================Clean up============================
	fprintf('===>>> runIsoluminant Finished Trials: %i\n',seq.thisRun);
	Screen('DrawText', sM.win, '===>>> FINISHED!!!');
	Screen('Flip',sM.win);
	WaitSecs('YieldSecs', 2);
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
		fprintf('==>> SAVE %s, to: %s\n', ana.nameExp, pwd);
		save([ana.nameExp '.mat'],'ana', 'seq', 'eL', 'sM', 'tL');
	end
	if IsWin	
		tL.printRunLog;
	end
	clear ana seq eL sM tL

catch ME
	if exist('eL','var'); close(eL); end
	if exist('sM','var'); close(sM); end
	ListenChar(0);ShowCursor;Priority(0);Screen('CloseAll');
	getReport(ME)
end

	function updatePlot(thisTrial)
		ifi = sM.screenVals.ifi;
		t = 0:ifi:ifi*(ana.trial(thisTrial).totalFrames-1);
		hold(ana.plotAxis1,'on');
		plot(ana.plotAxis1,t,ana.trial(thisTrial).pupil);
		calculatePower(thisTrial)
		plot(ana.plotAxis2,powerValues,'k-o');
        drawnow
	end

	function calculatePower(thisTrial)
		
		Fs = sM.screenVals.fps;            % Sampling frequency                  
		T = sM.screenVals.ifi;             % Sampling period       
		P=ana.trial(thisTrial).pupil;
		L=length(P);
		t = (0:L-1)*T;
		P1=fft(P);
		P2 = abs(P1/L);
		P3=P2(1:L/2+1);
		P3(2:end-1) = 2*P3(2:end-1);
		f=Fs*(0:(L/2))/L;
		idx = findNearest(f, ana.frequency);
		powerValues(thisTrial) = P3(idx);

	end

	function [idx,val,delta]=findNearest(in,value)
		%find nearest value in a vector, if more than 1 index return the first	
		[~,idx] = min(abs(in - value));
		val = in(idx);
		delta = abs(value - val);
	end
		
end
