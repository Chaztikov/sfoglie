close all
clear all
%format long eng

addpath('./panel/')
addpath('./Amplification/')
addpath('./geometry/')
addpath('./utilities/')
addpath('./models/')
addpath('./wake/')
addpath('./BoundaryLayer/')
set(groot, 'defaultAxesTickLabelInterpreter','LaTex'); set(groot, 'defaultLegendInterpreter','LaTex');

%%
%  air foil geometry and panels
%------------------------------------

% Parameters
profile.c = 1;       % scale factor of the profile   
profile.M = 80;      % number of x-values, where nodes will be -> 2*M-1 nodes in total

Invisc=false;% true; % % only inviscid solution or with Boundary Layer
profile.alfa = 2*pi/180;% 0; % 

profile.Uinfty=1; % Anstroemgeschwindigkeit
Re= 4e5;  %6.536*10^4;% 
nkrit=  9;%  % critical amplification exponent for transition to take place

%cinematic viscosity
nu= profile.c*profile.Uinfty /Re;

NACA = [4 4 1 2]; % naca profil
NoSkew=true; % if true profile skewness neclected

% blowing region
withBlowing=[true;...  % blowing on suction side  
             false];    % blowing on pressure side 
% start region         
xBstart= [0.25;...
          0.25]* profile.c;
% end region      
xBend  = [0.86;...
          0.86]* profile.c;
% blowing intensity      
intensity=[0.001;...
           0.001]* profile.Uinfty;

% tripping
trip=[ false;...       
       false];
% trip=[ true;... % tripping on suction side      
%        true];   % tripping on pressure side  
xtrip=[ 0.1;...
        0.1]*profile.c;

%--------------------------------------------------


NW= round(profile.M/4)+2; %   number of wake nodes
%calculates x- and y-component of homogeneous flow
ui = profile.Uinfty*cos(profile.alfa); 
vi = profile.Uinfty*sin(profile.alfa);

% % calculate NACA profile Nodes
% profile = naca4(profile,NACA,NoSkew);
 clear NACA NoSkew

% import profile Nodes
data=load('Nodes.txt');
profile.nodes.X=transpose(data(:,1));profile.nodes.Y=transpose(data(:,2));
profile.N=length(data(:,1)); clear data

% create the panels, identify if Profile has sharp or blunt trailing edge
profile = create_panels(profile);



%%
%  inviscid solution
%------------------------------------

% Solve potential flow
 [field]=potential(profile);  
 
 % get Leading edge position -> secant approximation
[ profile.Nle,profile.sLE,profile.LE1,profile.LE2 ] = getStagnationPoint( field.gamma, profile.s );
 
Nle=profile.Nle;
N=profile.N;
% arc length vector pressure side
profile.sL=profile.s(Nle:end)-(profile.s(Nle)-profile.LE2)*ones(1,N-Nle+1); 
% arc length vector suction side
profile.sU=(profile.s(Nle-1)+profile.LE1)*ones(1,Nle-1)-profile.s(1:Nle-1);   

xU=profile.panels.X(1,1:Nle-1);
xL=profile.panels.X(1,Nle:end);
if profile.IsSharp; xL=[xL,profile.panels.X(2,end) ]; end


% Plot polar curves
if Invisc
    Cp=1-field.gamma.^2;
    CL=getCL(profile,field.gamma);
    if profile.IsSharp; Cp=[Cp; Cp(1)]; end
    figure()
    hold on; box on
    plot([xU,xL(1)], Cp(1:Nle));
    plot(xL,  Cp(Nle:end));
    xlim([0 1]);
    legend('$C_p=1-\gamma(s)^2$ Saugseite','$C_p=1-\gamma(s)^2$ Druckseite');
end




%%
%  Wake influence
%------------------------------------



%   calculate wake node position
%------------------------------------
% done by integrating the streamline throug the TE of inviscid solution
wake=GetWakeStreamline(field,profile,NW);


% Plot wake
% figure(); 
% hold on; box on;
% plot([profile.panels.X]',[profile.panels.Y]','k','Linewidth',2);
% plot(wake.x,wake.y,'k');
% plot(XWt,YWt,'b');
% axis equal; xlabel('x'); ylabel('y')

if Invisc
   LEstr = LEstreamline( field,profile,round(3*NW/4) ,1.2);
   figure(); 
   hold on; box on;
   plot([profile.panels.X]',[profile.panels.Y]','k','Linewidth',2);
   plot(wake.x,wake.y,'b');
   plot(LEstr.x,LEstr.y,'b');
   axis equal; xlabel('x'); ylabel('y') 
   return;
end


% Source coefficient matrix for airfoil nodes Bges
%-------------------------------------------------------------

% influence of airfoil nodes -> i=1,..,N ; j=1,..,N
B=Qlin(profile.nodes.X', profile.nodes.Y' ,profile); % piecewise linear ansatz

% influence of wake nodes -> i=1,..,N ; j=N+1,..,N+NW
Bw=Qlin(profile.nodes.X', profile.nodes.Y' ,wake,true); 

Bges=[B, Bw];


% [L,U,ind] = lu(field.Ages,'vector');
% ALU= U + L-eye(size(field.Ages));

Ai=inv(field.Ages);

%invert airfoil node Coeffs -> Coefficients by means of eq (10)
Btilde=-Ai(1:profile.N,1:profile.N)*Bges;


% Source coefficient matrix for wake nodes Bges
%-------------------------------------------------------------

% influence of airfoil nodes -> i=N+1,..,N+NW ; j=1,..,N
[Cg, Cq] = GradPsiN( profile,wake );


