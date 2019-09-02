function trainColourCore(ana)

global rM

if exist('rM','var') && isa(rM,'arduinoManager')
	if ~rM.isOpen
		rM.open();
	end
else
	rM = arduinoManager('port',ana.arduinoPort);
	rM.open;
end

fprintf('\n--->>> trainColour Started: ana UUID = %s!\n',ana.uuid);

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
pf='Train_';
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
	sM.blend = 1;
	if sM.debug
		sM.bitDepth = '8bit';
	else
		sM.bitDepth = 'EnableBits++Bits++Output'; %EnableBits++Bits++Output EnableBits++Color++Output FloatingPoint32Bit
	end
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
	fprintf('\n--->>> ColourTrain Opened Screen %i : %s\n', sM.win, sM.fullName);
	
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
	circle3.sigma = ana.sigma1;
	circle4.sigma = ana.sigma2;
	circle1.size = ana.circle1Diameter;
	circle2.size = ana.circle2Diameter;
	circle3.size = ana.circle1Diameter;
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
		circle1.colour = ana.colour1 * ana.contrast1;
		circle2.colour = ana.colour2 * ana.contrast2;
		circle3.colour = ana.colour1 * ana.contrast2;
		circle4.colour = ana.colour2 * ana.contrast3;
	end
	
	vals = [-ana.positionXY(1) +ana.positionXY(1) -ana.positionXY(2) +ana.positionXY(2)];
	circle1.xPosition = vals(1);
	circle2.xPosition = vals(2);
	circle3.xPosition = vals(1);
	circle4.xPosition = vals(2);
	circle1.yPosition = vals(3);
	circle2.yPosition = vals(3);
	circle3.yPosition = vals(4);
	circle4.yPosition = vals(4);
	
	metaStim = metaStimulus('stimuli',{circle1,circle2,circle3,circle4},'screen',sM);
	
	setup(metaStim);
	
	%============================SET UP VARIABLES=====================================
	seq = stimulusSequence();
	seq.nVar(1).name = 'xPosition';
	seq.nVar(1).stimulus = 1;
	seq.nVar(1).values = vals(1:2);
	seq.nVar(2).name = 'yPosition';
	seq.nVar(2).stimulus = 1;
	seq.nVar(2).values = vals(3:4);
	seq.nVar(3).name = 'colour';
	seq.nVar(3).stimulus = 1;
	seq.nVar(3).values = {ana.colour1,ana.colour2};
	seq.nBlocks = ana.trialNumber;
	seq.fps = sM.screenVals.fps;
	seq.initialise();
	drawnow;
	ana.nTrials = seq.nRuns;
	fprintf('--->>> Train # Trials: %i; # FPS: %i \n',seq.nRuns, sM.screenVals.fps);
	WaitSecs('YieldSecs',0.25);
	
	%==============================setup eyelink==========================
	ana.strictFixation = true;
	eL = eyelinkManager('IP',[]);
	fprintf('--->>> Train eL setup starting: %s\n', eL.fullName);
	eL.isDummy = ana.isDummy; %use dummy or real eyelink?
	eL.name = ana.nameExp;
	eL.saveFile = [ana.nameExp '.edf'];
	eL.recordData = true; %save EDF file
	eL.sampleRate = ana.sampleRate;
	eL.remoteCalibration = false; % manual calibration?
	eL.calibrationStyle = ana.calibrationStyle; % calibration style
	eL.exclusionZone = ana.exclusionZone;
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
	fprintf('--->>> Train eL setup complete: %s\n', eL.fullName);
	WaitSecs('YieldSecs',0.5);
	getSample(eL); %make sure everything is in memory etc.
	
	
	%=======================set up the triggers===========================
	if ana.sendTrigger == true
		dPP = plusplusManager;
		dPP.sM = sM;
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
	Priority(MaxPriority(sM.win));
	
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	%=====================START HERE====================
	%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	while seq.totalRuns <= seq.nRuns && ~breakLoop
		%=========================MAINTAIN INITIAL FIXATION==========================
		fprintf('\n===>>> Train START Trial = %i / %i | %s, %s\n', seq.totalRuns, seq.nRuns, sM.fullName, eL.fullName);
		
		if ana.sendTrigger == true;sendStrobe(dPP,0);flip(sM);flip(sM);end
		
		resetFixation(eL);
		updateFixationValues(eL, ana.fixX, ana.fixY, ana.firstFixInit,...
			ana.firstFixTime, ana.firstFixDiameter, ana.strictFixation);
		trackerClearScreen(eL);
		%trackerDrawExclusion(eL);
		trackerDrawFixation(eL); %draw fixation window on eyelink computer
		edfMessage(eL,'V_RT MESSAGE END_FIX END_RT');  %this 3 lines set the trial info for the eyelink
		edfMessage(eL,['TRIALID ' num2str(seq.outIndex(seq.totalRuns))]);  %obj.getTaskIndex gives us which trial we're at
		startRecording(eL);
		statusMessage(eL,'INITIATE FIXATION...');
		fixated = '';
		ListenChar(2);
		
		if ana.sendTrigger == true;sendStrobe(dPP,248);flip(sM);end
		
		syncTime(eL);
		
		while ~strcmpi(fixated,'fix') && ~strcmpi(fixated,'breakfix')
			drawCross(sM,0.4,[1 1 1 1],ana.fixX,ana.fixY);
			getSample(eL);
			fixated=testSearchHoldFixation(eL,'fix','breakfix');
			[keyIsDown, ~, keyCode] = KbCheck(-1);
			if keyIsDown == 1
				rchar = KbName(keyCode); if iscell(rchar);rchar=rchar{1};end
				switch lower(rchar)
					case {'c'}
						fprintf('===>>> Train recalibrate pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						setOffline(eL);
						trackerSetup(eL);
						WaitSecs('YieldSecs',2);
					case {'d'}
						fprintf('===>>> Train drift correct pressed!\n');
						fixated = 'breakfix';
						stopRecording(eL);
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'q'}
						fprintf('===>>> Train quit pressed!!!\n');
						fixated = 'breakfix';
						breakLoop = true;
				end
			end
			Screen('Flip',sM.win); %flip the buffer
		end
		ListenChar(0);
		if strcmpi(fixated,'breakfix')
			sM.drawBackground;
			if ana.sendTrigger == true;sendStrobe(dPP,249);flip(sM);end
			if ana.sendTrigger == true;sendStrobe(dPP,255);flip(sM);flip(sM);end %STIM OFF
			
			statusMessage(eL,'Subject Broke Initial Fixation!');
			edfMessage(eL,'MSG:BreakInitialFix');
			resetFixation(eL);
			stopRecording(eL);
			setOffline(eL);
			
			ana.nTotal = ana.nTotal + 1;
			ana.runningPerformance(ana.nTotal) = -1;
			ana.nInitiateBreak = ana.nInitiateBreak + 1;
			
			fprintf('===>>> BROKE INITIATE FIXATION Trial = %i\n', seq.totalRuns);
			updatePlot(seq.totalRuns);
			WaitSecs('YieldSecs',0.1);
			continue
		end
		
		%sM.verbose = false; eL.verbose = false; sM.verbosityLevel = 4; eL.verbosityLevel = 4; %force lots of log output
		
		%=========================Our actual stimulus drawing loop==========================
		edfMessage(eL,'END_FIX');
		statusMessage(eL,'Show Stimulus...');
		
		xPos = seq.outValues{seq.totalRuns,1};
		yPos = seq.outValues{seq.totalRuns,2};
		thisColour = seq.outValues{seq.totalRuns,3};
		
		circle1.xPositionOut = xPos;
		circle1.yPositionOut = yPos;
		
		%we randomise the remaining circle positions
		rList = randsample(3,3);
		rPos = [-xPos yPos; xPos -yPos; -xPos -yPos];
		circle2.xPositionOut = rPos(rList(1),1);
		circle2.yPositionOut = rPos(rList(1),2);
		circle3.xPositionOut = rPos(rList(2),1);
		circle3.yPositionOut = rPos(rList(2),2);
		circle4.xPositionOut = rPos(rList(3),1);
		circle4.yPositionOut = rPos(rList(3),2);
		
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
			circle1.colourOut = thisColour * ana.contrast1;
		end
		
		%this allows the tracker to draw the stimulus positions
		stimulusPositions(1).x = xPos;
		stimulusPositions(1).y = yPos;
		stimulusPositions(1).size = circle1.size;
		stimulusPositions(1).selected = true;
		stimulusPositions(2).x = rPos(rList(1),1);
		stimulusPositions(2).y = rPos(rList(1),2);
		stimulusPositions(2).size = circle2.size;
		stimulusPositions(2).selected = false;
		stimulusPositions(3).x = rPos(rList(2),1);
		stimulusPositions(3).y = rPos(rList(2),2);
		stimulusPositions(3).size = circle3.size;
		stimulusPositions(3).selected = false;
		stimulusPositions(4).x = rPos(rList(3),1);
		stimulusPositions(4).y = rPos(rList(3),2);
		stimulusPositions(4).size = circle4.size;
		stimulusPositions(4).selected = false;
		trackerDrawStimuli(eL,stimulusPositions);
		
		fprintf('===>>> Target Position=%s | Foil Position=%s\n',num2str(circle1.xPositionOut),num2str(circle2.xPositionOut));
		edfMessage(eL,['MSG:variable=' num2str(seq.outIndex(seq.totalRuns))]);
		edfMessage(eL,['MSG:thisRun=' num2str(seq.totalRuns)]);
		
		ana.trial(seq.totalRuns).n = seq.totalRuns;
		ana.trial(seq.totalRuns).variable = seq.outIndex(seq.totalRuns);
		ana.trial(seq.totalRuns).pupil = [];
		ana.trial(seq.totalRuns).frameN = [];
		
		if length(ana.delayToChoice) == 2
			delayToChoice = (rand * (ana.delayToChoice(2)-ana.delayToChoice(1))) + ana.delayToChoice(1);
		else
			delayToChoice = ana.delayToChoice;
		end
		fprintf('===>>> Delay to Choice is: %.2g\n',delayToChoice);
		
		if ana.sendTrigger == true;sendStrobe(dPP,seq.outIndex(seq.totalRuns));flip(sM);end
		
		tStart = GetSecs; vbl = tStart;if isempty(tL.vbl);tL.vbl(1) = tStart;tL.startTime = tStart; end
		
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		while GetSecs < tStart + delayToChoice
			
			metaStim.draw();
			drawCross(sM,0.4,[1 1 1 1], ana.fixX, ana.fixY);
			finishDrawing(sM);
			
			[tL.vbl(tick),tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
			tL.stimTime(tick) = 0.5;
			tL.tick = tick;
			tick = tick + 1;
			
			getSample(eL);
			if ~isFixated(eL)
				fixated = 'breakfix';
				break %break the while loop
			end
		end
		
		if ~strcmpi(fixated,'breakfix')
			if (rand <= ana.fixOnlyReward/100); rM.timedTTL(2, 50); end
			resetFixation(eL);
			% X, Y, FixInitTime, FixTime, Radius, StrictFix
			updateFixationValues(eL, xPos, yPos,...
				ana.targetInitiation, ana.targetMaintain,...
				ana.targetDiameter/2, ana.strictFixation);
			fprintf('===>>> FIXX=%d | FIXY=%d\n',eL.fixationX,eL.fixationY);
			trackerDrawStimuli(eL,stimulusPositions,true);
			trackerDrawFixation(eL); %draw fixation window on eyelink computer
			statusMessage(eL,'Saccade to Target...');
			
			if ana.sendTrigger == true;sendStrobe(dPP,250);flip(sM);end %START CHOICE
			
			tStart = GetSecs; vbl = tStart;
			while GetSecs < tStart + 2
				
				metaStim.draw();
				
				finishDrawing(sM);
				getSample(eL);
				
				[tL.vbl(tick),tL.show(tick),tL.flip(tick),tL.miss(tick)] = Screen('Flip',sM.win, vbl + halfisi);
				tL.stimTime(tick) = 1;
				tL.tick = tick;
				tick = tick + 1;
				
				fixated=testSearchHoldFixation(eL,'fix','breakfix');
				if strcmpi(fixated,'breakfix') 
					if ana.sendTrigger == true;sendStrobe(dPP,253);flip(sM);end %BREAK CHOICE
					tFix = GetSecs; tReaction =  tFix - tStart;
					break %break the while loop
				elseif strcmpi(fixated,'fix')
					tFix = GetSecs; tReaction =  tFix - tStart;
					break %break the while loop
				elseif strcmp(fixated,'EXCLUDED!')
					tFix = GetSecs; 	tReaction =  tFix - tStart;
					break %break the while loop
				end
			end
		else
			if ana.sendTrigger == true;sendStrobe(dPP,253);flip(sM);end %BREAK CHOICE
		end
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		
		if ana.sendTrigger == true;sendStrobe(dPP,255);flip(sM);end %STIM OFF
		sM.drawBackground();
		[tL.vbl(tick),tL.show(tick),tL.flip(tick),tL.miss(tick)]=Screen('Flip',sM.win);
		tL.stimTime(tick) = -1;
		tL.tick = tick;
		tick = tick + 1;
		tEnd = tL.vbl(end);
		
		
		%=========================================check if we got fixation
		if strcmpi(fixated,'fix')
			if ana.sendTrigger == true;sendStrobe(dPP,251);flip(sM);end %CORRECT
			rM.timedTTL(2, ana.Rewardms)
			Beeper(1000,0.1,0.2);
			trackerDrawText(eL,'CORRECT!');
			fprintf('===>>> SUCCESS: Trial = %i (total:%.3g | reaction:%.3g)\n', seq.totalRuns, tEnd-tStart, tReaction);
			ana.nSuccess = ana.nSuccess + 1;
			ana.nTotal = ana.nTotal + 1;
			ana.runningPerformance(ana.nTotal) = 1;
			ana.trial(seq.totalRuns).success = true;
			ana.trial(seq.totalRuns).reactionTime = tReaction;
			stopRecording(eL);
			edfMessage(eL,'TRIAL_RESULT 1');
			setOffline(eL);
			updatePlot(seq.totalRuns);
			updateTask(seq,true); %updates our current run number
			iii = seq.totalRuns;
			if ana.debug
				Screen('DrawText', sM.win, '===>>> CORRECT!!!', 0, 0);
				Screen('Flip',sM.win);
			end
			waitTime = ana.trialDelay;
		else
			if ana.sendTrigger == true;sendStrobe(dPP,252);flip(sM);end %INCORRECT
			if strcmpi(fixated,'breakfix')
				fprintf('===>>> BROKE FIXATION Trial = %i (total:%.3g | reaction:%.3g)\n', seq.totalRuns, tEnd-tStart, tReaction);
				trackerDrawText(eL,'BREAK FIX!');
				edfMessage(eL,'TRIAL_RESULT -1');
				edfMessage(eL,'MSG:BreakFix');
			elseif strcmp(fixated,'EXCLUDED!')
				excludedN = excludedN + 1;
				fprintf('===>>> EXCLUSION ZONE Trial = %i > %i (total:%.3g | reaction:%.3g)\n', seq.totalRuns, excludedN, tEnd-tStart, tReaction);
				trackerDrawText(eL,'BREAK FIX (EXCLUSION)!');
				edfMessage(eL,'TRIAL_RESULT -1');
				edfMessage(eL,'MSG:BreakFixExclusion');
			end
			stopRecording(eL);
			setOffline(eL);
			Beeper(180,1,2);
			ana.nFixBreak = ana.nFixBreak + 1;
			ana.nTotal = ana.nTotal + 1;
			ana.runningPerformance(ana.nTotal) = 0;
			seq.verbose = true;
			resetRun(seq); %randomise within block
			seq.verbose = false;
			updatePlot(seq.totalRuns);
			if ana.debug
				Screen('DrawText', sM.win, '===>>> BREAK FIX!!!', 0, 0);
				Screen('Flip',sM.win);
			end
			waitTime = ana.punishDelay;
			if strcmp(fixated,'EXCLUDED!')
				waitTime = waitTime + 2;
			end
		end
		
		ListenChar(2);
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
						driftCorrection(eL);
						WaitSecs('YieldSecs',2);
					case {'escape'}
						fprintf('===>>> Train escape pressed!!!\n');
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
	fprintf('===>>> Train Finished Trials: %i\n',seq.totalRuns);
	Screen('DrawText', sM.win, '===>>> FINISHED!!!', 0, 0);
	Screen('Flip',sM.win);
	WaitSecs('YieldSecs', 2);
	close(sM); breakLoop = true;
	ListenChar(0);ShowCursor;Priority(0);
	close(rM);
	
	if exist(ana.ResultDir,'dir') > 0
		cd(ana.ResultDir);
	end
	trackerClearScreen(eL);
	stopRecording(eL);
	setOffline(eL);
	close(eL);
	if ~isempty(ana.nameExp) && isempty(regexpi(ana.nameExp,'debug'))
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
		ylim(ana.plotAxis2,[0 100])
		
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
		drawnow
	end

end
