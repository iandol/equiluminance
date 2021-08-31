function runEquiMotionPlot()

[f, p]				= uigetfile('*.mat','Load EquiMotion MAT File...');
cd(p);
out					= load(f);
ana					= out.ana;
seq					= out.seq;

maxLuminances		= [25.5484  102.9958   18.1265];
fixC				= find(ana.colorFixed == max(ana.colorFixed));
switch fixC
	case 1
		fixLabel	='Red';
	case 2
		fixLabel	='Green';
	case 3
		fixLabel	='Blue';
end
varC				= find(ana.colorEnd == max(ana.colorEnd));
switch varC
	case 1
		varLabel	='Red';
	case 2
		varLabel	='Green';
	case 3
		varLabel	='Blue';
end
for i = 1:length(seq.nVar(1).values)
	variableVals(i) = max(seq.nVar(1).values{i});
end
variableVals		= variableVals .* maxLuminances(varC);
varLabels			= arrayfun(@(a) num2str(a,3),variableVals,'UniformOutput',false);
LEFT = 1; 	RIGHT = 2; UNSURE = 3; REDO = -10; BREAKFIX = -1;
map					= analysisCore.optimalColours(seq.minTrials);
% to plot the psychometric function
PF					= @PAL_Quick;
maxbeta				= 200;
space.alpha			= linspace(min(variableVals), max(variableVals), 100);
space.beta			= linspace(0, maxbeta, 100);
space.gamma			= linspace(0, 0.15, 10);
space.lambda		= linspace(0, 0.15, 10);
pfx					= linspace(min(variableVals),max(variableVals),300);

tit = ['Data: ' f];
tit=regexprep(tit,'_','-');
h = figure('Name',tit,'Units','normalized',...
'Position',[0.25 0.25 0.5 0.6],...		
		'Color',[1 1 1],...
		'PaperType','A4','PaperUnits','centimeters');
tl = tiledlayout(h,2,1);
tl.Title.String = tit;
tl.Title.FontName = 'Fira Code';
tl.Title.FontWeight = 'bold';

ax=nexttile(1);
for i = 1:length(ana.trial)
	v = ana.trial(i).variable;
	r = ana.trial(i).response;
	p = [];
	if r == LEFT
		p = 'k-<';
	elseif r == RIGHT
		p = 'k->';
	elseif r == UNSURE
		p = 'k-x';
	end
	if ~isempty(p)
		hold on;
		pl=plot(v,i,p,'Color',map(v,:),'MarkerSize',8,'MarkerFaceColor', map(v,:));
	end
end
ax.FontName = 'Fira Code';
ylabel('Trial Number');
fprintf('%s fixed raw: %s\n',fixLabel,num2str(ana.colorFixed,'%.3f '));
title([fixLabel ' Fixed Value: ' num2str(ana.colorFixed .* maxLuminances)]);
xticks(1:length(varLabels));
xlim([0.5 length(varLabels)+0.5]);
xticklabels(varLabels); box on; grid on;
pl(1).Parent.XTickLabelRotation=45;

fixVal = ana.colorFixed(fixC) * maxLuminances(fixC);
ax = nexttile(2);
responseVals = ana.trial(end).responseVals;
totalVals = ana.trial(end).totalVals;
try
	hold on;
	try scatter(variableVals,(responseVals./totalVals),(totalVals+1).*20,...
		'filled','MarkerFaceAlpha',0.5); end
	[pv,ll,scenario] = PAL_PFML_Fit(variableVals,responseVals,totalVals,space,[1 1 1 1],PF);
	fprintf('FIT: %.2f %.2f %.2f %.2f | LL: %.2f | scenario: %i\n',...
			pv(1),pv(2),pv(3),pv(4),ll,scenario);
	if isinf(pv(1))
		warning('Weibull didn''t fit, change to Logistic!!!!!');
		PF = @PAL_Logistic;
		maxbeta = 20;
		space.beta			= linspace(0, maxbeta, 25);
		[pv,ll,scenario] = PAL_PFML_Fit(variableVals,responseVals,totalVals,space,[1 1 1 1],PF);
		fprintf('FIT: %.2f %.2f %.2f %.2f | LL: %.2f | scenario: %i\n',...
			pv(1),pv(2),pv(3),pv(4),ll,scenario);
	end
	if isinf(pv(2)); pv(2) = maxbeta; end
	pfvals = PF(pv,pfx);
	pl=plot(pfx,pfvals,'k-');
	pl(1).Parent.XTickLabelRotation=45;
	ylabel('Proportion LEFT Choices');
	ratio = (ana.colorFixed(fixC)*maxLuminances(fixC))/pv(1);
	tit=sprintf('%s Threshold:%.2f | Slope:%.2f | Trials:%i| Ratio:%.2f',...
		char(PF),pv(1),pv(2),sum(totalVals),ratio);
	tit=regexprep(tit,'_','-');
	title(tit);
end
line([fixVal fixVal],[0 1],'Color',[.3 .3 .3],'LineStyle','--','LineWidth',2);
fprintf('%s var raw: %s\n',varLabel,num2str(pv(1)/maxLuminances(varC),'%.3f '));
xticks(variableVals);
xticklabels(varLabels); 
ax.FontName			= 'Fira code';
xlim([min(variableVals)-(max(variableVals)/20) max(variableVals)+(max(variableVals)/20)]);
ylim([-0.05 1.05]);
box on; grid on;
tl.XLabel.String	= [varLabel ' Variable Color Value'];
tl.XLabel.FontName	= 'Fira code';

[~,f,~] = fileparts(f);
exportgraphics(tl,[pwd filesep f '.pdf']);

end
