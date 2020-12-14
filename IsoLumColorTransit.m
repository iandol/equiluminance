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
        [k,b] =  fitted(x,ired);
        [kk,bb] = fitted(x,igreen);
        out = reversfit(in,k,b,kk,bb);
        disp([num2str(in),' Red (' num2str(incdm2) 'cd/m2) = Green ',num2str(out)]);
		disp(['Green @ ' num2str(out) ' = ' num2str(out*max(igreen)) ' cd/m2'])
	case 2
        in = input('Input the Green 0-1 value\n > ');
		incdm2 = in * max(igreen);
        [k,b] =  fitted(x,igreen);
        [kk,bb] = fitted(x,ired);
        out = reversfit(in,k,b,kk,bb);
        disp([num2str(in),' Green (' num2str(incdm2) 'cd/m2) = Red ',num2str(out)]);
		disp(['Red @ ' num2str(out) ' = ' num2str(out*max(ired)) ' cd/m2'])
	case 3
        in = input('Input the Green 0-1 value\n > ');
		incdm2 = in * max(igreen);
        [k,b] =  fitted(x,igreen);
        [kk,bb] = fitted(x,igray);
        out = reversfit(in,k,b,kk,bb);
        disp([num2str(in),' Green (' num2str(incdm2) 'cd/m2) = Gray ',num2str(out)]);
		disp(['Gray @ ' num2str(out) ' = ' num2str(out*max(igray)) ' cd/m2'])
    case 4 
        in = input('Input the Red 0-1 value\n > ');
		incdm2 = in * max(ired);
        [k,b] =  fitted(x,ired);
        [kk,bb] = fitted(x,igray);
        out = reversfit(in,k,b,kk,bb);
        disp([num2str(in),' Red (' num2str(incdm2) 'cd/m2) = Gray ',num2str(out)]);
		disp(['Gray @ ' num2str(out) ' = ' num2str(out*max(igray)) ' cd/m2'])	
end
l=line(ax,[min(x) max(x)],[incdm2 incdm2],'LineStyle','--','Color','k','LineWidth',1);
l.HitTest = 'off';
l.PickableParts = 'none';

clear igray igreen ired iblue fxgray fxgreen fxred fxblue fgray fgreen fred fblue in out

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


