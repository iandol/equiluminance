% function IsoLumColorTransit
clear c igray igreen ired iblue fxgray fxgreen fxred fxblue fgray fgreen fred fblue in out
load('Display++Color++Mode-Ubuntu-RadeonPsychlab.mat')
igray	= c.inputValues(1).in;
igreen	= c.inputValues(3).in;
ired	= c.inputValues(2).in;
iblue	= c.inputValues(4).in;
x		= c.ramp;

[k,b,fx, fgray]		= fitted(x,igray);
[kr,br,~, fred]		= fitted(x,ired);
[kg,bg,~, fgreen]	= fitted(x,igreen);
[kb,bb,~, fblue]	= fitted(x,iblue);

figure('Units','normalized','Position',[0.2 0.2 0.6 0.6]);
hold on
pl = plot(x,igray,'ko'); ax = pl.Parent;
plot(x,igreen,'go');
plot(x,ired,'ro');
plot(x,iblue,'bo');
plot(fx,fgray,'k-');
plot(fx,fgreen,'g-');
plot(fx,fred,'r-');
plot(fx,fblue,'b-');
ylim([-5 round(max(igray)+5)]);
box on; grid on; grid minor;
title('RGB Luminance Outputs')
xlabel('RGB 0 <-> 1 Luminance')
ylabel('Physical Luminance (cd/m^2)')

list = {'Red>Green','Green>Red','Green>Grey',...
	'Red>Grey'};
[reply1,tf] = listdlg('ListString',list,'PromptString',...
	'Please select a conversion mode','SelectionMode','single');

in = inputdlg('Enter color value','Input');
in = str2num(in{1});

switch reply1
	case 1
		incdm = in * (max(igreen)-min(igreen))
		incdm2 = in * max(ired)
		out = reversfit(in,kr,br,kg,bg);
		[ix,iv,id] = findNearest(fx, in);
		outx1 = fx(ix);
		outy1 = fred(ix);
		[ix,iv,id] = findNearest(fgreen, outy1);
		outx2 = fx(ix);
		outy2 = fgreen(ix);
		tout = sprintf('RESULTS:\n%.3f Red (%.3f cd/m2) = Green %.3f (%.3f cd/m2)\n',in,outy1,outx2,outy2);
	case 2
		incdm = in * (max(igreen)-min(igreen))
		incdm2 = in * max(igreen)
		out = reversfit(in,kg,bg,kr,br);
		[ix,iv,id] = findNearest(fx, in);
		outx1 = fx(ix);
		outy1 = fgreen(ix);
		[ix,iv,id] = findNearest(fred, outy1);
		outx2 = fx(ix);
		outy2 = fred(ix);
		tout = sprintf('RESULTS:\n%.3f Green (%.3f cd/m2) = Red %.3f (%.3f cd/m2)\n',in,outy1,outx2,outy2);
	case 3
		incdm = in * (max(igreen)-min(igreen))
		incdm2 = in * max(igreen)
		out = reversfit(in,kg,bg,k,b);
		[ix,iv,id] = findNearest(fx, in);
		outx1 = fx(ix);
		outy1 = fgreen(ix);
		[ix,iv,id] = findNearest(fgray, outy1);
		outx2 = fx(ix);
		outy2 = fgray(ix);
		tout = sprintf('RESULTS:\n%.3f Green (%.3f cd/m2) = Gray %.3f (%.3f cd/m2)\n',in,outy1,outx2,outy2);
	case 4
		incdm = in * (max(ired)-min(ired))
		incdm2 = in * max(ired)
		out = reversfit(in,kr,br,k,b);
		[ix,iv,id] = findNearest(fx, in);
		outx1 = fx(ix);
		outy1 = fred(ix);
		[ix,iv,id] = findNearest(fgray, outy1);
		outx2 = fx(ix);
		outy2 = fgray(ix);
		tout = sprintf('RESULTS:\n%.3f Red (%.3f cd/m2) = Gray %.3f (%.3f cd/m2)\n',in,outy1,outx2,outy2);
end
disp(tout);
l=line(ax,[min(x) max(x)],[outy1 outy1],'LineStyle','--','Color','k','LineWidth',1);
l.HitTest = 'off';
l.PickableParts = 'none';
text(0.05, 80, tout);

% do the poly fitting
function [p1,p2,xx,yy] = fitted(x,y)
	if size(x,1)<size(x,2);x=x';end
	if size(y,1)<size(y,2);y=y';end
	f = fit(x,y,'poly1');
	xx = linspace(min(x),max(x),2^11)';
	yy = feval(f,xx);
	p1 = f.p1;
	p2 = f.p2;
end

% fitting back
function [valueColorkk] = reversfit(valueColork,k,b,kk,bb)
	valueColorkk = (valueColork*k+b-bb)/kk;
end

function [idx,val,delta]=findNearest(in,value)
	%find nearest value in a vector, if more than 1 index return the first
	[~,idx] = min(abs(in - value));
	val = in(idx);
	delta = abs(value - val);
end


