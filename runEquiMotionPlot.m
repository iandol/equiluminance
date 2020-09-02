function runEquiMotionPlot()

[f, p]				= uigetfile('*.mat','Load EquiMotion MAT File...');
cd(p);
out					= load(f);
ana					= out.ana;
seq					= out.seq;

maxLuminances		= [1 1 1];
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
map = analysisCore.optimalColours(seq.minBlocks);
% to plot the psychometric function
PF					= @PAL_Weibull;
maxbeta				= 30;
space.alpha			= linspace(min(variableVals), max(variableVals), 100);
space.beta			= linspace(1, maxbeta, 100);
space.gamma			= 0;
space.lambda		= 0;
pfx					= linspace(min(variableVals),max(variableVals),250);

tit = ['Equimotion Data: ' f];
tit=regexprep(tit,'_','-');
h = figure('Name',tit,'Units','normalized',...
		'Position',[0.25 0.25 0.3 0.4],...
		'Color',[1 1 1],...
		'PaperType','A4','PaperUnits','centimeters');
tl = tiledlayout(h,2,1);
tl.Title.String = tit;
tl.Title.FontName = 'JetBrains Mono';
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
ax.FontName = 'JetBrains Mono';
ylabel('Trial Number');
title([' Fixed Value: ' num2str(ana.colorFixed .* maxLuminances)]);
xticks(1:length(varLabels));
xlim([0 length(varLabels)+1]);
xticklabels(varLabels); box on; grid on;
pl(1).Parent.XTickLabelRotation=45;

ax = nexttile(2);
responseVals = ana.trial(end).responseVals;
totalVals = ana.trial(end).totalVals;
try
	hold on;
	try scatter(variableVals,(responseVals./totalVals),(totalVals+1).*20,...
		'filled','MarkerFaceAlpha',0.5); end
	pv = PAL_PFML_Fit(variableVals,responseVals,totalVals,space,[1 1 0 0],PF);
	if isinf(pv(2)); pv(2) = maxbeta; end
	pfvals = PF(pv,pfx);
	pl=plot(pfx,pfvals,'k-');
	pl(1).Parent.XTickLabelRotation=45;
	ylabel('Proportion LEFT Choices');
	title(sprintf('Weibull Threshold:%.2f | Slope:%.2f | Trials:%i',pv(1),pv(2),sum(totalVals)));
catch ME
	fprintf('===>>> Cannot plot psychometric curve yet...\n');
end
ax.FontName			= 'JetBrains Mono';
xlim([min(variableVals)-0.05 max(variableVals)+0.05]);
ylim([-0.05 1.05]);
box on; grid on;
tl.XLabel.String	= [varLabel ' Variable Color Value'];
tl.XLabel.FontName	= 'JetBrains Mono';	
end