function runEquiluminant(ana)

[rM, aM] = optickaCore.initialiseGlobals();

if ana.sendReward
	if ~exist('rM','var') || isempty(rM)
		 rM = arduinoManager('port',ana.arduinoPort);
	end
	open(rM) %open our reward manager
end

%------for windows, optionally disable audio manager
%close(aM); reset(aM);
%aM.device = -1; aM.silentMode = true;

alpha = 1;
if length(ana.colorFixed) == 4
	alpha = ana.colorFixed(4);
end

fprintf('\n--->>> runEquiluminant Started: ana UUID = %s!\n',ana.uuid);

%===================Initiate out metadata===================
ana.date		= datestr(datetime);
ana.version		= Screen('Version');
ana.computer	= Screen('Computer');
ana.gpu			= opengl('data');
ana.flashFirst	= true; %we changed the stimulus flash order on 2020/08/12; before 0 showed the fixColor, after this 0 shows the var color

%===================experiment parameters===================
if ana.debug
	ana.screenID = 0;
	ana.windowed = [0 0 1600 1000];
	ana.bitDepth = '8bit';
else
	ana.screenID = max(Screen('Screens'));%-1;
end

%===================Make a name for this run===================
pf='IsoLum_';
if ~isempty(ana.subject)
	nameExp		= [pf ana.subject];
	c			= sprintf(' %i',fix(clock()));
	nameExp		= [nameExp c];
	ana.nameExp = regexprep(nameExp,' ','_');
else
	ana.nameExp = 'debug';
end

cla(ana.plotAxis1);
cla(ana.plotAxis2);
cla(ana.plotAxis3);
drawnow;

