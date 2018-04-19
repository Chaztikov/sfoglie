
init
parameters
[sol,prf,flo,~,~,~]=airfoil(prf,flo,tri,blo,eng);

CL_ref=sol.CL; CD_ref=sol.Cdrag; tr_ref=sol.tran.x;


return



%
%

% N=20;
% xTop=linspace(-0.05,1.05,N);
% xBot=linspace(-0.05,1.05,N);
% 
% tri.x=tr_ref;
% tri.active=[true; true];
% blo.active=true;
% 
% for i=1:N
%     for j=1:N
%         blo.x= {[xTop(i)]*prf.c;          %  midpoint of blowing area
%                 [xBot(j)]*prf.c;};  
%         [sol,~,~,~,~,~]=airfoil(prf,flo,tri,blo,eng);
%         CL(i,j)=sol.CL;
%         CD(i,j)=sol.Cdrag;
%     end
% end
% 
% contourf(xTop,xBot,(real(CL(:,:))./CD)'/(CL_ref/CD_ref))
% xlabel('x_M^{TOP}')
% ylabel('x_M^{BOTTOM}')




%       Polarcurve

% loop over alfas + write out   for CL over alfa plots
step=1;
for k=0:step:16

    flo.alfa= step *pi/180;
    aTMP=round(flo.alfa*180/pi,1);
    disp(['ALFA=',num2str(aTMP)])
    disp('--------------------------------------------')
    
    
    % evaluation
    [sol,prf,flo,~,~,~]=airfoil(prf,flo,tri,blo,eng);

    if k==0
        CP=sol.Cp(1:prf.N);
        TAU=sol.tau(1:prf.N);
        CL   =sol.CL ;
        Cnu  =sol.Cnu;
        Cdrag=sol.Cdrag;
        alph=aTMP;
        
        xTT= [sol.tran.x(1), sol.xseparation(1), sol.xreattach(1) ];
        
        TST= DragCoeff(sol.T(end),sol.HK(end),sol.U(end),1);
    else
        CP=[CP,sol.Cp(1:prf.N)];
        TAU=[TAU,sol.tau(1:prf.N)];
        CL=[CL;sol.CL];
        Cnu=[Cnu;sol.Cnu];
        Cdrag=[Cdrag;sol.Cdrag];
        alph=[alph;aTMP];
        
        xTT=[xTT;sol.tran.x(1), sol.xseparation(1), sol.xreattach(1) ];
        
        TST=[TST; DragCoeff(sol.T(end),sol.HK(end),sol.U(end),1)];
    end

end




% %%
% % % Plots
% %--------------------------------------------------
% 
% % quantities that can be plotted: 
% %'tau','Cf','Cfint','Cp','delta' ,'U', 'CD','D','H12' ,'H32', 'Ret'
% % section: 1 - pressure side, 2 - suction side, 3 - wake, 4 - suction and pressure side , 5 - all sections
% % OverArclength=true ->  plot over arclength s instead of x                 
% % section=4;
% % OverArclength=false;
% % PlotStuff(prf,flo.wake,sol, 'tau',section,OverArclength);
% %------------------------------------------------------------------
% 
% % default: section = 4, OverArclength=false;
% PlotStuff(prf,flo.wake,sol, 'tau');
% 
% 
% % Plots of Profiles
% % mode 1: plots Profil and wake with displacement thickness and shows CL, Cd usw.
% % mode 2: plots Profil and wake witch the nodepositions used
% % mode 3: plots Profil with transition locations andblowing distribution in blowing case
% mode=1;
% PlotProfile(prf,flo.wake,sol, mode);
% 
% % Comparison between blowing case and reference case without blowing
% % mode 1: only plots overview with reduction in CL and Cd
% % mode 2: plots overview + plots for suction side
% % mode 3: plots overview + plots for pressure side
% mode=1;
% BlowingComparison(prf,flo.wake,sol,prfB,solB,1);
% 










