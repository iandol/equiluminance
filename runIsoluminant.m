function isoluminant_stimuli(ana)

%===================Initiate out metadata===================
ana.date = datestr(datetime);
ana.version = Screen('Version');
ana.computer = Screen('Computer');

%===================experiment parameters===================
ana.screenID = max(Screen('Screens'));%-1;

%===================Make a name for this run===================
pf='IsoLum_';
nameExp = [pf ana.subject];
c = sprintf(' %i',fix(clock()));
nameExp = [nameExp c];
ana.nameExp = regexprep(nameExp,' ','_');

cla(ana.plotAxis);

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
	if exist(ana.gammaTable, 'file')
		load(ana.gammaTable);
		if isa(c,'calibrateLuminance')
			sM.gammaTable = c;
		end
		clear c;
		if ~isempty(sM.windowed)
			sM.gammaTable.plot
		end
	end
	sM.backgroundColour = ana.backgroundColor;
	sM.open; % OPEN THE SCREEN
	
	%============================SET UP VARIABLES=====================================
	ana.nTrials = (sum(ana.colorEnd)-sum(ana.colorStart))/sum(ana.colorStep)+1; %
	ana.onFrames = round(ana.frequency/sM.screenVals.ifi); % video frames for each color
	
	diameter = ceil(ana.circleDiameter*sM.ppd);
	circleRect = [0,0,diameter,diameter];
	circleRect = CenterRectOnPoint(circleRect, sM.xCenter, sM.yCenter);
	
	%==============================setup eyelink==========================
	ana.strictFixation = true;
	eL = eyelinkManager('IP',[]);
	%eL.verbose = true;
	eL.isDummy = ana.isDummy; %use dummy or real eyelink?
	eL.name = ana.nameExp;
	eL.saveFile = [ana.nameExp '.edf'];
	eL.recordData = true; %save EDF file
	eL.sampleRate = 500;
	eL.remoteCalibration = false; % manual calibration?
	eL.calibrationStyle = 'HV5'; % calibration style
	eL.modify.calibrationtargetcolour = [0 0 0];
	eL.modify.calibrationtargetsize = 0.5;
	eL.modify.calibrationtargetwidth = 0.05;
	eL.modify.waitformodereadytime = 500;
	eL.modify.devicenumber = -1; % -1 = use any keyboard
	% X, Y, FixInitTime, FixTime, Radius, StrictFix
	updateFixationValues(eL, ana.fixX, ana.fixY, ana.firstFixInit,...
		ana.firstFixTime, ana.firstFixDiameter, ana.strictFixation);
	initialise(eL, sM); %use sM to pass screen values to eyelink
	setup(eL); % do setup and calibration
	WaitSecs('YieldSecs',0.25);
	getSample(eL); %make sure everything is in memory etc.
	
	
	% initialise our trial variables
	tL = timeLogger();
	tL.screenLog.beforeDisplay = GetSecs();
	tL.screenLog.stimTime(1) = 1;
	iii = 1;
	breakLoop = false;
	ana.trial = struct();
	tick = 1;
	halfisi = sM.screenVals.halfisi;
	Priority(MaxPriority(sM.win));
	
	while ~breakLoop
		%=========================MAINTAIN INITIAL FIXATION==========================
		resetFixation(eL);
		trackerClearScreen(eL);
		trackerDrawFixation(eL); %draw fixation window on eyelink computer
		edfMessage(eL,'V_RT MESSAGE END_FIX END_RT');  %this 3 lines set the trial info for the eyelink
		edfMessage(eL,['TRIALID ' num2str(iii)]);  %obj.getTaskIndex gives us which trial we're at
		startRecording(eL);
		statusMessage(eL,'INITIATE FIXATION...');
		fixated = '';
		ListenChar(2);
		drawCross(sM,0.3,[0 0 0 1],ana.fixX,ana.fixY);
		Screen('Flip',sM.win); %flip the buffer
		syncTime(eL);
		%fprintf('===>>> INITIATE FIXATION Trial = %i\n', iii);
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fixated = 'breakfix';
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'escape'}
						fixated = 'breakfix';
						breakLoop = true;
				end
			end
		end
		ListenChar(0);
		if strcmpi(fixated,'breakfix')
			fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', iii);
			statusMessage(eL,'Subject Broke Initial Fixation!');
			edfMessage(eL,'MSG:BreakFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			continue
		end
		
		%if we lost fixation then
		if ~strcmpi(fixated,'fix'); continue; end
		
		%=========================Our actual stimulus drawing loop==========================
		edfMessage(eL,'END_FIX');
		statusMessage(eL,'Show Stimulus...');
		
		i=1;
		toggle = 0;
		ii = 1;
		toggle = 0;
		thisPupil = [];
		mColor = ana.colorStart + ana.colorStep .* iii;
		fColor = ana.colorFixed;
		ana.trial(iii).n = iii;
		ana.trial(iii).mColor = mColor;
		ana.trial(iii).fColor = fColor;
		ana.trial(iii).pupil = [];
		ana.trial(iii).frameN = [];
		
		tStart = GetSecs; vbl = tStart;if isempty(tL.vbl);tL.vbl(1) = tStart;tL.startTime = tStart; end
			
		while GetSecs < tStart + ana.trialDuration
			if i > ana.onFrames
				toggle = mod(toggle+1,2); %switch the toggle 0 or 1
				ana.trial(iii).frameN = [ana.trial(iii).frameN i];
				i = 1; %reset out counter
			end
			if toggle
				bColor = mColor; cColor = fColor;
			else
				bColor = fColor; cColor = mColor;
			end
			
			Screen('FillRect', sM.win, bColor, sM.winRect);
			Screen('FillOval', sM.win, cColor, circleRect);
			drawCross(sM,0.3,[0 0 0 1], ana.fixX, ana.fixY);
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
				break %break the for loop
			end
		end
		
		sM.drawBackground();
		tEnd=Screen('Flip',sM.win);
		
		ana.trial(iii).pupil = thisPupil;
		ana.trial(iii).totalFrames = ii-1;
		
		% check if we lost fixation
		if ~strcmpi(fixated,'fix')
			fprintf('===>>> BROKE FIXATION Trial = %i (%i secs)\n', iii, tEnd-tStart);
			statusMessage(eL,'Subject Broke Fixation!');
			response = -1;
			edfMessage(eL,'TRIAL_RESULT -1');
			edfMessage(eL,'MSG:BreakFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			continue
		else
			fprintf('===>>> SUCCESS: Trial = %i (%i secs)\n', iii, tEnd-tStart);
			response = 1;
			stopRecording(eL);
			edfMessage(eL,'TRIAL_RESULT 1');
			setOffline(eL);
			iii = iii+1;
		end
		
		ListenChar(2);

		while GetSecs < tEnd + 0.5
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'escape'}
						breakLoop = true;
				end
			end
			WaitSecs('YieldSecs',0.015);
		end

		ListenChar(2);
		updatePlot();
		if iii > ana.nTrials; breakLoop = true; end
		
	end % while ~breakLoop
	
	%===============================Clean up============================
	close(sM);
	close(eL);
	ListenChar(0);ShowCursor;Priority(0);Screen('CloseAll');
	
	tL.printRunLog;
	oldDir = pwd;
	if exist(ana.ResultDir,'dir') > 0
		cd(ana.ResultDir);
	end
	close(eL);
	ana.plotAxis = [];
	fprintf('==>> SAVE %s, to: %s\n', ana.nameExp, pwd);
	save([ana.nameExp '.mat'],'ana','eL', 'sM', 'tL');
	cd(oldDir)
	clear ana eL sM tL
	
catch ME
	close(sM);
	ListenChar(0);ShowCursor;Priority(0);Screen('CloseAll');
	getReport(ME)
end

	function updatePlot()
		hold(ana.plotAxis,'on');
		plot(ana.plotAxis,ana.trial(end).pupil);
	end

	function calculatePower()
		
		Fs = sM.screenVals.fps;            % Sampling frequency                  
		T = sM.screenVals.fps;             % Sampling period       
		L = 1500;             % Length of signal
		t = (0:L-1)*T;   
		
	end
		
end
