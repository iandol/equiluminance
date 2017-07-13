function runIsoluminant(ana)

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
nameExp = [pf ana.subject];
c = sprintf(' %i',fix(clock()));
nameExp = [nameExp c];
ana.nameExp = regexprep(nameExp,' ','_');

cla(ana.plotAxis1);
cla(ana.plotAxis2);

xxx = 0;

try
	PsychDefaultSetup(2);
	xxx = xxx + 1;
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
		if ana.debug
			sM.gammaTable.plot
		end
	end
	sM.backgroundColour = ana.backgroundColor;
	sM.open; % OPEN THE SCREEN
	fprintf('\n--->>> %i ISOLUM Opened Screen %i : %s\n', xxx, sM.win, sM.fullName);
	
	Screen('Preference', 'DefaultFontName','DejaVu Sans');
	
	%============================SET UP VARIABLES=====================================
	ana.nTrials = abs((sum(ana.colorEnd)-sum(ana.colorStart))/sum(ana.colorStep)) + 1; %
	ana.onFrames = round((1/ana.frequency) * sM.screenVals.fps) / 2; % video frames for each color
	fprintf('--->>> ISOLUM # Trials: %i; # Frames Flip: %i; FPS: %i \n',ana.nTrials, ana.onFrames, sM.screenVals.fps);
	WaitSecs('YieldSecs',0.25);
	diameter = ceil(ana.circleDiameter*sM.ppd);
	circleRect = [0,0,diameter,diameter];
	circleRect = CenterRectOnPoint(circleRect, sM.xCenter, sM.yCenter);
	
	%==============================setup eyelink==========================
	ana.strictFixation = true;
	fprintf('--->>> ISOLUM eL setup starting...\n');
	eL = eyelinkManager('IP',[]);
	%eL.verbose = true;
	eL.isDummy = ana.isDummy; %use dummy or real eyelink?
	eL.name = ana.nameExp;
	eL.saveFile = [ana.nameExp '.edf'];
	eL.recordData = true; %save EDF file
	eL.sampleRate = 1000;
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
	fprintf('--->>> ISOLUM eL setup complete: %s\n', eL.fullName);
	WaitSecs('YieldSecs',0.5);
	getSample(eL); %make sure everything is in memory etc.
	eL.verbose = true;
	
	% initialise our trial variables
	tL = timeLogger();
	tL.screenLog.beforeDisplay = GetSecs();
	tL.screenLog.stimTime(1) = 1;
	iii = 1;
	powerValues = [];
	breakLoop = false;
	ana.trial = struct();
	tick = 1;
	halfisi = sM.screenVals.halfisi;
	Priority(MaxPriority(sM.win));
	
	while ~breakLoop
		%=========================MAINTAIN INITIAL FIXATION==========================
		fprintf('===>>> ISOLUM START Trial = %i\n', iii);eL.verbose = false;
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
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> ISOLUM recalibrate pressed\n');
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> ISOLUM drift correct pressed\n');
						fixated = 'breakfix';
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'escape'}
						fprintf('===>>> ISOLUM escape pressed\n');
						fixated = 'breakfix';
						breakLoop = true;
				end
			end
			WaitSecs('YieldSecs',0.0016);
		end
		ListenChar(0);
		if strcmpi(fixated,'breakfix')
			fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', iii);
			statusMessage(eL,'Subject Broke Initial Fixation!');
			edfMessage(eL,'MSG:BreakInitialFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			WaitSecs('YieldSecs',0.1);
			continue
		end
		
		%if we lost fixation then
		if ~strcmpi(fixated,'fix')
			fprintf('===>>> BROKE INITIATE: will retry...\n');
			continue
		end
		
		%=========================Our actual stimulus drawing loop==========================
		edfMessage(eL,'END_FIX');
		statusMessage(eL,'Show Stimulus...');
		
		i=1;
		toggle = 0;
		ii = 1;
		toggle = 0;
		thisPupil = [];
		modColor = ana.colorStart + (ana.colorStep .* (iii-1));
		modColor(modColor < 0) = 0; modColor(modColor > 1) = 1;
		fixedColor = ana.colorFixed;
		backColor = modColor;
		centerColor = fixedColor;
		fprintf('===>>> modColor=%s | fixColor=%s\n',num2str(modColor),num2str(fixedColor));
		edfMessage(eL,['MSG:modColor=' num2str(modColor)]);
		
		ana.trial(iii).n = iii;
		ana.trial(iii).mColor = modColor;
		ana.trial(iii).fColor = fixedColor;
		ana.trial(iii).pupil = [];
		ana.trial(iii).frameN = [];
		
		tStart = GetSecs; vbl = tStart;if isempty(tL.vbl);tL.vbl(1) = tStart;tL.startTime = tStart; end
		
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while GetSecs < tStart + ana.trialDuration
			if i > ana.onFrames
				toggle = mod(toggle+1,2); %switch the toggle 0 or 1
				ana.trial(iii).frameN = [ana.trial(iii).frameN i];
				i = 1; %reset out counter
				if toggle
					backColor = fixedColor; centerColor = modColor;
				else
					backColor = modColor; centerColor = fixedColor;
				end
			end
			
			Screen('FillRect', sM.win, backColor, sM.winRect);
			Screen('FillOval', sM.win, centerColor, circleRect);
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
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		
		sM.drawBackground();
		tEnd=Screen('Flip',sM.win);
		
		ana.trial(iii).pupil = thisPupil;
		ana.trial(iii).totalFrames = ii-1;
		
		% check if we lost fixation
		if ~strcmpi(fixated,'fix')
			fprintf('===>>> BROKE FIXATION Trial = %i (%i secs)\n\n', iii, tEnd-tStart);
			statusMessage(eL,'Subject Broke Fixation!');
			edfMessage(eL,'TRIAL_RESULT -1');
			edfMessage(eL,'MSG:BreakFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			continue
		else
			fprintf('===>>> SUCCESS: Trial = %i (%i secs)\n\n', iii, tEnd-tStart);
			ana.trial(iii).success = true;
			stopRecording(eL);
			edfMessage(eL,'TRIAL_RESULT 1');
			setOffline(eL);
			updatePlot(iii);
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
		ListenChar(0);
		
		if iii > ana.nTrials; breakLoop = true; end
		
	end % while ~breakLoop
	
	%===============================Clean up============================
	Screen('DrawText', sM.win, 'FINISHED!!!')
	Screen('Flip',sM.win)
	WaitSecs('YieldSecs', 1);
	close(sM); breakLoop = true;
	ListenChar(0);ShowCursor;Priority(0);
	
	if exist(ana.ResultDir,'dir') > 0
		cd(ana.ResultDir);
	end
	close(eL);
	ana.plotAxis1 = [];
	ana.plotAxis2 = [];
	fprintf('==>> SAVE %s, to: %s\n', ana.nameExp, pwd);
	save([ana.nameExp '.mat'],'ana','eL', 'sM', 'tL');
	
catch ME
	close(sM);
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