% add gamma influence on Cq
Cq2= Cq - Cg*Btilde;


D= [Btilde;Cq2];
% make sure first wake point has same velocity as trailing edge
D(N+1,:)=D(N,:);

     

%global arclength vector
sges= [profile.s, (profile.s(end)+profile.panels.L(end)/2)*ones(size(wake.s)) + wake.s]; 




% Calculate inviscous velocity
%---------------------------------------------

% Velocity at airfoil nodes
%UinvFoil=  Ai*( field.psi0*ones(N,1)+field.t); %-> equal to field.gamma

UFoil = abs(field.gamma);
nix= [wake.n(1,1); wake.n(1,:)'];
niy= [wake.n(2,1); wake.n(2,:)'];

UWake = ui*niy - vi*nix + Cg*field.gamma;
UWake(1)=UFoil(end); % First wake point has same velocity as TE
clear nix niy

Uinv=[UFoil; UWake];


clear Do Du Bwake CqFoil Cqwake 
%% 

%  viscous solution
%----------------------------------------------

%   without blowing

% initial solution for global Newton Method
Vb=zeros(size(Uinv));
ini = GetInitialSolution( profile,wake, Uinv,Vb,Re, 2, trip, xtrip );
%PlotStuff(profile,wake,ini, 'delta');
%PlotStuff(profile,wake,ini, 'U');


it=20; % maximum number of iterations

%  coupled boundary layer and potential flow solution
[sol, prfE]=NewtonEq( profile,wake,ini,D,Uinv,it);


% plot
inds=(prfE.Nle-1:-1:1);             % suction side node indizes
indp=(prfE.Nle  :prfE.N);           % pressure side node indizes
indw=(prfE.N    :prfE.N + wake.N);  % wake node indizes

% PlotStuff(profile,wake,sol, 'delta');
% PlotStuff(profile,wake,sol, 'U');
% PlotStuff(profile,wake,sol, 'tau');
% PlotStuff(profile,wake,sol, 'Cp');




%   with blowing
%%

if ~withBlowing(1) && withB(2); return; end

Vb=zeros(size(Uinv));
if withBlowing(1)
    indB1= find( xU < xBend(1) & xU > xBstart(1));
    Vb(indB1)=intensity(1);
end
if withBlowing(2)
    indB2= find( xL < xBend(2) & xL > xBstart(2));
    indB2= indB2 + (profile.Nle-1)*ones(size(indB2));
    Vb(indB2)=intensity(2);
end

iniB = GetInitialSolution( profile,wake, Uinv,Vb,Re, 2, trip, xtrip  );
%PlotStuff(profile,wake,iniB, 'delta');

it=20;
%  coupled boundary layer and potential flow solution
[solB, prfB]=NewtonEq( profile,wake,iniB,D,Uinv,it);

indBs=(prfB.Nle-1:-1:1);            % suction side node indizes
indBp=(prfB.Nle :prfB.N);           % pressure side node indizes
indBw=(prfB.N   :prfB.N + wake.N);  % wake node indizes


% PlotStuff(profile,wake,solB, 'delta');
% PlotStuff(profile,wake,solB, 'U');
% PlotStuff(profile,wake,solB, 'tau');
% PlotStuff(profile,wake,solB, 'Cp');



%PlotStuff(prfB,wake,solB, 'tau', indBs);
%%

figure 
hold on
plot(prfE.nodes.X(1:prfE.N), sol.Cp(1:prfE.N) ,'g')
plot(prfE.nodes.X(1:prfE.N), solB.Cp(1:prfE.N) ,'b')
line([prfE.nodes.X(indB1(1))   prfE.nodes.X(indB1(1))]  , [-1 1],'color','black');
line([prfE.nodes.X(indB1(end)) prfE.nodes.X(indB1(end))], [-1 1],'color','black');
title('Pressure coefficient')
ylabel(' C_p ') 
xlabel(' x ')
legend('without blowing','with blowing','blowing region','location','northeast'); 

figure 
hold on
plot(prfE.nodes.X(1:prfE.N), sol.tau(1:prfE.N) ,'g')
plot(prfE.nodes.X(1:prfE.N), solB.tau(1:prfE.N) ,'b')
line([prfE.nodes.X(indB1(1))   prfE.nodes.X(indB1(1))]  , [min(solB.tau) max(sol.tau)],'color','black');
line([prfE.nodes.X(indB1(end)) prfE.nodes.X(indB1(end))], [min(solB.tau) max(sol.tau)],'color','black');
title('wall shear stress')
ylabel(' \tau_w ') 
xlabel(' x ')
legend('without blowing','with blowing','blowing region','location','northeast'); 


figure 
hold on
plot(prfE.nodes.X(1:prfE.Nle-1), sol.D(1:prfE.Nle-1) ,'k')
plot(prfE.nodes.X(1:prfE.Nle-1), sol.T(1:prfE.Nle-1) ,'b')
plot(prfE.nodes.X(1:prfE.Nle-1), solB.D(1:prfE.Nle-1) ,'r')
plot(prfE.nodes.X(1:prfE.Nle-1), solB.T(1:prfE.Nle-1) ,'g')
title('BL thickness on suction side')
ylabel(' \delta ') 
xlabel(' x ')
legend('$\delta_1$ without blowing','$\delta_2$ without blowing','$\delta_1$ with blowing','$\delta_2$ with blowing','location','northeast'); 

solB.Cf(solB.Cf>0.02)=0.02;
sol.Cf(sol.Cf>0.02)=0.02;




 
