classdef pupilPower < analysisCore
	%PUPILPOWER Calculate power for each trial from EDF file pupil data
	
	%------------------PUBLIC PROPERTIES----------%
	properties
		%> eyelink parsed edf data
		pupilData eyelinkAnalysis
		%> plot verbosity
		verbose = true
		%> normalise the pupil diameter to the baseline?
		normaliseBaseline logical = true
		colorMap = 'jet';
		maxLuminances = [1 1 1]
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
		allowedProperties char = 'pupilData|normaliseBaseline|colormap'
	end
	
	%=======================================================================
	methods
		%=======================================================================
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function me = pupilPower(varargin)
			if nargin == 0
				varargin.measureRange = [0.5 3.5];
				varargin.baselineWindow = [-0.3 0];
				varargin.plotRange = [];
			end
			me = me@analysisCore(varargin); %superclass constructor
			if nargin>0; me.parseArgs(varargin, me.allowedProperties); end
			if isempty(me.name); me.name = 'pupilPower'; end
			if isempty(me.pupilData)
				run(me);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function run(me, force)
			if ~exist('force','var') || isempty(force); force = false; end
			me.load(force);
			me.calculate();
			if me.doPlots; me.plot(); end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(me)
			if ~me.isCalculated; return; end
			fix = me.metadata.ana.colorFixed .* me.maxLuminances;
			fColor=find(fix~=0); %get the position of not zero
			fixColor = fix(fColor);
			cE = me.metadata.ana.colorEnd .* me.maxLuminances;
			cS = me.metadata.ana.colorStart .* me.maxLuminances;
			vals = me.metadata.seq.nVar.values';
			vals = cellfun(@(x) x .* me.maxLuminances, vals, 'UniformOutput', false);
			tit = num2str(fix,'%.2f ');
			tit = regexprep(tit,'0\.00','0');
			tit = ['Fixed Colour = ' tit];
			colorChange= cE - cS;
			tColor=find(colorChange~=0); %get the position of not zero
			step=abs(colorChange(tColor)/me.metadata.ana.colorStep);
			trlColor=cell2mat(vals);
			trlColors = trlColor(:,tColor)';
			nms = num2cell(trlColors);
			nms = cellfun(@(x) num2str(x,'%.2f'), nms, 'UniformOutput', false);
			colorMax=max(trlColor(:,tColor));
			colorMin=min(trlColor(:,tColor));
			
			h=figure;figpos(1,[1500 1000]);set(h,'Color',[1 1 1],'NumberTitle','off',...
				'Name',['pupilPower: ' me.pupilData.file]);
			plotColor=zeros(1,3);
			plotColor(1,tColor)=1;        %color of line in the plot
			
			numVars = length(me.meanPowerValues);
			traceColor = colormap(me.colorMap);
			traceColor_step = floor(length(traceColor)/numVars);
			subplot(411)
			trlColor(numVars+1,:)=trlColor(numVars,:);
			PL = stairs(1:numVars+1, trlColor(:,tColor),'color',plotColor,'LineWidth',2);
			PL.Parent.FontSize = 7;
			PL.Parent.XTick = 1.5:1:numVars+0.5;
			PL.Parent.XTickLabel = nms; 
			PL.Parent.XTickLabelRotation = 30;
			xlim([0.5 numVars+1.5])
			xlabel('Step (cd/m2)')
			ylim([colorMin-step colorMax+step])
			set(gca,'ytick',colorMin-step:2*step:colorMax+step)
			ylabel('Luminance')
			title(tit);
			box on; grid on;
			
			ax2 = subplot(412);
			hold on
			PL1 = areabar(trlColors,me.meanPowerValues0,me.varPowerValues0,[0.3 0.3 0.5],'Color',[0.3 0.3 0.5],'LineWidth',1);
			PL1.plot.DataTipTemplate.DataTipRows(1).Label = 'Time';
			PL1.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
			PL2 = areabar(trlColors,me.meanPowerValues,me.varPowerValues,[0.7 0.3 0.3],'Color',[0.7 0.3 0.3],'LineWidth',1);
			PL2.plot.DataTipTemplate.DataTipRows(1).Label = 'Time';
			PL2.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
			pr = (me.meanPowerValues .* me.meanPowerValues0);
			mx = max([max(me.meanPowerValues0) max(me.meanPowerValues0)]);
			mn = min([min(me.meanPowerValues0) min(me.meanPowerValues0)]);
			pr = (pr / max(pr)) * mx;
			PL3 = plot(trlColors,pr,'--','Color',[0 0.4 0],'LineWidth',1);
			ax2.FontSize = 7;
			ax2.XTick = trlColors;
			ax2.XTickLabel = nms; 
			ax2.XTickLabelRotation = 30;
			line([fixColor fixColor],[ax2.YLim(1) ax2.YLim(2)],...
				'lineStyle',':','Color',[0.5 0.5 0.5 0.5],'linewidth',1)
			xlabel('Luminance step (cd/m2)')
			ylabel('Power')
			title(tit);
			legend([PL1.plot,PL2.plot,PL3],{'0F','1F','Prod'})
			box on; grid on;
			
			subplot(413)
			f = round(me.metadata.ana.onFrames) * (1 / me.metadata.sM.screenVals.fps);
			m = 1:2:31;
			for i = 1 : floor(me.metadata.ana.trialDuration / f / 2)
				rectangle('Position',[f*m(i) -6000 f 12000],'FaceColor',[0.8 0.8 0.8 0.3],'EdgeColor','none')
			end
			maxp = 0;
			minp = 0;
			for i = 1: length(me.meanPupil)
				hold on
				t = me.meanTimes{i};
				p = me.meanPupil{i};
				idx = t >= -1;
				t = t(idx);
				p = p(idx);
				
				if me.normaliseBaseline
					idx = t >= me.baselineWindow(1) & t <= me.baselineWindow(2);
					mn = median(p(idx));
					p = p - mn;
				end
				
				idx = t >= me.measureRange(1) & t <= me.measureRange(2);
				maxp = max([maxp max(p(idx))]);
				minp = min([minp min(p(idx))]);
				
				PL = plot(t, p,'color', traceColor(i*traceColor_step,:), 'LineWidth', 1);
				PL.DataTipTemplate.DataTipRows(1).Label = 'Time';
				PL.DataTipTemplate.DataTipRows(2).Label = 'Power';

			end
			xlabel('Time (s)')
			ylabel('Pupil Diameter')
			title(['Pupil Diameter'])
			xlim([-0.05 me.measureRange(2)+0.1]);
			ylim([minp+(minp/10) maxp+(maxp/10)]);
			box on; grid on;
			
			ax4 = subplot(414);
			maxP = 0;
			for i = 1: length(me.meanF)
				hold on
				F = me.meanF{i};
				P = me.meanP{i};
				idx = F < 20;
				F = F(idx);
				P = P(idx);
				maxP = max([maxP max(P)]);
				PL = plot(F,P,'color', traceColor(i*traceColor_step,:),...
					'Marker','o','DisplayName',nms{i});	
				PL.DataTipTemplate.DataTipRows(1).Label = 'Frequency';
				PL.DataTipTemplate.DataTipRows(2).Label = 'Power';
			end
			xlim([-0.1 floor(me.metadata.ana.frequency*3)]);
			ylim([0 maxP+(maxP/20)]);
			line([me.metadata.ana.frequency me.metadata.ana.frequency],[ax4.YLim(1) ax4.YLim(2)],...
				'Color',[0.5 0.5 0.5 0.5],'linestyle',':','LineWidth',1);
			%ax4.XScale = 'log';
			xlabel('Frequency (Hz)');
			ylabel('Power');
			legend(nms,'Location','bestoutside','FontSize',5);
			title(['FFT Power (F = ' num2str(me.metadata.ana.frequency) ')'])
			box on; grid on;
			
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
				me.pupilData=eyelinkAnalysis;
				parseSimple(me.pupilData);
				[~,fn] = fileparts(me.pupilData.file);
				me.metadata = load([me.pupilData.dir,fn,'.mat']); %load .mat of same filename with .edf
				if isa(me.metadata.sM.gammaTable,'calibrateLuminance') && ~isempty(me.metadata.sM.gammaTable)
					if ~isempty(me.metadata.sM.gammaTable.inputValuesTest)
						l = me.metadata.sM.gammaTable.inputValuesTest;
					else
						l = me.metadata.sM.gammaTable.inputValues;
					end
					me.maxLumiances(1) = l(2).in(end);
					me.maxLumiances(2) = l(3).in(end);
					me.maxLumiances(1) = l(4).in(end);
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
							me.rawPupil{currentVar,currentBlock} = thisTrials(currentVar,currentBlock).pa;
							me.rawTimes{currentVar,currentBlock} = thisTrials(currentVar,currentBlock).times / 1e3;
							p = me.rawPupil{currentVar,currentBlock};
							t = me.rawTimes{currentVar,currentBlock};
							
							if me.normaliseBaseline
								idx = t >= me.baselineWindow(1) & t <= me.baselineWindow(2);
								mn = median(p(idx));
								p = p - mn;
							end
							
							idx = t >= me.measureRange(1) & t <= me.measureRange(2);
							p = p(idx);
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
					[p,e] = analysisCore.stderr(P,'SE',false,0.05,1);
					me.meanP{currentVar,1}=p;
					me.varP{currentVar,1}=e;
					
					me.meanTimes{currentVar,1} = Ti(1,:);
					[p,e] = analysisCore.stderr(Pu,'SE',false,0.05,1);
					me.meanPupil{currentVar,1}=p;
					me.varPupil{currentVar,1}=e;
					
				end
			end
			toc(t1);
			pV=me.powerValues;
			pV(pV==0)=NaN;
			[p,e] = analysisCore.stderr(pV,'SE',false,0.05,2);
			me.meanPowerValues = p';
			me.varPowerValues = e';
			me.varPowerValues(me.varPowerValues==inf)=0;
			
			pV0=me.powerValues0;
			pV0(pV0==0)=NaN;
			[p,e] = analysisCore.stderr(pV0,'SE',false,0.05,2);
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

