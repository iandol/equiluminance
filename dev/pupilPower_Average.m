
for i=1:3;   
data(i)=pupilPower;
close all;

end


for i=1:size(data,2)
PowerNorm(i,:)=(data(i).meanPowerValues-min(data(i).meanPowerValues))/(max(data(i).meanPowerValues)-min(data(i).meanPowerValues));
end

Power_Ave=mean(PowerNorm);

for i=1:size(PowerNorm,2)
    Power_Var(i)=sqrt(sum((PowerNorm(:,i)-Power_Ave(i)).^2)/(size(PowerNorm,1)*(size(PowerNorm,1)-1)));
end

colorChange=data(1).metadata.ana.colorEnd-data(1).metadata.ana.colorStart;
            tColor=find(colorChange~=0); %get the position of not zero
            step=abs(colorChange(tColor)/data(1).metadata.ana.colorStep);
            trlColor=cell2mat(data(1).metadata.seq.nVar.values');
            colorMax=max(trlColor(:,tColor));
            colorMin=min(trlColor(:,tColor));

plotColor=zeros(1,3);
            plotColor(1,tColor)=1;        %color of line in the plot
            
            numTrials = length(data(1).meanPowerValues);
            traceColor = colormap(jet);
            traceColor_step = floor(length(traceColor)/numTrials);

tit1 = ['Fixed: ' num2str(data(1).metadata.ana.colorFixed)];



h=figure(1);figpos(1,[1000 1500]);set(h,'Color',[1 1 1],'NumberTitle','off',...
    'Name',['Averaged PupilPower' ]);

subplot(2,1,1)        %plot UP stimulus luminance

stairColor=trlColor(:,tColor);
stairColor(numTrials+1,1)=stairColor(numTrials,1);
stairs(stairColor,'color',plotColor)
xlim([0.5 numTrials+1.5])
set(gca,'xtick',0.5:1:numTrials+1.5)
set(gca,'xticklabel',{0:1:numTrials+1})
xlabel('Trial #')
ylim([colorMin-step colorMax+step])
set(gca,'ytick',colorMin-step:2*step:colorMax+step)
ylabel('Color')
title(tit1);
box on; grid on;



subplot(2,1,2)        %plot averaged pupil power
plot(Power_Ave,'ko-','LineWidth',1.5)
hold on
Trial=1:1:numTrials;
errorbar(Trial,Power_Ave,Power_Var,'k','LineWidth',1)
xlim([0 numTrials+1])
xlabel('Trial #')
ylabel('Normalized PupilPower')
title(tit1);
box on; grid on;


h2=figure(2);figpos(1,[1900 1600]);set(h2,'Color',[1 1 1],'NumberTitle','off',...
    'Name',['Raw Plots' ]);


for i=1:size(data,2)
subplot(3,2,2*i-1)           
names = {};
for j = 1: length(data(1,i).meanPupil)
    hold on
    t = data(1,i).meanTimes{j};
    p = data(1,i).meanPupil{j};
    idx = t >= -0.5;
    t = t(idx);
    p = p(idx);
    
    if data(1,i).normaliseBaseline
        idx = t < 0;
        mn = median(p(idx));
        p = p - mn;
    end
    
    plot(t, p,'color', traceColor(j*traceColor_step,:),'LineWidth', 1)
    names{j} = num2str(trlColor(j,:));
    names{j} = regexprep(names{j},'\s+',' ');
end
xlabel('Time (s)')
ylabel('Pupil Diameter')
xlim([-0.5 data(1,i).metadata.ana.trialDuration+0.5])
title(['Subject' num2str(i) ' - Raw Pupil Plot for Frequency = ' num2str(data(1,i).metadata.ana.frequency)])
legend(names,'location','EastOutside')
axv = axis;
f = round(data(1,i).metadata.ana.onFrames) * (1 / data(1,i).metadata.sM.screenVals.fps);
rectangle('Position',[0 axv(3) f 100], 'FaceColor',[0.8 0.8 0.8 0.5],'EdgeColor','none')
rectangle('Position',[f*2 axv(3) f 100], 'FaceColor',[0.8 0.8 0.8 0.5],'EdgeColor','none')
box on; grid on;




subplot(3,2,2*i)  
			for j = 1: length(data(1,i).meanF)
				hold on
				plot(data(1,i).meanF{j},data(1,i).meanP{j},'color', traceColor(j*traceColor_step,:),...
                    'Marker','o');
				names{j} = num2str(trlColor(j,:));
				names{j} = regexprep(names{j},'\s+',' ');
			end
			xlim([0 10])
			xlabel('Frequency (Hz)')
			ylabel('Power')
            legend(names,'location','EastOutside')
			title(['Subject' num2str(i) ' - Power Plots for Frequency = ' num2str(data(1,i).metadata.ana.frequency)])
			box on; grid on;

end
 