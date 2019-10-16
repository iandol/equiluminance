function runIsoluminant(ana)

global rM

if ana.sendReward
	if ~exist('rM','var') || isempty(rM)
		 rM = arduinoManager('port',ana.arduinoPort);
	end
	open(rM) %open our reward manager
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
	Screen('Preference', 'SkipSyncTests', 1);
	%===================open our screen====================
	sM = screenManager();
	sM.screen = ana.screenID;
    sM.disableSyncTests = true;
	sM.windowed = ana.windowed;
	sM.pixelsPerCm = ana.pixelsPerCm;
	sM.distance = ana.distance;
	sM.debug = ana.debug;
	sM.blend = 1;
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
	ana.onFrames = round(((1/ana.frequency) * sM.screenVals.fps)) / 2; % video frames for each color
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
	eL.sampleRate = ana.sampleRate;
	eL.remoteCalibration = ana.fixManual; % manual calibration?
	eL.calibrationStyle = 'HV5'; % calibration style
	eL.modify.calibrationtargetcolour = ana.fixColour;
	eL.modify.calibrationtargetsize = 1;
	eL.modify.calibrationtargetwidth = 0.1;
	eL.modify.waitformodereadytime = 500;
	eL.modify.devicenumber = -1; % -1 = use any keyboard
	% X, Y, FixInitTime, FixTime, Radius, StrictFix
	updateFixationValues(eL, ana.fixX, ana.fixY, ana.firstFixInit,...
		ana.firstFixTime, ana.firstFixDiameter, ana.strictFixation);
	
	%sM.verbose = true; eL.verbose = true; sM.verbosityLevel = 10; eL.verbosityLevel = 4; %force lots of log output
	
	map = analysisCore.optimalColours(seq.minBlocks);
	
	initialise(eL, sM); %use sM to pass screen values to eyelink
	setup(eL); % do setup and calibration
	fprintf('--->>> runIsoluminant eL setup complete: %s\n', eL.fullName);
	WaitSecs('YieldSecs',0.5);
	getSample(eL); %make sure everything is in memory etc.
	
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
		fprintf('===>>> runIsoluminant START Run = %i / %i (%i:%i) | %s, %s\n', seq.totalRuns, seq.nRuns, seq.thisBlock, seq.thisRun, sM.fullName, eL.fullName);
		resetFixation(eL);
		trackerClearScreen(eL);
		trackerDrawFixation(eL); %draw fixation window on eyelink computer
		trackerMessage(eL,'V_RT MESSAGE END_FIX END_RT');  %this 3 lines set the trial info for the eyelink
		trackerMessage(eL,['TRIALID ' num2str(seq.outIndex(seq.totalRuns))]);  %obj.getTaskIndex gives us which trial we're at
		startRecording(eL);
		statusMessage(eL,'INITIATE FIXATION...');
		fixated = '';
		ListenChar(2);
		fprintf('===>>> runIsoluminant initiating fixation to start run...\n');
		%syncTime(eL);
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
			%drawCross(sM, 0.3, ana.fixColour, ana.fixX, ana.fixY);
            drawSpot(sM, 0.25, ana.fixColour,ana.fixX, ana.fixY);
            drawPhotoDiodeSquare(sM,[0 0 0 1]);
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			Screen('Flip',sM.win); %flip the buffer
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
					case {'q'}
						fprintf('===>>> runIsoluminant Q pressed!!!\n');
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
		i=1;
		ii = 1;
		toggle = 0;
		thisPupil = [];
		modColor = seq.outValues{seq.totalRuns};
		modColor(modColor < 0) = 0; modColor(modColor > 1) = 1;
		fixedColor = ana.colorFixed;
		backColor = modColor;
		centerColor = fixedColor;
		fprintf('===>>> modColor=%s | fixColor=%s @ %i frames\n',num2str(modColor),num2str(fixedColor),ana.onFrames);
		trackerMessage(eL,['MSG:modColor=' num2str(modColor)]);
		trackerMessage(eL,['MSG:variable=' num2str(seq.outIndex(seq.totalRuns))]);
		trackerMessage(eL,['MSG:totalRuns=' num2str(seq.totalRuns)]);
		
		ana.trial(seq.totalRuns).n = seq.totalRuns;
		ana.trial(seq.totalRuns).variable = seq.outIndex(seq.totalRuns);
		ana.trial(seq.totalRuns).mColor = modColor;
		ana.trial(seq.totalRuns).fColor = fixedColor;
		ana.trial(seq.totalRuns).pupil = [];
		ana.trial(seq.totalRuns).frameN = [];
		
		statusMessage(eL,'Show Stimulus...');
		trackerMessage(eL,'END_FIX');
		tStart = GetSecs; vbl = tStart;if isempty(tL.vbl);tL.vbl(1) = tStart;tL.startTime = tStart; end
		
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while GetSecs < tStart + ana.trialDuration
			if i > ana.onFrames
				toggle = mod(toggle+1,2); %switch the toggle 0 or 1
				ana.trial(seq.totalRuns).frameN = [ana.trial(seq.totalRuns).frameN i];
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
			
			%drawCross(sM, 0.3, ana.fixColour, ana.fixX, ana.fixY);
            drawSpot(sM, 0.25, ana.fixColour, ana.fixX, ana.fixY);
            drawPhotoDiodeSquare(sM,[1 1 1 1]);
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
		
		tEnd=Screen('Flip',sM.win);
		trackerMessage(eL,'END_RT');
		ana.trial(seq.totalRuns).pupil = thisPupil;
		ana.trial(seq.totalRuns).totalFrames = ii-1;
		
		% check if we lost fixation
		if ~strcmpi(fixated,'fix')
			fprintf('===>>> BROKE FIXATION Trial = %i (%i secs)\n\n', seq.totalRuns, tEnd-tStart);
			statusMessage(eL,'Subject Broke Fixation!');
			stopRecording(eL);
			trackerMessage(eL,'TRIAL_RESULT -1');
			trackerMessage(eL,'MSG:BreakFix');
			setOffline(eL);
			resetFixation(eL);
            WaitSecs('YieldSecs',ana.trialInterval)
		else
			fprintf('===>>> SUCCESS: Trial = %i (%i secs)\n\n', seq.totalRuns, tEnd-tStart);
            if ana.sendReward; rM.timedTTL(2,ana.rewardTime); end
			ana.trial(seq.totalRuns).success = true;
			statusMessage(eL,'CORRECT!');trackerMessage(eL,'MSG:Correct');
			trackerClearScreen(eL);
            WaitSecs('YieldSecs',ana.trialInterval);
			stopRecording(eL);
			trackerMessage(eL,'TRIAL_RESULT 1');
			setOffline(eL);
			resetFixation(eL);
            updatePlot(seq.totalRuns);
			updateTask(seq,true); %updates our current run number
			iii = seq.totalRuns;
        end
        
        ListenChar(2);
		while GetSecs < tEnd + 0.01
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
					case {'q'}
						fprintf('===>>> runIsoluminant quit pressed!!!\n');
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
	fprintf('===>>> runIsoluminant Finished Trials: %i\n',seq.totalRuns);
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
		ana.plotAxis3 = [];
		fprintf('==>> SAVE %s, to: %s\n', ana.nameExp, pwd);
		save([ana.nameExp '.mat'],'ana', 'seq', 'eL', 'sM', 'tL');
	end
	if IsWin	
		%tL.printRunLog;
	end
	clear ana seq eL sM tL

catch ME
	assignin('base','ana',ana)
	if exist('eL','var'); close(eL); end
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