try
	PsychDefaultSetup(2);
	%===================open our screen====================
	sM				= screenManager();
	sM.screen		= ana.screenID;
	if ana.debug || ismac || ispc || ~isempty(regexpi(ana.gpu.Vendor,'NVIDIA','ONCE'))
		sM.disableSyncTests = true; 
	end
	sM.windowed		= ana.windowed;
	sM.pixelsPerCm	= ana.pixelsPerCm;
	sM.distance		= ana.distance;
	sM.debug		= ana.debug;
	sM.blend		= true;
	sM.bitDepth		= ana.bitDepth;
	sM.verbosityLevel = 4;
	if exist(ana.gammaTable, 'file')
		load(ana.gammaTable);
		if exist('c','var') && isa(c,'calibrateLuminance')
			sM.gammaTable = c;
		end
		clear c;
	end
	sM.backgroundColour = ana.backgroundColor;
	screenVals			= sM.open; % OPEN THE SCREEN
	ana.gpuInfo			= Screen('GetWindowInfo',sM.win);
	ana.screenVals		= screenVals;
	fprintf('\n--->>> runEquiluminant Opened Screen %i : %s\n', sM.win, sM.fullName);
	disp(screenVals);
	
	if IsLinux
		Screen('Preference', 'TextRenderer', 1);
		Screen('Preference', 'DefaultFontName', 'DejaVu Sans');
	end
	
	%===========================set up stimuli====================
	circle1			= discStimulus;
	circle2			= discStimulus;
	circle1.sigma	= ana.sigma1;
	circle2.sigma	= ana.sigma2;
	circle1.size	= ana.circleDiameter;
	circle2.size	= ana.backgroundDiameter;
	setup(circle1,sM);
	setup(circle2,sM);
	
	%============================SET UP VARIABLES=====================================
	if ana.useDKL
		cM = colourManager;
		cM.deviceSPD = '/home/psychww/MatlabFiles/Calibration/PhosphorsDisplay++Color++.mat';
		cM.backgroundColour = sM.backgroundColour;
		fColour = cM.DKLtoRGB(ana.colorFixed);
		sM.backgroundColour = fColour; sM.drawBackground;sM.flip;
		ele = linspace(ana.colorStart(3),ana.colorEnd(3),ana.colorStep);
		vals = cell(length(ele),1);
		for i = 1:length(ele)
			vals{i} = cM.DKLtoRGB([ana.colorStart(1) ana.colorStart(2) ele(i)]);
		end
	else
		cM = [];
		fColour = ana.colorFixed;
		len = 0;
		r = cell(3,1);
		for i = 1:length(r)
			r{i} = linspace(ana.colorStart(i), ana.colorEnd(i),ana.colorStep)';
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
	end
	
	seq = taskSequence;
	seq.nVar(1).name = 'colour';
	seq.nVar(1).stimulus = 1;
	seq.nVar(1).values = vals;
	seq.nBlocks = ana.trialNumber;
	seq.initialise();
	ana.nTrials = seq.nRuns;
	ana.onFrames = round(((1/ana.frequency) * sM.screenVals.fps)) / 2; % video frames for each color
	fprintf('--->>> runEquiluminant # Trials: %i; # Frames Flip: %i; FPS: %i \n',seq.nRuns, ana.onFrames, sM.screenVals.fps);
	WaitSecs('YieldSecs',0.25);
	
	%==============================setup eyelink==========================
	ana.strictFixation = true;
	eL = eyelinkManager('IP',[]);
	fprintf('--->>> runEquiluminant eL setup starting: %s\n', eL.fullName);
	eL.isDummy = ana.isDummy; %use dummy or real eyelink?
	eL.name = ana.nameExp;
	eL.saveFile = [ana.nameExp '.edf'];
	eL.recordData = true; %save EDF file
	eL.sampleRate = ana.sampleRate;
	eL.calibration.manual = ana.fixManual; % manual calibration?
	eL.calibration.style = 'HV5'; % calibration style
	eL.calibration.calibrationtargetcolour = [1 1 1];
	eL.calibration.calibrationtargetsize = 1.75;
	eL.calibration.calibrationtargetwidth = 0.1;
	eL.calibration.waitformodereadytime = 500;
	eL.calibration.devicenumber = -1; % -1 = use any keyboard
	%------uncomment the next line to try the original callback, note you'll lose control of the reward system
	%eL.calibration.callback = 'PsychEyelinkDispatchCallback';
	% X, Y, FixInitTime, FixTime, Radius, StrictFix
	updateFixationValues(eL, ana.fixX, ana.fixY, ana.firstFixInit,...
		ana.firstFixTime, ana.firstFixDiameter, ana.strictFixation);
	
	%sM.verbose = true; eL.verbose = true; sM.verbosityLevel = 10; eL.verbosityLevel = 4; %force lots of log output
	
	map = analysisCore.optimalColours(seq.minTrials);
	
	initialise(eL, sM); %use sM to pass screen values to eyelink
	ListenChar(-1); trackerSetup(eL); ListenChar(0); % do setup and calibration
	fprintf('--->>> runEquiluminant eL setup complete: %s\n', eL.fullName);
	WaitSecs('YieldSecs',0.5);
	getSample(eL); %make sure everything is in memory etc.
	
	% initialise our trial variables
	tL				= timeLogger();
	tL.screenLog.beforeDisplay = GetSecs();
	tL.screenLog.stimTime(1) = 1;
	powerValues		= [];
	powerValuesV	= cell(1,seq.minTrials);
	breakLoop		= false;
	ana.trial		= struct();
	ana.nBreakInit	= 0;
	ana.nBreakFix	= 0;
	ana.nCorrect	= 0;
	tick			= 1;
	halfisi			= sM.screenVals.halfisi;
	if ~ana.debug; ListenChar(-1); end
	Priority(MaxPriority(sM.win));
	
	%================================================================================
	%-------------------------------------TASK LOOP----------------------------------
	while ~seq.taskFinished && ~breakLoop
		%=========================MAINTAIN INITIAL FIXATION==========================
		fprintf('===>>> runEquiluminant START Run = %i / %i (%i:%i) | %s, %s\n', seq.totalRuns, seq.nRuns, seq.thisBlock, seq.thisRun, sM.fullName, eL.fullName);
		resetFixation(eL);
		trackerClearScreen(eL);
		trackerDrawFixation(eL); %draw fixation window on eyelink computer
		trackerMessage(eL,'V_RT MESSAGE END_FIX END_RT');  %this 3 lines set the trial info for the eyelink
		trackerMessage(eL,['TRIALID ' num2str(seq.outIndex(seq.totalRuns))]);  %obj.getTaskIndex gives us which trial we're at
		startRecording(eL); % this should come after the TRIALID message 
		WaitSecs('YieldSecs',0.1);
		statusMessage(eL,'INITIATE FIXATION...');
		fixated = '';
		fprintf('===>>> runEquiluminant initiating fixation to start run...\n');
		%syncTime(eL);
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
			if ana.fixCross
				drawCross(sM, 0.7, ana.fixColour, ana.fixX, ana.fixY, 0.05, false, 0.25);
			else
				drawSpot(sM, 0.2, ana.fixColour, ana.fixX, ana.fixY);
			end
            %drawPhotoDiodeSquare(sM,[0 0 0 1]);
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			Screen('Flip',sM.win); %flip the buffer
            [keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> runEquiluminant recalibrate pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> runEquiluminant drift correct pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'q'}
						fprintf('===>>> runEquiluminant Q pressed!!!\n');
						fixated = 'breakfix';
						breakLoop = true;
				end
			end
		end
		if strcmpi(fixated,'breakfix')
			trackerMessage(eL,'END_FIX');trackerMessage(eL,'END_RT');
			fprintf('===>>> BROKE INITIATE FIX: Trial = %i; break inits: %i\n', seq.totalRuns,ana.nBreakInit);
			ana.nBreakInit = ana.nBreakInit + 1;
			statusMessage(eL,'Subject Broke Initial Fixation!');
			trackerMessage(eL,'MSG:BreakInitialFix');
			trackerMessage(eL,'TRIAL_RESULT -100');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
            Screen('Flip',sM.win); %flip the buffer
			WaitSecs('YieldSecs',0.3);
			continue
		end
		
		%sM.verbose = false; eL.verbose = false; sM.verbosityLevel = 4; eL.verbosityLevel = 4; %force lots of log output
		
		%=========================Our actual stimulus drawing loop==========================
		togCount=1;
		ii = 1;
		toggle = 0;
		thisPupil = [];
		modColor = seq.outValues{seq.totalRuns};
		modColor(modColor < 0) = 0; modColor(modColor > 1) = 1;
		fixedColor = fColour;
		backColor = fixedColor;
		centerColor = modColor;
		centerColor(4) = alpha;
		backColor(4) = alpha;
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
			if togCount > ana.onFrames
				toggle = mod(toggle+1,2); %switch the toggle 0 or 1
				ana.trial(seq.totalRuns).frameN = [ana.trial(seq.totalRuns).frameN togCount];
				togCount = 1; %reset out counter
				if toggle
					backColor = modColor; centerColor = fixedColor;
				else
					backColor = fixedColor; centerColor = modColor;
				end
				centerColor(4) = alpha;
				backColor(4) = alpha;
			end
			
			circle1.colourOut = centerColor;
			circle2.colourOut = backColor;
			%circle2.draw(); %background circle draw first!
			circle1.draw();
			
			if ana.fixCross
				drawCross(sM, 0.7, ana.fixColour, ana.fixX, ana.fixY, 0.05, false, 0.2);
			else
				drawSpot(sM, 0.2, ana.fixColour, ana.fixX, ana.fixY);
			end
            %drawPhotoDiodeSquare(sM,[1 1 1 1]);
			finishDrawing(sM);
			
			[tL.vbl(tick),tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
			if ii == 1; syncTime(eL); end
			tL.stimTime(tick) = toggle;
			tL.tick = tick;
			tick = tick + 1;
			togCount = togCount + 1;

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
		sM.drawTextNow(['Trial: ' num2str(seq.totalRuns) '/' num2str(seq.nRuns)]);
		ana.trial(seq.totalRuns).pupil = thisPupil;
		ana.trial(seq.totalRuns).totalFrames = ii-1;
		
		% check if we lost fixation
		if ~strcmpi(fixated,'fix')
			trackerMessage(eL,'MSG:BreakFix');
			ana.nBreakFix = ana.nBreakFix + 1;
			cr = ana.nCorrect / (ana.nCorrect+ana.nBreakFix);
			cr2 = ana.nCorrect / (ana.nCorrect+ana.nBreakFix+ana.nBreakInit);
			statusMessage(eL,'Subject Broke Fixation!');
			WaitSecs('YieldSecs',0.5);
			stopRecording(eL); setOffline(eL);
			trackerMessage(eL,'TRIAL_RESULT -1');
			resetFixation(eL);
			updatePlot(seq.totalRuns);
			fprintf('===>>> BROKE FIX: Trial = %i (%i secs) correct rate: %.2f (break+init: %.2f)\n\n',...
				seq.totalRuns, tEnd-tStart,  cr, cr2);
            twait = ana.trialInterval+1;
		else
            if ana.sendReward; rM.timedTTL(2,ana.rewardTime); end
			trackerMessage(eL,'MSG:Correct');
			ana.trial(seq.totalRuns).success = true;
			ana.nCorrect = ana.nCorrect + 1;
			cr = ana.nCorrect / (ana.nCorrect+ana.nBreakFix);
			cr2 = ana.nCorrect / (ana.nCorrect+ana.nBreakFix+ana.nBreakInit);
			statusMessage(eL,'CORRECT!');
			trackerClearScreen(eL);
			trackerMessage(eL,'TRIAL_RESULT 1');
			WaitSecs('YieldSecs',0.5);
			stopRecording(eL); setOffline(eL);
			resetFixation(eL);
            updatePlot(seq.totalRuns);
			updateTask(seq,true,tEnd-tStart); %updates our current run number
			fprintf('===>>> SUCCESS: Trial = %i (%i secs) correct rate: %.2f (break+init: %.2f)\n\n',...
				seq.totalRuns, tEnd-tStart, cr, cr2);
            twait = ana.trialInterval;
		end
        
		tEnd=Screen('Flip',sM.win);
		while GetSecs < tEnd + twait
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> runEquiluminant recalibrate pressed!\n');
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> runEquiluminant drift correct pressed!\n');
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'q'}
						fprintf('===>>> runEquiluminant quit pressed!!!\n');
						trackerClearScreen(eL);
						stopRecording(eL);
						setOffline(eL);
						breakLoop = true;
				end
			end
			WaitSecs('YieldSecs',sM.screenVals.ifi);
		end
		
	end % while ~breakLoop
	
	%===============================Clean up============================
	fprintf('===>>> runEquiluminant Finished Trials: %i\n',seq.totalRuns);
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
	if seq.totalRuns < ana.colorStep; eL.saveFile = ''; end
	close(eL);
	if ~isempty(ana.nameExp) || ~strcmpi(ana.nameExp,'debug')
		ana.powerValues = powerValues;
		ana.powerValuesV = powerValuesV;
		ana.plotAxis1 = [];
		ana.plotAxis2 = [];
		ana.plotAxis3 = [];
		if seq.totalRuns >= ana.colorStep
			fprintf('==>> SAVE %s, to: %s\n', ana.nameExp, pwd);
			save([ana.nameExp '.mat'],'ana', 'seq', 'eL', 'sM', 'tL','cM');
		end
	end
	if IsWin	
		%tL.printRunLog;
	end
	assignin('base','ana',ana);
	clear ana seq eL sM tL cM

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
		try 
			plot(ana.plotAxis1,t,ana.trial(thisTrial).pupil-mean(ana.trial(thisTrial).pupil(1:5)),'Color',map(v,:));
			xlim(ana.plotAxis1,[ 0 ana.trialDuration]);
			calculatePower(thisTrial)
			hold(ana.plotAxis2,'on');
			plot(ana.plotAxis2,thisTrial,powerValues(thisTrial),'k-o','MarkerSize',8,...
				'MarkerEdgeColor',map(v,:),'MarkerFaceColor',map(v,:),...
				'DisplayName',num2str(ana.trial(thisTrial).variable));
			errorbar(ana.plotAxis3,1:length(powerValuesV),cellfun(@mean,powerValuesV),cellfun(@std,powerValuesV))
		end
		drawnow
	end

	function calculatePower(thisTrial)
		v = ana.trial(thisTrial).variable;
		Fs = sM.screenVals.fps;            % Sampling frequency                  
		T  = sM.screenVals.ifi;            % Sampling period       
		P  = ana.trial(thisTrial).pupil;
		L  = length(P);
		P = P - mean(P);
		P1 = fft(P);
		P2 = abs(P1/L);
		P3 = P2(1:floor(L+1/2));
		P3(2:end-1) = 2*P3(2:end-1);
		f  = Fs*(0:round(L/2))/L;
		idx = findNearest(f, ana.frequency);
		fprintf('F (%.2f) actually @ %.2f\n\n',ana.frequency,f(idx));
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
