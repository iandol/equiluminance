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
		colorMap = 'jet';
		%> actual R G B luminance maxima, if [1 1 1] then use 0<->1
		%> floating point range
		maxLuminances = [1 1 1]
		%> smooth the pupil data?
		smoothPupil logical = true;
		%> smoothing window in milliseconds
		smoothWindow = 30;
		%> smooth method
		smoothMethod = 'gaussian'
		%> draw error bars on raw pupil plots
		drawError logical = true
		%> error bars
		error = 'SE';
		%> downsample raw pupil for plotting only (every N points)
		downSample = 20;
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = public)
		metadata struct
		SortedPupil struct
		powerValues
		powerValues0
		varPowerValues
		varPowerValues0
		meanPowerValues
		meanPowerValues0
		rawPupil cell
		meanPupil
		varPupil
		rawTimes cell
		meanTimes
		rawF cell
		meanF
		rawP cell
		meanP
		varP
		isLoaded logical = false
		isCalculated logical = false
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction, see parseArgs
		allowedProperties char = ['fileName|pupilData|normaliseBaseline|normalisePowerPlots|error|colormap|'...
		'maxLuminances|smoothPupil|smoothMethod|drawError|downSample']
	end
	
	%=======================================================================
	methods
		%=======================================================================
		
		% =========false==========================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function me = pupilPower(varargin)
			defaults.measureRange = [0.25 3.65];
			defaults.baselineWindow = [-0.2 0.2];
			defaults.plotRange = [];
			varargin = optickaCore.addDefaults(varargin,defaults);
			me = me@analysisCore(varargin); %superclass constructor
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			if ~isempty(me.fileName)
				[p,f,e] = fileparts(me.fileName);
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
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function handles = run(me, force)
			if ~exist('force','var') || isempty(force); force = false; end
			me.load(force);
			me.calculate();
			if me.doPlots; handles = me.plot(); end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function handles = plot(me)
			if ~me.isCalculated; return; end
			fix = me.metadata.ana.colorFixed .* me.maxLuminances;
			fColor=find(fix > 0); %get the position of not zero
			switch fColor(1)
				case 1
					fixName = 'Red';
				case 2
					fixName = 'Green';
				otherwise
					fixName = 'Blue';
			end
			fixColor = fix(fColor);
			cE = me.metadata.ana.colorEnd .* me.maxLuminances;
			cS = me.metadata.ana.colorStart .* me.maxLuminances;
			vColor=find(cE > 0); %get the position of not zero
			switch vColor(1)
				case 1
					varName = 'Red';
				case 2
					varName = 'Green';
				otherwise
					varName = 'Blue';
			end
			vals = me.metadata.seq.nVar.values';
			vals = cellfun(@(x) x .* me.maxLuminances, vals, 'UniformOutput', false);
			tit = num2str(fix,'%.2f ');
			tit = regexprep(tit,'0\.00','0');
			tit = ['Fixed Colour (' fixName ') = ' tit ' | Variable Colour = ' varName];
			colorChange= cE - cS;
			tColor=find(colorChange~=0); %get the position of not zero
			step=abs(colorChange(tColor)/me.metadata.ana.colorStep);
			trlColor=cell2mat(vals);
			trlColors = trlColor(:,tColor)';
			nms = num2cell(trlColors);
			nms = cellfun(@(x) num2str(x,'%.2f'), nms, 'UniformOutput', false);
			colorMax=max(trlColor(:,tColor));
			colorMin=min(trlColor(:,tColor));
			
			handles.h1=figure;figpos(1,[1000 625]);set(handles.h1,'Color',[1 1 1],'NumberTitle','off',...
				'Name',['pupilPower: ' me.pupilData.file]);
			set(handles.h1,'Papertype','a4','PaperUnits','centimeters','PaperOrientation','landscape','Renderer','painters')
			plotColor=zeros(1,3);
			plotColor(1,tColor)=1;        %color of line in the plot
			numVars = length(me.meanPowerValues);
			traceColor = colormap(me.colorMap);
			traceColor_step = floor(length(traceColor)/numVars);
			trlColor(numVars+1,:)=trlColor(numVars,:);
			PL = stairs(1:numVars+1, trlColor(:,tColor),'color',plotColor,'LineWidth',2);
			PL.Parent.FontSize = 8;
			PL.Parent.XTick = 1.5:1:numVars+0.5;
			PL.Parent.XTickLabel = nms; 
			PL.Parent.XTickLabelRotation = 30;
			xlim([0.5 numVars+1.5])
			if max(me.maxLuminances) == 1
				xlabel('Step (0 <-> 1)')
			else
				xlabel('Step (cd/m2)')
			end
			ylim([colorMin-step colorMax+step])
			set(gca,'ytick',colorMin-step:2*step:colorMax+step)
			ylabel('Luminance')
			title(tit);
			box on; grid on;
			
			handles.h2=figure;figpos(1,[1900 1200]);set(handles.h2,'Color',[1 1 1],'NumberTitle','off',...
				'Name',['pupilPower: ' me.pupilData.file]);
			set(handles.h2,'Papertype','a4','PaperUnits','centimeters','PaperOrientation','landscape','Renderer','painters')
			
			ax1 = subplot(311);
			f = round(me.metadata.ana.onFrames) * (1 / me.metadata.sM.screenVals.fps);
			m = 1:2:31;
			for i = 1 : floor(me.metadata.ana.trialDuration / f / 2)
				rectangle('Position',[f*m(i) -10000 f 20000],'FaceColor',[0.8 0.8 0.8 0.3],'EdgeColor','none')
			end
			maxp = -inf;
			minp = inf;
			for i = 1: length(me.meanPupil)
				hold on
				t = me.meanTimes{i};
				p = me.meanPupil{i};
				e = me.varPupil{i};
				idx = t >= -1;
				t = t(idx);
				p = p(idx);
				e = e(idx);
				
				if me.normaliseBaseline
					idx = t >= me.baselineWindow(1) & t <= me.baselineWindow(2);
					mn = median(p(idx));
					p = p - mn;
				end
				
				if me.pupilData.sampleRate > 500
					idx = logical(mod(1:length(t),me.downSample)); %downsample every N as less points to draw
					t(idx) = [];
					p(idx) = [];
					e(idx) = [];
				end
				
				idx = t >= me.measureRange(1) & t <= me.measureRange(2);
				maxp = max([maxp max(p(idx))]);
				minp = min([minp min(p(idx))]);
				
				if me.drawError
					PL1 = areabar(t,p,e,traceColor(i*traceColor_step,:),...
						'Color', traceColor(i*traceColor_step,:), 'LineWidth', 1,'DisplayName',nms{i});
					PL1.plot.DataTipTemplate.DataTipRows(1).Label = 'Time';
					PL1.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
				else
					PL1 = plot(t,p,'color', traceColor(i*traceColor_step,:),...
						'LineWidth', 1,'DisplayName',nms{i});
					PL1.DataTipTemplate.DataTipRows(1).Label = 'Time';
					PL1.DataTipTemplate.DataTipRows(2).Label = 'Power';
				end %close(handles.h1);
				
			end
			xlabel('Time (s)')
			ylabel('Diameter')
			if me.normaliseBaseline
				title(['Normalised Pupil  (' num2str(me.baselineWindow,'%.2f ')...
					') | Trials = ' num2str(me.metadata.ana.trialNumber) ' | Subject = ' me.metadata.ana.subject]);
			else
				title(['Raw Pupil | Trials = ' num2str(me.metadata.ana.trialNumber) ' | Subject = ' me.metadata.ana.subject])
			end
			xlim([-0.05 me.measureRange(2)+0.05]);
			if minp < 0
				ylim([minp+(minp/100*2) maxp+(maxp/100*2)]);
			else
				ylim([minp-(minp/100*2) maxp+(maxp/100*2)]);
			end
			legend(nms,'Location','bestoutside','FontSize',5,...
				'Position',[0.9125 0.5673 0.0779 0.3550]);
			box on; grid on;
			ax1.XMinorGrid = 'on';
			ax1.FontSize = 8;
			
			ax2 = subplot(312);
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
					'Marker','o','DisplayName',nms{i},...
					'MarkerSize', 5,'MarkerFaceColor',traceColor(i*traceColor_step,:),...
					'MarkerEdgeColor', 'none');	
				PL2.DataTipTemplate.DataTipRows(1).Label = 'Frequency';
				PL2.DataTipTemplate.DataTipRows(2).Label = 'Power';
			end
			xlim([-0.1 floor(me.metadata.ana.frequency*3)]);
			ylim([0 maxP+(maxP/20)]);
			xlabel('Frequency (Hz)');
			ylabel('Power');
			if ~me.normaliseBaseline
				ax2.YScale = 'log';
				ylabel('Power [log]');
			end
			line([me.metadata.ana.frequency me.metadata.ana.frequency],[ax2.YLim(1) ax2.YLim(2)],...
				'Color',[0.3 0.3 0.3 0.5],'linestyle',':','LineWidth',2);
			title(['FFT Power (T=' num2str(me.measureRange,'%.2f ') ' F = ' num2str(me.metadata.ana.frequency) ')'])
			
			box on; grid on;
			ax2.FontSize = 8;
			
			ax3 = subplot(313);
			hold on
			if me.normalisePowerPlots
				m0 = me.meanPowerValues0 / max(me.meanPowerValues0);
				e0 = me.varPowerValues0 / max(me.meanPowerValues0);
			else
				m0 = me.meanPowerValues0;
				e0 = me.varPowerValues0;
			end
			PL3 = areabar(trlColors,m0,e0,[0.3 0.3 0.6],'Color',[0.3 0.3 0.6],'LineWidth',1);
			PL3.plot.DataTipTemplate.DataTipRows(1).Label = 'Time';
			PL3.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
			if me.normalisePowerPlots
				m = me.meanPowerValues / max(me.meanPowerValues);
				e = me.varPowerValues / max(me.meanPowerValues);
			else
				m = me.meanPowerValues;
				e = me.varPowerValues;
			end
			PL4 = areabar(trlColors,m,e,[0.7 0.2 0.2],'Color',[0.7 0.2 0.2],'LineWidth',1);
			PL4.plot.DataTipTemplate.DataTipRows(1).Label = 'Time';
			PL4.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
			pr = (m .* m0);
			mx = max([max(m) max(m0)]);
			mn = min([min(m) min(m0)]);
			pr = (pr / max(pr)) * mx;
			PL5 = plot(trlColors,pr,'--','Color',[0.4 0.4 0.4],'LineWidth',2);
			ax3.FontSize = 8;
			ax3.XTick = trlColors;
			ax3.XTickLabel = nms; 
			ax3.XTickLabelRotation = 30;
			line([fixColor fixColor],[ax3.YLim(1) ax3.YLim(2)],...
				'lineStyle',':','Color',[0.3 0.3 0.3 0.5],'linewidth',2)
			if max(me.maxLuminances) == 1
				xlabel('LuminanceStep (0 <-> 1)')
			else
				xlabel('Luminance Step (cd/m2)')
			end
			if me.normalisePowerPlots
				ylabel('Normalised Power')
			else
				ylabel('Power')
			end
			title(tit);
			legend([PL3.plot,PL4.plot,PL5],{'0H','1H','.Prod'},...
				'Location','bestoutside','FontSize',5,'Position',[0.9125 0.2499 0.0816 0.0735])
			box on; grid on;
			
			handles.ax1 = ax1;
			handles.ax2 = ax2;
			handles.ax3 = ax3;
			handles.Pl1 = PL1;
			handles.PL2 = PL2;
			handles.PL3 = PL3;
			handles.PL4 = PL4;
			handles.PL5 = PL5;
			
			drawnow;
			figure(handles.h2);
			
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
				end
				parseSimple(me.pupilData);
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
					me.maxLuminances(1) = l(4).in(end);
				end
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
							t = t(idx);
							
							L=length(p);
							P1 = fft(p);
							P2 = abs(P1/L);
							P3=P2(1:floor(L/2)+1);
							P3(2:end-1) = 2*P3(2:end-1);
							f=Fs1*(0:(L/2))/L;
							idx = analysisCore.findNearest(f, me.metadata.ana.frequency);
							me.powerValues(currentVar,currentBlock) = P3(idx); %get the pupil power of tagging frequency
							idx = analysisCore.findNearest(f, 0);
							me.powerValues0(currentVar,currentBlock) = P3(idx); %get the pupil power of 0 harmonic
							me.rawF{currentVar,currentBlock} = f;
							me.rawP{currentVar,currentBlock} = P3;
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
			
			pV0=me.powerValues0;
			pV0(pV0==0)=NaN;
			[p,e] = analysisCore.stderr(pV0,me.error,false,0.05,2);
			me.meanPowerValues0 = p';
			me.varPowerValues0 = e';
			me.varPowerValues0(me.varPowerValues0==inf)=0;
			
			me.isCalculated = true;
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

