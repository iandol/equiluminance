classdef pupilPower < analysisCore
	%PUPILPOWER Calculate power for each trial from EDF file pupil data
	
	%------------------PUBLIC PROPERTIES----------%
	properties
		pupilData@eyelinkAnalysis
		%> plot verbosity
		verbose = true
		normaliseBaseline@logical = true
	end
	
	%------------------VISIBLE PROPERTIES----------%
	properties (SetAccess = {?analysisCore}, GetAccess = public)
		metadata@struct
		powerValues
		trlColor
		rawPupil@cell
		rawTimes@cell
		rawF@cell
		rawP@cell
		isParsed@logical = false
	end
	
	%------------------PRIVATE PROPERTIES----------%
	properties (SetAccess = private, GetAccess = private)
		%> allowed properties passed to object upon construction, see parseArgs
		allowedProperties@char = 'pupilData'
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
		function self = pupilPower(varargin)
			if nargin == 0; varargin.name = 'pupilPower';end
			self = self@analysisCore(varargin); %superclass constructor
			if nargin>0; self.parseArgs(varargin, self.allowedProperties); end
			if isempty(self.name); self.name = 'pupilPower'; end
			if isempty(self.pupilData)
				run(self);
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function run(self, force)
			if ~exist('force','var') || isempty(force); force = false; end
			self.load(force);
			self.calculate();
			self.plot()
		end
	
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function plot(self)
			if ~self.isParsed; return; end
			tit = ['Fixed: ' num2str(self.metadata.ana.colorFixed)];
			if ~self.isParsed; return; end
			colorStep1=self.metadata.ana.colorStep;   %Step=(R,G,B)
			tColor1=find(colorStep1~=0); %get the position of not zero
			step1=abs(colorStep1(tColor1));
			colorUp1=max(self.trlColor(:,tColor1));
			colorDown1=min(self.trlColor(:,tColor1));
			h=figure;figpos(1,[1000 1500]);set(h,'Color',[1 1 1],'NumberTitle','off',...
				'Name',['pupilPower: ' self.pupilData.file]);
			plotColor=zeros(1,3);
			plotColor(1,tColor1)=1;        %color of line in the plot
			
			numTrials = length(self.powerValues);
			
			subplot(411)
			stairs(self.trlColor(:,tColor1),'color',plotColor,'LineWidth',2)
			xlim([0 numTrials+1])
			xlabel('Trial #')
			ylim([colorDown1-step1 colorUp1+step1])
			set(gca,'ytick',colorDown1-step1:2*step1:colorUp1+step1)
			ylabel('Color')
			title(tit);
			box on; grid on;
			
			subplot(412)
			plot(self.powerValues,'ko-','LineWidth',2)
			xlim([0 numTrials+1])
			xlabel('Trial #')
			ylabel('PupilPower')           
			title(tit);
			box on; grid on;
			
			subplot(413)
			names = {};
			for i = 1: length(self.rawPupil)
				hold on
				t = self.rawTimes{i}; 
				p = self.rawPupil{i};
				idx = t >= -0.5;
				t = t(idx);
				p = p(idx);
				
				if self.normaliseBaseline
					idx = t < 0;
					mn = median(p(idx));
					p = p - mn;
				end
				
				plot(t, p, 'LineWidth', 1)
				names{i} = num2str(self.trlColor(i,:));
				names{i} = regexprep(names{i},'\s+',' ');
			end
			xlabel('Time (s)')
			ylabel('Pupil Diameter')
			title(['Raw Pupil Plots for Frequency = ' num2str(self.metadata.ana.frequency)])
			legend(names)
			axv = axis;
			f = round(self.metadata.ana.onFrames) * (1 / self.metadata.sM.screenVals.fps);
			rectangle('Position',[0 axv(3) f 100], 'FaceColor',[0.8 0.8 0.8 0.5],'EdgeColor','none')
			if self.metadata.ana.trialDuration * self.metadata.ana.frequency > 1
			rectangle('Position',[f*2 axv(3) f 100], 'FaceColor',[0.8 0.8 0.8 0.5],'EdgeColor','none')
			end
			if self.metadata.ana.trialDuration * self.metadata.ana.frequency > 2
				rectangle('Position',[f*4 axv(3) f 100], 'FaceColor',[0.8 0.8 0.8 0.5],'EdgeColor','none')
			end
			box on; grid on;
			
			subplot(414)
			for i = 1: length(self.rawF)
				hold on
				plot(self.rawF{i},self.rawP{i},'o-')
				names{i} = num2str(self.trlColor(i,:));
				names{i} = regexprep(names{i},'\s+',' ');
			end
			xlim([0 10])
			xlabel('Frequency (Hz)')
			ylabel('Power')
			title(['Power Plots for Frequency = ' num2str(self.metadata.ana.frequency)])
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
		function load(self, force)
			if ~exist('force','var') || isempty(force); force = false; end
			if self.isParsed && ~force; return; end
			try
			self.pupilData=eyelinkAnalysis;
			parseSimple(self.pupilData);
			[~,fn] = fileparts(self.pupilData.file);
			self.metadata = load([self.pupilData.dir,fn,'.mat']); %load .mat of same filename with .edf
			self.isParsed = true;
			catch
				self.isParsed = false;
			end
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function calculate(self)
			if ~self.isParsed; return; end
			Fs1 = self.pupilData.sampleRate; % Sampling frequency
			T1 = 1/Fs1; % Sampling period
			
			thisTrials = self.pupilData.trials(self.pupilData.correct.idx);
			numTrials=length(thisTrials); %Number of trials
			
			for currentTrial=1:numTrials                   %exact the color information of each trial
				self.trlColor(currentTrial,:)=self.metadata.ana.trial(currentTrial).mColor;
			end
			
			for currentTrial=1:numTrials
				self.rawPupil{currentTrial} = thisTrials(currentTrial).pa;
				self.rawTimes{currentTrial} = thisTrials(currentTrial).times / 1e3;
				p = self.rawPupil{currentTrial};
				t = self.rawTimes{currentTrial};
				
				idx = t >= -0.5;
				t = t(idx);
				p = p(idx);
				
				if self.normaliseBaseline
					idx = t < 0;
					mn = median(p(idx));
					p = p - mn;
				end
				
				idx = t >= 0;
				p = p(idx);
				t = t(idx);
				
				L=length(p);
				P1 = fft(p);
				P2 = abs(P1/L);
				P3=P2(1:floor(L/2)+1);
				P3(2:end-1) = 2*P3(2:end-1);
				f=Fs1*(0:(L/2))/L;
				idx = analysisCore.findNearest(f, self.metadata.ana.frequency);
				self.powerValues(currentTrial) = P3(idx); %get the pupil power of tagging frequency
				self.rawF{currentTrial} = f;
				self.rawP{currentTrial} = P3;
			end
			
		end
		
		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function closeUI(self, varargin)
			try delete(self.handles.parent); end %#ok<TRYNC>
			self.handles = struct();
			self.openUI = false;
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function makeUI(self, varargin) %#ok<INUSD>
			disp('Feature not finished yet...')
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function updateUI(self, varargin) %#ok<INUSD>
			disp('Feature not finished yet...')
		end

		% ===================================================================
		%> @brief
		%>
		%> @param
		%> @return
		% ===================================================================
		function notifyUI(self, varargin) %#ok<INUSD>
			disp('Feature not finished yet...')
		end
	
	end
end

