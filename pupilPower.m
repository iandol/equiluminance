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
        SortedPupil@struct
        powerValues
        varPowerValues
        meanPowerValues
        rawPupil@cell
        meanPupil
        rawTimes@cell
        meanTimes
        rawF@cell
        meanF
        rawP@cell
        meanP
        isLoaded@logical = false
        isCalculated@logical = false
    end
    
    %------------------PRIVATE PROPERTIES----------%
    properties (SetAccess = private, GetAccess = private)
        %> allowed properties passed to object upon construction, see parseArgs
        allowedProperties@char = 'pupilData|normaliseBaseline'
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
            self.plot();
        end
        
        % ===================================================================
        %> @brief
        %>
        %> @param
        %> @return
        % ===================================================================
        function plot(self)
            if ~self.isCalculated; return; end
            tit = ['Fixed Colour = ' num2str(self.metadata.ana.colorFixed)];
            colorChange=self.metadata.ana.colorEnd-self.metadata.ana.colorStart;
            tColor=find(colorChange~=0); %get the position of not zero
            step=abs(colorChange(tColor)/self.metadata.ana.colorStep);
            trlColor=cell2mat(self.metadata.seq.nVar.values');
            colorMax=max(trlColor(:,tColor));
            colorMin=min(trlColor(:,tColor));
            
            h=figure;figpos(1,[1000 1500]);set(h,'Color',[1 1 1],'NumberTitle','off',...
                'Name',['pupilPower: ' self.pupilData.file]);
            plotColor=zeros(1,3);
            plotColor(1,tColor)=1;        %color of line in the plot
            
            numTrials = length(self.meanPowerValues);
            traceColor = colormap(jet);
            traceColor_step = floor(length(traceColor)/numTrials);
            subplot(411)
            trlColor(numTrials+1,:)=trlColor(numTrials,:);
            stairs(trlColor(:,tColor),'color',plotColor,'LineWidth',2)
            xlim([0.5 numTrials+1.5])
            set(gca,'xtick',0.5:1:numTrials+1.5)
            set(gca,'xticklabel',{0:1:numTrials+1})
            xlabel('Variable Number')
            ylim([colorMin-step colorMax+step])
            set(gca,'ytick',colorMin-step:2*step:colorMax+step)
            ylabel('Color')
            title(tit);
            box on; grid on;
              
            subplot(412)
            areabar(1:length(self.meanPowerValues),self.meanPowerValues,self.varPowerValues,'ko','LineWidth',1)
            xlim([0 numTrials+1])
            xlabel('Variable Number')
            ylabel('Pupil Power at 1st Harmonic')
            title(tit);
            box on; grid on;
            
            subplot(413)
            names = {};
            for i = 1: length(self.meanPupil)
                hold on
                t = self.meanTimes{i};
                p = self.meanPupil{i};
                idx = t >= -0.5;
                t = t(idx);
                p = p(idx);
                
                if self.normaliseBaseline
                    idx = t < 0;
                    mn = median(p(idx));
                    p = p - mn;
                end
                
                plot(t, p,'color', traceColor(i*traceColor_step,:), 'LineWidth', 1)
                if isempty(t)==0
                names{i} = num2str(trlColor(i,:));
                names{i} = regexprep(names{i},'\s+',' ');
                end
            end
            xlabel('Time (s)')
            ylabel('Pupil Diameter')
            title(['Raw Pupil Plots for Frequency = ' num2str(self.metadata.ana.frequency)])
            names(cellfun(@isempty,names))=[];
            legend(names,'Location','bestoutside')
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
            for i = 1: length(self.meanF)
                hold on
                plot(self.meanF{i},self.meanP{i},'color', traceColor(i*traceColor_step,:),...
                    'Marker','o');
                 if isempty(self.meanF{i})==0
                names{i} = num2str(trlColor(i,:));
                names{i} = regexprep(names{i},'\s+',' ');
                 end
            end
            xlim([0 10])
            xlabel('Frequency (Hz)')
            ylabel('Power')
             names(cellfun(@isempty,names))=[];
            legend(names,'Location','bestoutside');
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
            if self.isLoaded && ~force; return; end
            try
                self.pupilData=eyelinkAnalysis;
                parseSimple(self.pupilData);
                [~,fn] = fileparts(self.pupilData.file);
                self.metadata = load([self.pupilData.dir,fn,'.mat']); %load .mat of same filename with .edf
                self.isLoaded = true;
            catch
                self.isLoaded = false;
            end
        end
        
        % ===================================================================
        %> @brief
        %>
        %> @param
        %> @return
        % ===================================================================
        function calculate(self)
            if ~self.isLoaded; return; end
            Fs1 = self.pupilData.sampleRate; % Sampling frequency
            T1 = 1/Fs1; % Sampling period
            thisTrials = self.pupilData.trials(self.pupilData.correct.idx);
            for i=1:length(thisTrials)
                
                self.SortedPupil(1).anaTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks))=self.metadata.ana.trial(i);
                self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks))=thisTrials(i);
                idx=self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).times>=-500;
                self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).times=self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).times(idx);
                self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).gx=self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).gx(idx);
                self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).gy=self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).gy(idx);
                self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).hx=self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).hx(idx);
                self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).hy=self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).hy(idx);
                self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).pa=self.SortedPupil(1).pupilTrials(self.metadata.seq.outIndex(i),ceil(i/self.metadata.seq.minBlocks)).pa(idx);
                
            end
            
            thisTrials = self.SortedPupil.pupilTrials;
            numTrials=size(thisTrials,1); %Number of trials
            numBlocks=size(thisTrials,2); %Number of Blocks
            
            for currentTrial=1:numTrials
                if isempty(self.SortedPupil.pupilTrials(currentTrial).variable)==0
                k=1;                F=[];                P=[];    Pu=[];  Ti=[];
                for currentBlock=1:numBlocks
                    if isempty(self.SortedPupil.pupilTrials(currentTrial,currentBlock).variable)==0
                    self.rawPupil{currentTrial,currentBlock} = thisTrials(currentTrial,currentBlock).pa;
                    self.rawTimes{currentTrial,currentBlock} = thisTrials(currentTrial,currentBlock).times / 1e3;
                    p = self.rawPupil{currentTrial,currentBlock};
                    t = self.rawTimes{currentTrial,currentBlock};
                    
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
                    self.powerValues(currentTrial,currentBlock) = P3(idx); %get the pupil power of tagging frequency
                    self.rawF{currentTrial,currentBlock} = f;
                    self.rawP{currentTrial,currentBlock} = P3;
                    rawFramef(k)=size(self.rawF{currentTrial,currentBlock},2);
                    rawFramePupil(k)=size(self.rawPupil{currentTrial,currentBlock},2);
                    k=k+1;
                    end
                                   end
                rawFramefMin(currentTrial)=min(rawFramef);
                rawFramePupilMin(currentTrial)=min(rawFramePupil);
                for currentBlock=1:numBlocks
                    if isempty(self.SortedPupil.pupilTrials(currentTrial,currentBlock).variable)==0
                    F(1,currentBlock,:)=self.rawF{currentTrial,currentBlock}(1,1:rawFramefMin(currentTrial));
                    P(1,currentBlock,:)=self.rawP{currentTrial,currentBlock}(1,1:rawFramefMin(currentTrial));
                    Pu(1,currentBlock,:)=self.rawPupil{currentTrial,currentBlock}(1,1:rawFramePupilMin(currentTrial));
                    Ti(1,currentBlock,:)=self.rawTimes{currentTrial,currentBlock}(1,1:rawFramePupilMin(currentTrial));
                    end
                end                
                self.meanF{currentTrial,1}=squeeze(mean(F,2));
                self.meanP{currentTrial,1}=squeeze(mean(P,2));
                self.meanPupil{currentTrial,1}=squeeze(mean(Pu,2));
                self.meanTimes{currentTrial,1}=squeeze(mean(Ti,2));
                end
            end
            powerValues=self.powerValues;
            powerValues(powerValues==0)=NaN;
            self.meanPowerValues=nanmean(powerValues,2);
            for i=1:size(self.powerValues,1)
                if self.powerValues(i,size(self.powerValues,2))==0
                    n=size(self.powerValues,2)-1;
                else
                    n=size(self.powerValues,2);
                end
                self.varPowerValues(i,1)=sqrt(sum((self.powerValues(i,:)-self.meanPowerValues(i)).^2)/(n*(n-1)));
            end
                self.varPowerValues(self.varPowerValues==inf)=0;            
            self.isCalculated = true;
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

