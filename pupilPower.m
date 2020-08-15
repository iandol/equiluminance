classdef pupilPower < analysisCore
	%PUPILPOWER Calculate power for each trial from EDF file pupil data
	
	%------------------PUBLIC PROPERTIES----------%
	properties
		%> filename to use
		fileName char
		%> eyelink parsed edf data
		pupilData eyelinkAnalysis
		%> plot verbosity
		verbose = true
		%> normalise the pupil diameter to the baseline?
		normaliseBaseline logical = true
		%> detrend each trial  before computing FFT
		detrend logical = true
		%> normalise the plots of power vs luminance?
		normalisePowerPlots logical = true
		%> color map to use
		colorMap char = 'jet';
		%> actual R G B luminance maxima, if [1 1 1] then use 0<->1
		%> floating point range
		maxLuminances double = [1 1 1]
		%> use hanning window?
		useHanning logical = false
		%> smooth the pupil data?
		smoothPupil logical = true;
		%> smoothing window in milliseconds
		smoothWindow double = 30;
		%> smooth method
		smoothMethod char = 'gaussian'
		%> draw error bars on raw pupil plots
		drawError logical = true
		%> error bars
		error char = 'SE';
		%> downsample raw pupil for plotting only (every N points)
		downSample double = 20;
	end
	
	properties (Hidden = true)
		%> default R G B luminance maxima, if [1 1 1] then use 0<->1
		%> floating point range
		defLuminances double = [1 1 1]
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = public)
		meanPowerValues
		varPowerValues
		meanPowerValues0
		varPowerValues0
		meanPhaseValues
		varPhaseValues
		meanPupil
		varPupil
		meanTimes
		meanF
		meanP
		varP
	end
	
	%------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = public, Hidden = true)
		powerValues
		phaseValues
		powerValues0
		metadata struct
		SortedPupil struct
		rawPupil cell
		rawTimes cell
		rawF cell
		rawP cell
		isLoaded logical = false
		isCalculated logical = false
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> raw data removed, cannot reparse from EDF events.
		isRawDataRemoved logical = false
		%> allowed properties passed to object upon construction, see parseArgs
		allowedProperties char = ['useHanning|defLuminances|fileName|pupilData|'...
			'normaliseBaseline|normalisePowerPlots|error|colorMap|'...
			'maxLuminances|smoothPupil|smoothMethod|drawError|downSample']
	end
	
	%=======================================================================
	methods
	%=======================================================================
		
		% ===================================================================
		%> @brief class constructor
		%>
		%> @param
		%> @return
		% ===================================================================
		function me = pupilPower(varargin)
			defaults.measureRange = [0.72 3.57];
			defaults.baselineWindow = [-0.2 0.2];
			defaults.plotRange = [];
			varargin = optickaCore.addDefaults(varargin,defaults);
			me = me@analysisCore(varargin); %superclass constructor
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			if ~isempty(me.fileName)
				[p,f,~] = fileparts(me.fileName);
				if ~isempty(p) && (exist(p,'dir') == 7)
					me.rootDirectory = p;
				else
					me.rootDirectory = pwd;
				end
				me.name = f;
			else
				if isempty(me.name); me.name = 'pupilPower'; end
				me.rootDirectory = pwd;
				run(me);
			end
		end
		
		% ===================================================================
		%> @brief run full analysis and plot the result
		%>
		%> @param force: reload the EDF and reparse
		%> @return
		% ===================================================================
		function [handles,data] = run(me, force)
			if ~exist('force','var') || isempty(force); force = false; end
			me.load(force);
			me.calculate();
			if me.doPlots; [handles,data] = me.plot(); end
		end
		
		% ===================================================================
		%> @brief plot the parsed data
		%>
		%> @param
		%> @return
		% ===================================================================
		function [handles,data] = plot(me)
			if ~me.isCalculated; return; end
			
			[fixColor,fixName,fColor,varColor,varName,tColor,trlColor,trlColors,...
				tit,colorLabels,step,colorMin,colorMax] = makecolors(me);
			
			data.fixName = fixName;
			data.varName = varName;
			data.trlColors = trlColors;
			
			handles.h1=figure;figpos(1,[900 500]);set(handles.h1,'Color',[1 1 1],'NumberTitle','off',...
				'Name',['pupilPower: ' me.pupilData.file],'Papertype','a4','PaperUnits','centimeters',...
				'PaperOrientation','landscape','Renderer','painters');
			switch varName
				case 'Yellow'
					plotColor = [0.8 0.8 0];
				otherwise
					plotColor = zeros(1,3);	plotColor(1,tColor)	= 0.8;
			end
			switch fixName
				case 'Yellow'
					lineColor = [0.8 0.8 0];
				otherwise
					lineColor = zeros(1,3);	lineColor(1,fColor)	= 0.8;
			end
			pCorrect = (length(me.pupilData.correct.idx)/length(me.pupilData.trials))*100;
			t2 = sprintf(' | %i / %i = %.2f%%',...
				length(me.pupilData.correct.idx),length(me.pupilData.trials), ...
				pCorrect);
			numVars	= length(colorLabels);
			csteps = trlColors;
			csteps(numVars+1) = csteps(numVars);
			PL = stairs(1:numVars+1, csteps, 'Color',plotColor,'LineWidth',2);
			PL.Parent.FontSize = 11;
			PL.Parent.XTick = 1.5:1:numVars+0.5;
			PL.Parent.XTickLabel = colorLabels; 
			PL.Parent.XTickLabelRotation = 30;
			xlim([0.5 numVars+1.5])
			ax = axis;
			line([ax(1) ax(2)],[fixColor fixColor],'Color',lineColor,'Linewidth',2);
			if max(me.maxLuminances) == 1
				xlabel('Step (0 <-> 1)')
			else
				xlabel('Step (cd/m^2)')
			end
			ylim([colorMin-step(1) colorMax+step(1)])
			%set(gca,'ytick',colorMin-step:2*step:colorMax+step)
			ylabel('Luminance (cd/m^2)')
			title([tit t2]);
			box on; grid on;
			
			handles.h2=figure;figpos(1,[0.9 0.9],[],'%');set(handles.h2,'Color',[1 1 1],'NumberTitle','off',...
				'Name',['pupilPower: ' me.pupilData.file],'Papertype','a4','PaperUnits','centimeters',...
				'PaperOrientation','landscape','Renderer','painters');
			tl = tiledlayout(handles.h2,3,1,'TileSpacing','compact');
			ax1 = nexttile(tl);
			traceColor				= colormap(me.colorMap);
			traceColor_step			= floor(length(traceColor)/numVars);
			
			f = round(me.metadata.ana.onFrames) * (1 / me.metadata.sM.screenVals.fps);
			if isfield(me.metadata.ana,'flashFirst') && me.metadata.ana.flashFirst == true
				m = 0:2:100;
			else
				m = 1:2:101;
			end
			for i = 1 : floor(me.metadata.ana.trialDuration / f / 2)+1
				rectangle('Position',[f*m(i) -10000 f 20000],'FaceColor',[0.8 0.8 0.8 0.3],'EdgeColor','none')
			end
			maxp = -inf;
			minp = inf;
			
			for i = 1: length(me.meanPupil)
				hold on
				t = me.meanTimes{i};
				p = me.meanPupil{i};
				e = me.varPupil{i};
				
				if isempty(t); continue; end
				
				if me.normaliseBaseline
					idx = t >= me.baselineWindow(1) & t <= me.baselineWindow(2);
					mn = mean(p(idx));
					p = p - mn;
				end
				
				if me.pupilData.sampleRate > 500
					idx = circshift(logical(mod(1:length(t),me.downSample)), -(me.downSample-1)); %downsample every N as less points to draw
					t(idx) = [];
					p(idx) = [];
					e(idx) = [];
				end
				
				idx = t >= me.measureRange(1) & t <= me.measureRange(2);
				if me.detrend
					p = p - mean(p(idx));
				end
				
				[~, ~, A(i), p1(i), p0(i)] = doFFT(me,p);
				
				idx = t >= 0 & t <= 3.5;
				maxp = max([maxp max(p(idx))]);
				minp = min([minp min(p(idx))]);

				if ~isempty(p)
					if me.drawError
						PL1 = analysisCore.areabar(t,p,e,traceColor(i*traceColor_step,:),0.1,...
							'Color', traceColor(i*traceColor_step,:), 'LineWidth', 2,'DisplayName',colorLabels{i});
						PL1.plot.DataTipTemplate.DataTipRows(1).Label = 'Time';
						PL1.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
					else
						PL1 = plot(t,p,'color', traceColor(i*traceColor_step,:),...
							'LineWidth', 1,'DisplayName',colorLabels{i});
						PL1.DataTipTemplate.DataTipRows(1).Label = 'Time';
						PL1.DataTipTemplate.DataTipRows(2).Label = 'Power';
					end 
				end
				
			end
			
			line([me.measureRange(1) me.measureRange(1)],[minp maxp],...
				'Color',[0.3 0.3 0.3 0.5],'linestyle',':','LineWidth',2);
			line([me.measureRange(2) me.measureRange(2)],[minp maxp],...
				'Color',[0.3 0.3 0.3 0.5],'linestyle',':','LineWidth',2);
			
			data.minDiameter = minp;
			data.maxDiameter = maxp;
			data.diameterRange = maxp - minp;
			
			xlabel('Time (s)')
			ylabel('Diameter')
			if me.normaliseBaseline
				title(['Normalised Pupil: # Trials = ' num2str(me.metadata.ana.trialNumber) ' | Subject = ' me.metadata.ana.subject  ' | baseline = ' num2str(me.baselineWindow,'%.2f ') 'secs'  ' | Range = ' num2str(data.diameterRange,'%.2f')]);
			else
				title(['Raw Pupil: # Trials = ' num2str(me.metadata.ana.trialNumber) ' | Subject = ' me.metadata.ana.subject  ' | Range = ' num2str(data.diameterRange,'%.2f')])
			end
			xlim([-0.2 me.measureRange(2)+0.05]);if minp == 0;minp = -1;end;if maxp==0;maxp = 1; end
			if minp <= 0
				ylim([minp+(minp/100*2) maxp+(maxp/100*2)]);
			else
				ylim([minp-(minp/100*2) maxp+(maxp/100*2)]);
			end
			legend(colorLabels,'Location','bestoutside','FontSize',10,...
				'Position',[0.9125 0.5673 0.0779 0.3550]);
			box on; grid on;
			ax1.XMinorGrid = 'on';
			ax1.FontSize = 12;
			
			ax2 = nexttile(tl);
			maxP = 0;
			for i = 1: length(me.meanF)
				hold on
				F = me.meanF{i};
				P = me.meanP{i};
				idx = F < 20;
				F = F(idx);
				P = P(idx);
				maxP = max([maxP max(P)]);
				PL2 = plot(F,P,'color', [traceColor(i*traceColor_step,:) 0.6],...
					'Marker','o','DisplayName',colorLabels{i},...
					'MarkerSize', 5,'MarkerFaceColor',traceColor(i*traceColor_step,:),...
					'MarkerEdgeColor', 'none');	
				PL2.DataTipTemplate.DataTipRows(1).Label = 'Frequency';
				PL2.DataTipTemplate.DataTipRows(2).Label = 'Power';
			end
			xlim([-0.1 floor(me.metadata.ana.frequency*3)]);
			if maxP==0; maxP=1; end
			ylim([0 maxP+(maxP/20)]);
			xlabel('Frequency (Hz)');
			ylabel('Power');
			if ~me.detrend && ~me.normaliseBaseline
				ax2.YScale = 'log';
				ylabel('Power [log]');
			end
			line([me.metadata.ana.frequency me.metadata.ana.frequency],[ax2.YLim(1) ax2.YLim(2)],...
				'Color',[0.3 0.3 0.3 0.5],'linestyle',':','LineWidth',2);
			title(['FFT Power: measure range = ' num2str(me.measureRange,'%.2f ') 'secs | F = ' num2str(me.metadata.ana.frequency) 'Hz, Hanning=' num2str(me.useHanning)]);
			
			box on; grid on;
			ax2.FontSize = 12;
			
			ax3 = nexttile(tl);
			hold on
			if exist('colororder','file')>0; colororder({'k','k'});end
			yyaxis right
			phasePH = analysisCore.areabar(trlColors,me.meanPhaseValues,...
				me.varPhaseValues,[0.6 0.6 0.3],0.2,'LineWidth',1.5);
			try
				phasePH.DataTipTemplate.DataTipRows(1).Label = 'Luminance';
				phasePH.DataTipTemplate.DataTipRows(2).Label = 'Angle';
			end
			%PL3b = plot(trlColors,rad2deg(A),'k-.','Color',[0.6 0.6 0.3],'linewidth',1);
			ylabel('Phase (deg)');
			
			box on; grid on;
			
			yyaxis left
			if me.normalisePowerPlots
				m0 = me.meanPowerValues0 / max(me.meanPowerValues0);
				e0 = me.varPowerValues0 / max(me.meanPowerValues0);
			else
				m0 = me.meanPowerValues0;
				e0 = me.varPowerValues0;
			end
			h0PH = analysisCore.areabar(trlColors,m0,e0,[0.5 0.5 0.7],0.1,...
				'LineWidth',1);
			try
				h0PH.plot.DataTipTemplate.DataTipRows(1).Label = 'Luminance';
				h0PH.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
			end
			
			if me.normalisePowerPlots
				m = me.meanPowerValues / max(me.meanPowerValues);
				e = me.varPowerValues / max(me.meanPowerValues);
			else
				m = me.meanPowerValues;
				e = me.varPowerValues;
			end
			idx = find(m==min(m));
			minC = trlColors(idx);
			ratio = fixColor / minC;
			h1PH = analysisCore.areabar(trlColors,m,e,[0.7 0.2 0.2],0.2,...
				'LineWidth',2);
			try
				h1PH.plot.DataTipTemplate.DataTipRows(1).Label = 'Luminance';
				h1PH.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
			end
			pr = (m .* m0);
			mx = max([max(m) max(m0)]);
			mn = min([min(m) min(m0)]);
			pr = (pr / max(pr)) * mx;
			h0h1PH = plot(trlColors,pr,'--','Color',[0.5 0.5 0.5],...
				'LineWidth',1);
			data.minColor = minC;
			data.ratio = ratio;
			%plot(trlColors,p0 / max(p0),'b--',trlColors,p1 / max(p1),'r:','linewidth',1);
			
			ax3.FontSize = 12;
			ax3.XTick = trlColors;
			ax3.XTickLabel = colorLabels; 
			ax3.XTickLabelRotation = 30;
			if fixColor <= max(trlColors) && fixColor >= min(trlColors)
				line([fixColor fixColor],[ax3.YLim(1) ax3.YLim(2)],...
				'lineStyle',':','Color',[0.3 0.3 0.3 0.5],'linewidth',2);
			end
			if max(me.maxLuminances) == 1
				xlabel('LuminanceStep (0 <-> 1)')
			else
				xlabel('Luminance Step (cd/m^2)')
			end
			if me.normalisePowerPlots
				ylabel('Normalised Power')
			else
				ylabel('Power')
			end
			tit = sprintf('Harmonic Power: %s | %s Min@H1 = %.2f & Ratio = %.2f', tit, varName, data.minColor, data.ratio);
			title(tit);
			legend([h0PH.plot,h1PH.plot,h0h1PH,phasePH.plot],{'H0','H1','H0.*H1','Phase'},...
				'Location','bestoutside','FontSize',10,'Position',[0.9125 0.2499 0.0816 0.0735])
			
			box on; grid on;
			
			handles.ax1 = ax1;
			handles.ax2 = ax2;
			handles.ax3 = ax3;
			handles.PL1 = PL1;
			handles.PL2 = PL2;
			handles.PL3a = phasePH;
			handles.PL3 = h0PH;
			if exist('h1PH','var')
				handles.PL4 = h1PH;
				handles.PL5 = h0h1PH;
			end
			drawnow;
			figure(handles.h2);
			
		end
		
		% ===================================================================
		%> @brief save
		%>
		%> @param file filename to save to
		%> @return
		% ===================================================================
		function save(me, file)
			
			me.pupilData.removeRawData();
			save(file,'me','-v7.3');

		end
	
	% ===================================================================
		%> @brief make the color variables used in plotting
		%>
		%> @param
		%> @return
		% ===================================================================
		function [fixColor,fixName,fColor,varColor,varName,tColor,trlColor,...
				trlColors,tit,colorLabels,step,colorMin,colorMax] = ...
				makecolors(me,fc,cs,ce,vals)
			if ~exist('fc','var') || isempty(fc); fc = me.metadata.ana.colorFixed; end
			if ~exist('cs','var') || isempty(cs); cs = me.metadata.ana.colorStart; end
			if ~exist('ce','var') || isempty(ce); ce = me.metadata.ana.colorEnd; end
			if ~exist('vals','var') || isempty(vals); vals = me.metadata.seq.nVar.values'; end
			
			cNames = {'Red';'Green';'Blue';'Yellow';'Cyan';'Purple'};
			fix = fc .* me.maxLuminances;
			fColor=find(fix > 0); %get the position of not zero
			if all([1 2] == fColor); fColor = 4; end
			fixName = cNames{fColor};
			switch fixName
				case 'Yellow'
					fixColor = fix(1) + fix(2);
				otherwise
					fixColor = fix(fColor);
			end
			
			cE = ce .* me.maxLuminances;
			cS = cs .* me.maxLuminances;
			vColor=find(cE > 0); %get the position of not zero
			if all([1 2] == vColor); vColor = 4; end
			varName = cNames{vColor};
			switch varName
				case 'Yellow'
					varColor = cS(1) + cS(2);
				otherwise
					varColor = cS(vColor);
			end

			vals = cellfun(@(x) x .* me.maxLuminances, vals, 'UniformOutput', false);
			tit = num2str(fix,'%.2f ');
			tit = regexprep(tit,'0\.00','0');
			tit = ['Fix color (' fixName ') = ' tit ' | Var color (' varName ')'];
			colorChange= cE - cS;
			tColor=find(colorChange~=0); %get the position of not zero
			step=abs(colorChange(tColor)/me.metadata.ana.colorStep);
			trlColor=cell2mat(vals);
			switch varName
				case 'Yellow'
					trlColors = trlColor(:,1)' + trlColor(:,2)';
					colorMin = min(trlColor(:,1)) + min(trlColor(:,2));
					colorMax = max(trlColor(:,1)) + max(trlColor(:,2));
				otherwise
					trlColors = trlColor(:,tColor)';
					colorMax=max(trlColor(:,tColor));
					colorMin=min(trlColor(:,tColor));
			end
			
			colorLabels = num2cell(trlColors);
			colorLabels = cellfun(@(x) num2str(x,'%.2f'), colorLabels, 'UniformOutput', false);
			
		end
	end
	
	
	%=======================================================================
	methods (Access = protected) %------------------PRIVATE METHODS
	%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function load(me, force)
			if ~exist('force','var') || isempty(force); force = false; end
			if me.isLoaded && ~force; return; end
			try
				if ~isempty(me.fileName)
					me.pupilData=eyelinkAnalysis('file',me.fileName,'dir',me.rootDirectory);
				else
					me.pupilData=eyelinkAnalysis;
					me.fileName = me.pupilData.file;
					me.rootDirectory = me.pupilData.dir;
				end
				[~,fn] = fileparts(me.pupilData.file);
				me.metadata = load([me.pupilData.dir,filesep,fn,'.mat']); %load .mat of same filename with .edf
				if isa(me.metadata.sM.gammaTable,'calibrateLuminance') && ~isempty(me.metadata.sM.gammaTable)
					if ~isempty(me.metadata.sM.gammaTable.inputValuesTest)
						l = me.metadata.sM.gammaTable.inputValuesTest;
					else
						l = me.metadata.sM.gammaTable.inputValues;
					end
					me.maxLuminances(1) = l(2).in(end);
					me.maxLuminances(2) = l(3).in(end);
					me.maxLuminances(3) = l(4).in(end);
				else
					me.maxLuminances = me.defLuminances;
				end
				
				me.pupilData.plotRange = [-0.5 3.5];
				me.pupilData.measureRange = me.measureRange;
				me.pupilData.pixelsPerCm = me.metadata.sM.pixelsPerCm;
				me.pupilData.distance = me.metadata.sM.distance;
				
				fprintf('\n<strong>--->>></strong> LOADING raw EDF data: \n')
				parseSimple(me.pupilData);
				me.pupilData.removeRawData();me.isRawDataRemoved=true;
				me.isLoaded = true;
			catch ME
				getReport(ME);
				me.isLoaded = false;
				rethrow(ME)
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function calculate(me)
			if ~me.isLoaded; return; end
			Fs1 = me.pupilData.sampleRate; % Sampling frequency
			T1 = 1/Fs1; % Sampling period
			smoothSamples = me.smoothWindow / (T1 * 1e3);
			me.SortedPupil = [];me.powerValues=[];me.powerValues0=[];me.rawP = []; me.rawF = []; me.rawPupil = []; me.rawTimes=[];
			thisTrials = me.pupilData.trials(me.pupilData.correct.idx);
			for i=1:length(thisTrials)
				
				me.SortedPupil(1).anaTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks))=me.metadata.ana.trial(i);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks))=thisTrials(i);
				idx=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).times>=-1000;
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).times=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).times(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).gx=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).gx(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).gy=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).gy(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).hx=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).hx(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).hy=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).hy(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).pa=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/me.metadata.seq.minBlocks)).pa(idx);
				
			end
			
			thisTrials = me.SortedPupil.pupilTrials;
			numvars=size(thisTrials,1); %Number of trials
			numBlocks=size(thisTrials,2); %Number of Blocks
			t1=tic;
			for currentVar=1:numvars
				if isempty(me.SortedPupil.pupilTrials(currentVar).variable)==0
					k=1;	F=[];	P=[];	Pu=[];	Ti=[];
					for currentBlock=1:numBlocks
						if isempty(me.SortedPupil.pupilTrials(currentVar,currentBlock).variable)==0
							pa = thisTrials(currentVar,currentBlock).pa;
							ta = thisTrials(currentVar,currentBlock).times / 1e3;
							if me.smoothPupil
								pa = smoothdata(pa,me.smoothMethod,smoothSamples);
							end				
							me.rawPupil{currentVar,currentBlock} = pa;
							me.rawTimes{currentVar,currentBlock} = ta;
							
							p = me.rawPupil{currentVar,currentBlock};
							t = me.rawTimes{currentVar,currentBlock};
							
							if me.normaliseBaseline
								idx = t >= me.baselineWindow(1) & t <= me.baselineWindow(2);
								mn = mean(p(idx));
								p = p - mn;
							end
							
							idx = t >= me.measureRange(1) & t <= me.measureRange(2);
							p = p(idx);
							if me.detrend
								p = p - mean(p);
							end
							
							[P,f,A,p1,p0] = me.doFFT(p);
							
							me.powerValues(currentVar,currentBlock) = p1; %get the pupil power of tagging frequency
							me.phaseValues(currentVar,currentBlock) = rad2deg(A);
							me.powerValues0(currentVar,currentBlock) = p0; %get the pupil power of 0 harmonic
							me.rawF{currentVar,currentBlock} = f;
							me.rawP{currentVar,currentBlock} = P;
							rawFramef(k)=size(me.rawF{currentVar,currentBlock},2);
							rawFramePupil(k)=size(me.rawPupil{currentVar,currentBlock},2);
							k=k+1;
						end
					end
					rawFramefMin(currentVar)=min(rawFramef);
					rawFramePupilMin(currentVar)=min(rawFramePupil);
					for currentBlock=1:numBlocks
						if ~isempty(me.SortedPupil.pupilTrials(currentVar,currentBlock).variable)
							F(currentBlock,:)=me.rawF{currentVar,currentBlock}(1,1:rawFramefMin(currentVar));
							P(currentBlock,:)=me.rawP{currentVar,currentBlock}(1,1:rawFramefMin(currentVar));
							Pu(currentBlock,:)=me.rawPupil{currentVar,currentBlock}(1,1:rawFramePupilMin(currentVar));
							Ti(currentBlock,:)=me.rawTimes{currentVar,currentBlock}(1,1:rawFramePupilMin(currentVar));
						end
					end
					
					me.meanF{currentVar,1} = F(1,:);
					[p,e] = analysisCore.stderr(P,me.error,false,0.05,1);
					me.meanP{currentVar,1}=p;
					me.varP{currentVar,1}=e;
					
					me.meanTimes{currentVar,1} = Ti(1,:);
					[p,e] = analysisCore.stderr(Pu,me.error,false,0.05,1);
					me.meanPupil{currentVar,1}=p;
					me.varPupil{currentVar,1}=e;
					
				end
			end
			toc(t1);
			pV=me.powerValues;
			pV(pV==0)=NaN;
			[p,e] = analysisCore.stderr(pV,me.error,false,0.05,2);
			me.meanPowerValues = p';
			me.varPowerValues = e';
			me.varPowerValues(me.varPowerValues==inf)=0;
			
			pH=me.phaseValues;
			pH(pH==0)=NaN;
			[p,e] = analysisCore.stderr(pH,me.error,false,0.05,2);
			me.meanPhaseValues = p';
			me.varPhaseValues = e';
			me.varPhaseValues(me.varPhaseValues==inf)=0;
			
			pV0=me.powerValues0;
			pV0(pV0==0)=NaN;
			[p,e] = analysisCore.stderr(pV0,me.error,false,0.05,2);
			me.meanPowerValues0 = p';
			me.varPowerValues0 = e';
			me.varPowerValues0(me.varPowerValues0==inf)=0;
			
			me.isCalculated = true;
		end
		
		% ===================================================================
		%> @brief do the FFT
		%>
		%> @param p the raw signal
		%> @return 
		% ===================================================================
		function [P, f, A, p1, p0] = doFFT(me,p)	
			useX = true;
			L = length(p);
			if me.useHanning
				win = hanning(L, 'periodic');
				P = fft(p.*win'); 
			else
				P = fft(p);
			end
			
			if useX
				Pi = fft(p);
				P = abs(Pi/L);
				P=P(1:floor(L/2)+1);
				P(2:end-1) = 2*P(2:end-1);
				f = me.pupilData.sampleRate * (0:(L/2))/L;
			else
				Pi = fft(p);
				NumUniquePts = ceil((L+1)/2);
				P = abs(Pi(1:NumUniquePts));
				f = (0:NumUniquePts-1)*me.pupilData.sampleRate/L;
			end
			
			idx = analysisCore.findNearest(f, me.metadata.ana.frequency);
			p1 = P(idx);
			A = angle(Pi(idx));
			idx = analysisCore.findNearest(f, 0);
			p0 = P(idx);
				
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function closeUI(me, varargin)
			try delete(me.handles.parent); end %#ok<TRYNC>
			me.handles = struct();
			me.openUI = false;
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function makeUI(me, varargin) %#ok<INUSD>
			disp('Feature not finished yet...')
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function updateUI(me, varargin) %#ok<INUSD>
			disp('Feature not finished yet...')
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function notifyUI(me, varargin) %#ok<INUSD>
			disp('Feature not finished yet...')
		end
		
	end
end

