% function IsoLumColorTransit
clear c igray igreen ired iblue fxgray fxgreen fxred fxblue fgray fgreen fred fblue in out
load('Display++Color++Mode-Ubuntu-RadeonPsychlab.mat')
igray	= c.inputValues(1).in;
igreen	= c.inputValues(3).in;
ired	= c.inputValues(2).in;
iblue	= c.inputValues(4).in;
x		= c.ramp;

[~,~,fxgray, fgray]		= fitted(x,igray);
[~,~,fxred, fred]		= fitted(x,ired);
[~,~,fxgreen, fgreen]	= fitted(x,igreen);
[~,~,fxblue, fblue]		= fitted(x,iblue);

figure('Units','normalized','Position',[0.2 0.2 0.6 0.6]);
hold on
pl = plot(x,igray,'ko'); ax = pl.Parent;
plot(x,igreen,'go');
plot(x,ired,'ro');
plot(x,iblue,'bo');
plot(fxgray,fgray,'k-');
plot(fxgreen,fgreen,'g-');
plot(fxred,fred,'r-');
plot(fxblue,fblue,'b-');
ylim([-5 round(max(igray)+5)]);
box on; grid on; grid minor;
title('RGB Luminance Outputs')
xlabel('RGB 0 <-> 1 Luminance')
ylabel('Physical Luminance (cd/m^2)')

disp('>>>What do you want? ')
reply = input('--->>>Red to Green press 1\n--->>>Green to Red press 2\n--->>>Green to Gray press 3\n--->>>Red to Gray press 4\n > ');
switch reply
    case 1
        in = input('Input the Red 0-1 value\n > ');
		incdm2 = in * max(ired);
        [k,b,rx,ry] =  fitted(x,ired);
        [kk,bb,gx,gy] = fitted(x,igreen);
        out = reversfit(in,k,b,kk,bb);
        [ix,iv,id] = findNearest(rx, in);
		outRx = rx(ix);
		outRy = ry(ix);
		[ix,iv,id] = findNearest(gy, outRy);
		outGx = gx(ix);
		outGy = gy(ix);
		fprintf('\nRESULTS:\n%.3f Red (%.3fcd/m2) = Green %.3f\n',in,outRy,outGx)
		fprintf('Green @ %.2f = %.2f cd/m2\n',outGx,outGy);
	case 2
        in = input('Input the Green 0-1 value\n > ');
		incdm2 = in * max(igreen);
        [k,b,rx,ry] =  fitted(x,igreen);
        [kk,bb,gx,gy] = fitted(x,ired);
        out = reversfit(in,k,b,kk,bb);
        [ix,iv,id] = findNearest(rx, in);
		outRx = rx(ix);
		outRy = ry(ix);
		[ix,iv,id] = findNearest(gy, outRy);
		outGx = gx(ix);
		outGy = gy(ix);
		fprintf('\nRESULTS:\n%.3f Green (%.3fcd/m2) = Red %.3f\n',in,outRy,outGx)
		fprintf('Red @ %.3f = %.3f cd/m2\n',outGx,outGy);
	case 3
        in = input('Input the Green 0-1 value\n > ');
		incdm2 = in * max(igreen);
        [k,b,rx,ry] =  fitted(x,igreen);
        [kk,bb,gx,gy] = fitted(x,igray);
        out = reversfit(in,k,b,kk,bb);
		[ix,iv,id] = findNearest(rx, in);
		outRx = rx(ix);
		outRy = ry(ix);
		[ix,iv,id] = findNearest(gy, outRy);
		outGx = gx(ix);
		outGy = gy(ix);
		fprintf('\nRESULTS:\n%.3f Green (%.3f cd/m2) = Gray %.3f\n',in,outRy,outGx)
		fprintf('Gray @ %.3f = %.3f cd/m2\n',outGx,outGy);
    case 4 
        in = input('Input the Red 0-1 value\n > ');
		incdm2 = in * (max(ired)-min(ired));
        [k,b,rx,ry] =  fitted(x,ired);
        [kk,bb,gx,gy] = fitted(x,igray);
        out = reversfit(in,k,b,kk,bb);
		[ix,iv,id] = findNearest(rx, in);
		outRx = rx(ix);
		outRy = ry(ix);
		[ix,iv,id] = findNearest(gy, outRy);
		outGx = gx(ix);
		outGy = gy(ix);
		fprintf('\nRESULTS:\n%.3f Red (%.3f cd/m2) = Gray %.3f\n',in,outRy,outGx)
		fprintf('Gray @ %.3f = %.3f cd/m2\n',outGx,outGy);

end
plot(rx,ry,'c--','LineWidth',1)
plot(gx,gy,'c--','LineWidth',1)
l=line(ax,[min(x) max(x)],[incdm2 incdm2],'LineStyle','--','Color','k','LineWidth',1);
l.HitTest = 'off';
l.PickableParts = 'none';

clear igray igreen ired iblue fxgray fxgreen fxred fxblue fgray fgreen fred fblue in out rx ry gx gy kx ky

% do the poly fitting
function [p1,p2,xx,yy] = fitted(x,y)
         p = polyfit(x,y,1);
		 xx = linspace(min(x),max(x),600);
		 yy = polyval(p,xx);
         p1 = p(1);
         p2 = p(2);
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


