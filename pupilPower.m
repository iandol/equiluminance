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
		colorMap char = 'turbo';
		%> actual R G B luminance maxima for display, if [1 1 1] then use 0<->1
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
		%> the calibration data from the display++
		calibrationFile = ''
	end
	
	properties (Hidden = true)
		%> default R G B luminance maxima, if [1 1 1] then use 0<->1
		%> floating point range, compatibility with older code, use
		%> maxLumiances
		defLuminances double = [1 1 1]
		%> use simple luminance or the linear regression
		simpleMode = false
		%> choose which variables to plot
		xpoints = []
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
		SortedPupil struct
		taggingFrequency = []
	end
	
	%------------------PROTECTED PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = public, Hidden = true)
		powerValues
		phaseValues
		powerValues0
		metadata struct
		rawPupil cell
		rawTimes cell
		rawF cell
		rawP cell
		isLoaded logical = false
		isCalculated logical = false
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> the luminance data
		c
		%> processed luminance data
		l
		%> raw data removed, cannot reparse from EDF events.
		isRawDataRemoved logical = false
		%> allowed properties passed to object upon construction, see parseArgs
		allowedProperties char = ['calibrationFile|useHanning|defLuminances|fileName|pupilData|'...
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
			defaults.measureRange = [1.23 3.5];
			defaults.baselineWindow = [-0.2 0.2];
			defaults.plotRange = [];
			if ~exist('turbo.m','file')
				defaults.colorMap = 'jet';
			end
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
		%> @brief validate 
		% ===================================================================
		function set.maxLuminances(me,value)
			if all( [1 3] == size(value) )
				me.maxLuminances = value;
			elseif all( [3 1] == size(value) )
				me.maxLuminances = value';
			else 
				me.maxLuminances = [1 1 1];
			end
		end
		
		% ===================================================================
		%> @brief run full analysis and plot the result
		%>
		%> @param force: reload the EDF and reparse
		%> @return
		% ===================================================================
		function [handles,data] = run(me, force)
			if ~me.simpleMode;loadCalibration(me); fitLuminances(me);end
			if isempty(me.l); me.simpleMode = true; end
			if ~exist('force','var') || isempty(force); force = false; end
			me.load(force);
			
			if isfield(me.metadata.ana,'onFrames')
				me.taggingFrequency = (me.metadata.sM.screenVals.fps/me.metadata.ana.onFrames) / 2;
			else
				me.taggingFrequency = me.metadata.ana.frequency;
			end
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
			
			handles.h1=figure;figpos(2,[1000 500]);set(handles.h1,'Color',[1 1 1],'NumberTitle','off',...
				'Name',['pupilPower: ' me.pupilData.file],'Papertype','a4','PaperUnits','centimeters',...
				'PaperOrientation','landscape','Renderer','painters');
			switch varName
				case 'Grey'
					plotColor = [0.5 0.5 0.5];
				case 'Yellow'
					plotColor = [0.8 0.8 0];
				otherwise
					plotColor = zeros(1,3);	plotColor(1,tColor)	= 0.8;
			end
			switch fixName
				case 'Grey'
					lineColor = [0.5 0.5 0.5];
				case 'Yellow'
					lineColor = [0.8 0.8 0];
				otherwise
					lineColor = zeros(1,3);	lineColor(1,fColor)	= 0.8;
			end
			pCorrect = (length(me.pupilData.correct.idx)/length(me.pupilData.trials))*100;
			if me.simpleMode && max(me.maxLuminances) > 1
				 mode = 'simple';
			elseif ~me.simpleMode && max(me.maxLuminances) == 1
				mode = 'none';
			else
				mode = 'full';
			end
			t2 = sprintf('LumCorrect:%s | %i / %i = %.2f%% | background: %s',...
				mode, length(me.pupilData.correct.idx),length(me.pupilData.trials), ...
				pCorrect,num2str(me.metadata.ana.backgroundColor,'%.3f '));
			
			if isempty(me.xpoints)
				start = 1;
				finish = length(colorLabels);
				numVars	= finish;
			else
				start = me.xpoints(1);
				finish = me.xpoints(2);
				numVars = (finish-start) + 1;
			end
			
			csteps = trlColors(start:finish);
			csteps(numVars+1) = csteps(numVars);
			PL = stairs(1:numVars+1, csteps, 'Color',plotColor,'LineWidth',2);
			PL.Parent.FontSize = 11;
			PL.Parent.XTick = 1.5:1:numVars+0.5;
			PL.Parent.XTickLabel = colorLabels; 
			PL.Parent.XTickLabelRotation = 30;
			xlim([0.5 numVars+1.5])
			ax = axis;
			line([ax(1) ax(2)],[fixColor(1) fixColor(1)],'Color',lineColor,'Linewidth',2);
			if max(me.maxLuminances) == 1
				xlabel('Step (0 <-> 1)')
			else
				xlabel('Step (cd/m^2)')
			end
			ylim([min(csteps)-step(1) max(csteps)+step(1)])
			%set(gca,'ytick',colorMin-step:2*step:colorMax+step)
			ylabel('Luminance (cd/m^2)')
			title([tit t2]);
			box on; grid on;
			
			handles.h2=figure;figpos(1,[0.9 0.9],[],'%');set(handles.h2,'Color',[1 1 1],'NumberTitle','off',...
				'Name',['pupilPower: ' me.pupilData.file],'Papertype','a4','PaperUnits','centimeters',...
				'PaperOrientation','landscape','Renderer','painters');
			tl = tiledlayout(handles.h2,2,3,'TileSpacing','compact');
			ax1 = nexttile(tl,[1 3]);
			traceColor				= colormap(me.colorMap);
			traceColor_step			= floor(length(traceColor)/numVars);
			
			f = round(me.metadata.ana.onFrames) * (1 / me.metadata.sM.screenVals.fps);
			if isfield(me.metadata.ana,'flashFirst') && me.metadata.ana.flashFirst == true
				m = 0:2:100;
			else
				m = 1:2:101;
			end
			for i = 1 : floor(me.metadata.ana.trialDuration / f / 2) + 1
				rectangle('Position',[f*m(i) -10000 f 20000],'FaceColor',[0.8 0.8 0.8 0.3],'EdgeColor','none')
			end
			maxp = -inf;
			minp = inf;
			
			a = 0;
			for i = start : finish %length(me.meanPupil)
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
				
				idx = t >= me.measureRange(1) & t <= me.measureRange(2);
				maxp = max([maxp max(p(idx))]);
				minp = min([minp min(p(idx))]);

				if ~isempty(p)
					if me.drawError
						PL1 = analysisCore.areabar(t,p,e,traceColor((a*traceColor_step)+1,:),0.2,...
							'Color', traceColor((a*traceColor_step)+1,:), 'LineWidth', 2,'DisplayName',colorLabels{i});
						PL1.plot.DataTipTemplate.DataTipRows(1).Label = 'Time';
						PL1.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
					else
						PL1 = plot(t,p,'color', traceColor((a*traceColor_step)+1,:),...
							'LineWidth', 1,'DisplayName',colorLabels{i});
						PL1.DataTipTemplate.DataTipRows(1).Label = 'Time';
						PL1.DataTipTemplate.DataTipRows(2).Label = 'Power';
					end 
					a = a + 1;
				end
				
			end
			
			line([me.measureRange(1) me.measureRange(1)],[minp maxp],...
				'Color',[0.3 0.3 0.3 0.5],'linestyle',':','LineWidth',2);
			line([me.measureRange(2) me.measureRange(2)],[minp maxp],...
				'Color',[0.3 0.3 0.3 0.5],'linestyle',':','LineWidth',2);
			
			data.minDiameter = minp;
			data.maxDiameter = maxp;
			data.diameterRange = maxp - minp;
			
			xlabel('Time (secs)')
			ylabel('Pupil Diameter')
			if me.normaliseBaseline
				title(['Normalised Pupil: # Trials = ' num2str(me.metadata.ana.trialNumber) ' | Subject = ' me.metadata.ana.subject  ' | baseline = ' num2str(me.baselineWindow,'%.2f ') 'secs'  ' | Range = ' num2str(data.diameterRange,'%.2f')]);
			else
				title(['Raw Pupil: # Trials = ' num2str(me.metadata.ana.trialNumber) ' | Subject = ' me.metadata.ana.subject  ' | Range = ' num2str(data.diameterRange,'%.2f')])
			end
			xlim([-0.2 me.measureRange(2)+0.05]);
			if minp == 0; minp = -1;end
			if maxp==0; maxp = 1; end
			if minp <= 0
				ylim([minp+(minp/10) maxp+(maxp/10)]);
			else
				ylim([minp-(minp/10) maxp+(maxp/10)]);
			end
			legend(colorLabels(start:finish),'FontSize',10,'Location','southwest'); %'Position',[0.955 0.75 0.04 0.24]
			box on; grid on; 
			ax1.XMinorGrid = 'on';
			ax1.FontSize = 12;
			
			ax2 = nexttile(tl);
			maxP = 0;
			a=0;
			for i = start : finish %1: length(me.meanF)
				hold on
				F = me.meanF{i};
				P = me.meanP{i};
				idx = F < 20;
				F = F(idx);
				P = P(idx);
				maxP = max([maxP max(P)]);
				PL2 = plot(F,P,'color', [traceColor((a*traceColor_step)+1,:) 0.6],...
					'Marker','o','DisplayName',colorLabels{i},...
					'MarkerSize', 5,'MarkerFaceColor',traceColor((a*traceColor_step)+1,:),...
					'MarkerEdgeColor', 'none');
				PL2.DataTipTemplate.DataTipRows(1).Label = 'Frequency';
				PL2.DataTipTemplate.DataTipRows(2).Label = 'Power';
				a = a + 1;
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
			line([me.taggingFrequency me.taggingFrequency],[ax2.YLim(1) ax2.YLim(2)],...
				'Color',[0.3 0.3 0.3 0.5],'linestyle',':','LineWidth',2);
			title(['FFT Power: range = ' num2str(me.measureRange,'%.2f ') 'secs | F = ' num2str(me.taggingFrequency) 'Hz\newlineHanning = ' num2str(me.useHanning)]);
			
			box on; grid on; grid minor;
			ax2.FontSize = 12;
			
			csteps = trlColors(start:finish);
			ax3 = nexttile(tl,[1 2]);
			hold on
			if exist('colororder','file')>0; colororder({'k','k'});end
			yyaxis right
			phasePH = analysisCore.areabar(csteps,me.meanPhaseValues(start:finish),...
				me.varPhaseValues(start:finish),[0.6 0.6 0.3],0.25,'LineWidth',1.5);
			try
				phasePH.DataTipTemplate.DataTipRows(1).Label = 'Luminance';
				phasePH.DataTipTemplate.DataTipRows(2).Label = 'Angle';
			end
			mn = min(me.meanPhaseValues-me.varPhaseValues);
			mx = max(me.meanPhaseValues+me.varPhaseValues);
			ylim([mn mx]);
			%PL3b = plot(trlColors,rad2deg(A),'k-.','Color',[0.6 0.6 0.3],'linewidth',1);
			ylabel('Phase (deg)');
			data.X=csteps;
			data.phaseY=me.meanPhaseValues(start:finish);
			data.phaseE=me.varPhaseValues(start:finish);
			
			box on; grid on;
			
			yyaxis left
			hold on
			if me.normalisePowerPlots
				m0 = me.meanPowerValues0(start:finish) / max(me.meanPowerValues0(start:finish));
				e0 = me.varPowerValues0(start:finish) / max(me.meanPowerValues0(start:finish));
			else
				m0 = me.meanPowerValues0(start:finish);
				e0 = me.varPowerValues0(start:finish);
			end
			data.m0=m0;
			data.e0=e0;
			is0=false;
			if max(me.meanPowerValues0) > 0.1 % only if there is a significant response
				is0 = true;
				h0PH = analysisCore.areabar(csteps,m0,e0,[0.5 0.5 0.7],0.1,...
					'LineWidth',1);
				try %#ok<*TRYNC>
					h0PH.plot.DataTipTemplate.DataTipRows(1).Label = 'Luminance';
					h0PH.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
				end
			end
			
			if me.normalisePowerPlots
				m = me.meanPowerValues(start:finish) / max(me.meanPowerValues(start:finish));
				e = me.varPowerValues(start:finish) / max(me.meanPowerValues(start:finish));
			else
				m = me.meanPowerValues(start:finish);
				e = me.varPowerValues(start:finish);
			end
			data.m=m;
			data.e=e;
			
			xx = linspace(min(csteps),max(csteps),500);
			f = fit(csteps',m','smoothingspline');
			yy = feval(f,xx);
			ymin = find(yy==min(yy));
			ymin = xx(ymin);
			
			idx = find(m==min(m));
			minC = csteps(idx);
			ratio = fixColor / minC;
			ratio2 = fixColor / ymin;
			
			h1PH = analysisCore.areabar(csteps,m,e,[0.7 0.2 0.2],0.2,...
				'LineWidth',2);
			try
				h1PH.plot.DataTipTemplate.DataTipRows(1).Label = 'Luminance';
				h1PH.plot.DataTipTemplate.DataTipRows(2).Label = 'Power';
			end
			plot(xx,yy,'c-','LineWidth',1.5);
			
			if is0
				mx = max([max(m+e) max(m0+e0)]);
				mn = min([min(m-e) min(m0-e0)]);
			else
				mx = max(m+e);
				mn = min(m-e);
			end
			ylim([mn mx]);
			pr = (m .* m0);
			pr = (pr / max(pr)) * mx;
			%h0h1PH = plot(trlColors,pr,'--','Color',[0.5 0.5 0.5],...
			%	'LineWidth',1);

			data.minColor = minC;
			data.ratio = ratio;
			data.ratio2 = ratio2;
			%plot(trlColors,p0 / max(p0),'b--',trlColors,p1 / max(p1),'r:','linewidth',1);
			
			ax3.FontSize = 12;
			ax3.XTick = csteps;
			ax3.XTickLabel = colorLabels(start:finish); 
			ax3.XTickLabelRotation = 45;
			pad = max(diff(csteps))/10;
			ax3.XLim = [ min(csteps) - pad max(csteps) + pad];
			
			if fixColor <= max(csteps) && fixColor >= min(csteps)
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
			tit = sprintf('Harmonic Power: %s | %s Min@H1 = %.2f & Ratio = %.2f/%.2f', ...
				tit, varName, data.minColor, data.ratio, data.ratio2);
			title(tit);
			
			if is0
				legend([h0PH.plot,h1PH.plot,phasePH.plot],{'H0','H1','Phase'},...
				'FontSize',10,'Location','southwest'); %'Position',[0.9125 0.2499 0.0816 0.0735],
			else
				legend([h1PH.plot,phasePH.plot],{'H1','Phase'},...
				'FontSize',10,'Location','southwest')	
			end
			
			box on; grid on;
			
			handles.ax1 = ax1;
			handles.ax2 = ax2;
			handles.ax3 = ax3;
			handles.PL1 = PL1;
			handles.PL2 = PL2;
			handles.PL3a = phasePH;
			if exist('h0PH','var');handles.PL3 = h0PH;end
			if exist('h1PH','var'); handles.PL4 = h1PH;end
			if exist('h0h1PH','var');handles.PL5 = h0h1PH;end
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
		%> @brief save
		%>
		%> @param file filename to save to
		%> @return
		% ===================================================================
		function fitLuminances(me)
			if isempty(me.c); loadCalibration(me); end
			if isa(me.c,'calibrateLuminance') && isempty(me.l) 
				
				l.igray		= me.c.inputValues(1).in; %#ok<*PROP>
				l.ired		= me.c.inputValues(2).in;
				l.igreen	= me.c.inputValues(3).in;
				l.iblue		= me.c.inputValues(4).in;
				l.x			= me.c.ramp;

				[l.fx, l.fgray]	= analysisCore.linearFit(l.x, l.igray);
				[~, l.fred]		= analysisCore.linearFit(l.x, l.ired);
				[~, l.fgreen]	= analysisCore.linearFit(l.x, l.igreen);
				[~, l.fblue]	= analysisCore.linearFit(l.x, l.iblue);
				l.fred(l.fred<0)=0; l.fgreen(l.fgreen<0)=0; l.fblue(l.fblue<0)=0; l.fgray(l.fgray<0)=0;
				me.l = l;
			end
		end
		
		% ===================================================================
		%> @brief save
		%>
		%> @param file filename to save to
		%> @return
		% ===================================================================
		function [x1, y1, x2, y2] = getLuminances(me, value, from, to)
			if isempty(me.l); me.fitLuminances; end
			l = me.l;
			fx = l.fx;
			switch from
				case 'red'
					fy = l.fred;
				case 'green'
					fy = l.fgreen;
				case 'blue'
					fy = l.fblue;
				case 'gray'
					fy = l.fgray;
			end
			
			switch to
				case 'red'
					ty = l.fred;
				case 'green'
					ty = l.fgreen;
				case 'blue'
					ty = l.fblue;
				case 'gray'
					ty = l.fgray;
			end
			
			[ix,~,~] = analysisCore.findNearest(fx, value);
			x1 = fx(ix);
			y1 = fy(ix);
			[ix,~,~] = analysisCore.findNearest(ty, y1);
			x2 = fx(ix);
			y2 = ty(ix);
		end
		
		% ===================================================================
		%> @brief save
		%>
		%> @param file filename to save to
		%> @return
		% ===================================================================
		function [y, x] = getLuminance(me, value, color)
			if isempty(me.l); me.fitLuminances; end
			l = me.l;
			fx = l.fx;
			if ~exist('color','var') && length(value) == 3
				fy{1} = l.fred;
				fy{2} = l.fgreen;
				fy{3} = l.fblue;
				for i = 1:3
					[ix,~,~] = analysisCore.findNearest(fx, value(i));
					x(i) = fx(ix);
					y(i) = fy{i}(ix);
				end
			else
				switch color
					case 'red'
						fy = l.fred;
					case 'green'
						fy = l.fgreen;
					case 'blue'
						fy = l.fblue;
					case 'gray'
						fy = l.fgray;
				end
				for i = 1:length(value)
					[ix,~,~] = analysisCore.findNearest(fx, value(i));
					x(i) = fx(ix);
					y(i) = fy(ix);
				end
			end
			y( y < 0 ) = 0;
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
			if size(me.maxLuminances,1) > 1; me.maxLuminances=me.maxLuminances';end
			cNames = {'Red';'Green';'Blue';'Yellow';'Grey';'Cyan';'Purple'};
			
			fColor=find(fc > 0); %get the position of not zero
			if length(fColor) == 1 && fColor <= 3
				
			elseif length(fColor) == 2 && all([1 2] == fColor)
				fColor = 4;
			elseif length(fColor) == 2 && all([1 3] == fColor)
				fColor = 7;
			elseif length(fColor) == 2 && all([2 3] == fColor)
					fColor = 6;
			elseif length(fColor) == 3 && isequal(fc(1),fc(2),fc(3))
				fColor = 5;
			else
				warning('Cannot Define fixed color!');
			end
			if me.simpleMode
				fix = fc .* me.maxLuminances;
			else
				fix = me.getLuminance(fc);
			end
			fixName = cNames{fColor};
			switch fixName
				case 'Grey'
					fixColor = fix(1) + fix(2) + fix(3);
				case 'Yellow'
					fixColor = fix(1) + fix(2);
				otherwise
					fixColor = sum(fix(fColor));
			end
			
			if me.simpleMode
				cE = ce .* me.maxLuminances;
				cS = cs .* me.maxLuminances;
			else
				cE = me.getLuminance(ce);
				cS = me.getLuminance(cs);
			end
			vColor=find(ce > 0); %get the position of not zero
			if length(vColor)==3 && all([1 2 3] == vColor); vi = 5;
			elseif length(vColor)==2 && all([1 2] == vColor); vi = 4; 
			elseif length(vColor)==2 && all([1 3] == vColor); vi = 7; 
			elseif length(vColor)==2 && all([2 3] == vColor); vi = 6;
			else; vi = vColor;
			end
			varName = cNames{vi};
			varColor = sum(cS(vColor));
			
			if me.simpleMode
				vals = cellfun(@(x) x .* me.maxLuminances, vals, 'UniformOutput', false);
			else
				vals = cellfun(@(x) getLuminance(me,x), vals, 'UniformOutput', false);
			end
			trlColor=cell2mat(vals);
			tit = num2str(fix,'%.2f ');
			tit = regexprep(tit,'0\.00','0');
			tit = ['Fix color (' fixName ') = ' tit ' | Var color (' varName ')'];
			colorChange= cE - cS;
			tColor=find(colorChange~=0); %get the position of not zero
			step=abs(colorChange(tColor)/me.metadata.ana.colorStep);
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
			
			idx = analysisCore.findNearest(f, me.taggingFrequency);
			p1 = P(idx);
			A = angle(Pi(idx));
			idx = analysisCore.findNearest(f, 0);
			p0 = P(idx);
				
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
				elseif max(me.defLuminances) > 1
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
			if isa(me.metadata.seq,'stimulusSequence')
				minTrials = me.metadata.seq.minBlocks;
			else
				minTrials = me.metadata.seq.minTrials;
			end
			for i=1:length(thisTrials)
				
				me.SortedPupil(1).anaTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials))=me.metadata.ana.trial(i);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials))=thisTrials(i);
				idx=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).times>=-1000;
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).times=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).times(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).gx=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).gx(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).gy=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).gy(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).hx=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).hx(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).hy=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).hy(idx);
				me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).pa=me.SortedPupil(1).pupilTrials(me.metadata.seq.outIndex(i),ceil(i/minTrials)).pa(idx);
				
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
					clear P;
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
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function loadCalibration(me)
			if (isempty(me.c) || ~isa(me.c,'calibrateLuminance')) && exist(me.calibrationFile,'file')
				in = load(me.calibrationFile);
				fprintf('--->>> Using %s calibration and max luminances: ',me.calibrationFile);
				me.c = in.c; clear in;
				me.maxLuminances = me.c.maxLuminances(2:4);
				fprintf('%.3f ',me.maxLuminances); fprintf('\n\n');
			end
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

