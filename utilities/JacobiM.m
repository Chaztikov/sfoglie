function [ J, rhs] = JacobiM( gamma,D,L,m,T )
%JACOBIM        calculates the Jacobimatrix and right hand side for the Newton system for solution vector z=[T1,..,TN,m1,..,mN]^T 
%               gamma: circulation distribution
%               D: Coefficients of mass Defekt -> U = Uinv + Dm
%               L: Vector with panel length
%               m: mass defect vector from previous step
%               T: momentum thickness vector from previous step


nu=evalin('base','nu');
Nle=find(gamma<0);Nle=Nle(1); % find leading edge
Uinv=abs(gamma);
N=length(L); % node number on air foil

h=L(1:end-1);%without TE

U=Uinv+D*m; % total velocity

DI=m./U; %displacement thickness

%Filter unrealistic DI
% ind=find(DI(1:Nle-1)<1.02*T(1:Nle-1)); %suction side
% DI(ind)=0.02*T(ind);
% ind=find(DI(Nle:end)<1.00005*T(Nle:end)); % pressure side
% ind=ind+(Nle-1)*ones(length(ind),1);
% DI(ind)=1.00005*T(ind);

% panel midpoint approximations (without TE panel)
TM=(T(2:end)+T(1:end-1))/2;
DM=(DI(2:end)+DI(1:end-1))/2;
%mM=(m(2:end)+m(1:end-1))/2;
UM=(U(2:end)+U(1:end-1))/2;

% trailing edge panel
% TTE=(T(1)+T(end))/2;
% DTE=(DI(1)+DI(end))/2;
% mTE=(m(1)+m(end))/2;


% help quantities

H=DI./T; %shape parameter H1
%HM=(H(2:end)+H(1:end-1));%HM=DM./TM;
Ret= U.*T/nu;
%ReM=(Ret(2:end)+Ret(1:end-1));%UM.*TM/nu;


%initialising variables
Cf=zeros(N,1);CD=zeros(N,1); 
dCf_dH=zeros(N,1); dCf_dRet=zeros(N,1);
dCD_dH=zeros(N,1); dCD_dRet=zeros(N,1);
%dE_dH=zeros(N,1);E=zeros(N,1);
 H32=zeros(N,1);dH32_dH=zeros(N,1);

% calculate Cf, CD, E(energy thickness) and their derivates in respect to H and Ret
for i=1:N
    [ Cf(i), dCf_dH(i), dCf_dRet(i) ] = CF2lam( H(i), Ret(i));
%     [E(i), dE_dH(i)]=delta3lam(T(i),H(i));
%     [ CD(i), dCD_dH(i), dCD_dRet(i) ]=CD2lam(H(i),Ret(i),E(i)/T(i));
    [H32(i), dH32_dH(i)]=H32lam(H(i));
    [ CD(i), dCD_dH(i), dCD_dRet(i) ]=CD2lam(H(i),Ret(i),H32(i));
end

% mid point values
CfM=(Cf(2:end)+Cf(1:end-1))/2;
CDM=(CD(2:end)+CD(1:end-1))/2;
H32M=(H32(2:end)+H32(1:end-1))/2;
%EM=(E(2:end)+E(1:end-1))/2;

%derivates in respect to T
dRet_dT = U/nu;
dH_dT   =-H./T;
dH32_dT = dH32_dH.*dH_dT;

dCf_dT= dCf_dH.*dH_dT + dCf_dRet.*dRet_dT;
dCD_dT= dCD_dH.*dH_dT + dCD_dRet.*dRet_dT + dH32_dT.*CD./H32;
% dE_dT=E./T + dE_dH.*dH_dT;
% dCD_dT= dCD_dH.*dH_dT + dCD_dRet.*dRet_dT -CD./T +dE_dT.*CD./E;

%derivates in respect to D
dH_dD   = 1./T;
dCf_dD  = dCf_dH .*dH_dD;
dH32_dD = dH32_dH.*dH_dD;
dCD_dD  = dCD_dH .*dH_dD + dH32_dD.*CD./H32;

% dE_dD=dE_dH.*dH_dD;
% dCD_dD= dCD_dH.*dH_dD + dE_dD.*CD./E;



%derivates in respect to U
dRet_dU= T/nu;
dCf_dU = dCf_dRet.*dRet_dU;
dCD_dU = dCD_dRet.*dRet_dU;



% finite differences of each panel
dT=T(2:end)-T(1:end-1);
dU=U(2:end)-U(1:end-1);
%dE=E(2:end)-E(1:end-1);
%I=ones(N-1,1); % Einheitsmatrix
dH32=H32(2:end)-H32(1:end-1);


% momentum equation -> right hand side of Newton System
f1=dT./h+(2*TM+DM)./(h.*UM).*dU-CfM;


%shape parameter equation -> right hand side of Newton System
%f2= dE./h - EM./(TM.*h).*dT + EM.*(I-DM./TM).*dU./(h.*UM) -CDM + EM./TM.*CfM;
f2= TM.*dH32 + H32M.*(TM-DM).*dU./(h.*UM) -CDM + H32M.*CfM;


% derivates of the momentum equation
df1_dT1= -1./h + dU./(UM.*h) - dCf_dT(1:end-1);
df1_dT2=  1./h + dU./(UM.*h) - dCf_dT(2:end);
df1_dD1=  dU./(2*h.*UM) - dCf_dD(1:end-1);
df1_dD2=  dU./(2*h.*UM) - dCf_dD(2:end);
df1_dU1= -(2*TM+DM)./(h.*UM) -(2*TM+DM).*dU./(2*h.*UM.^2) - dCf_dU(1:end-1);
df1_dU2=  (2*TM+DM)./(h.*UM) -(2*TM+DM).*dU./(2*h.*UM.^2) - dCf_dU(2:end);



% derivates of the shape parameter equation

     
df2_dT1=   dH32./(2*h) - TM.*dH32_dT(1:end-1)./h - H32M.*dU./(2*h.*UM) ...
         + dH32_dT(1:end-1).*(DM-TM).*dU./(2*h.*UM) - dCD_dT(1:end-1) ...
         + dH32_dT(1:end-1).*CfM + H32M.*dCf_dT(1:end-1);
df2_dT2=   dH32./(2*h) + TM.*dH32_dT(2:end)./h - H32M.*dU./(2*h.*UM) ...
         + dH32_dT(2:end).*(DM-TM).*dU./(2*h.*UM) - dCD_dT(2:end) ...
         + dH32_dT(2:end).*CfM + H32M.*dCf_dT(2:end);


df2_dD1= - TM.*dH32_dD(1:end-1) + H32M.*dU./(2*h.*UM) + dH32_dD(1:end-1).*(DM-TM).*dU./(2*h.*UM) ...
         - dCD_dD(1:end-1)/2  + H32M.*dCf_dD(1:end-1) + dH32_dD(1:end-1).*CfM;
df2_dD2= + TM.*dH32_dD(2:end) + H32M.*dU./(2*h.*UM) + dH32_dD(2:end).*(DM-TM).*dU./(2*h.*UM) ...
         - dCD_dD(2:end)/2  + H32M.*dCf_dD(2:end) + dH32_dD(2:end).*CfM;    

df2_dU1= - H32M.*(DM-TM)./(h.*UM) - H32M.*(DM-TM).*dU./(2*h.*UM.^2) ...
         - dCD_dU(1:end-1) + H32M.*dCf_dU(1:end-1);
df2_dU2=   H32M.*(DM-TM)./(h.*UM) - H32M.*(DM-TM).*dU./(2*h.*UM.^2) ...
         - dCD_dU(2:end) + H32M.*dCf_dU(2:end);

%{
         % df2_dT1=    EM./(TM.*h) + EM./TM.^2.*dT./(2*h) + EM.*DM./TM.^2.*dU./(2*h.*UM) ...
%           - dE_dT(1:end-1)./h + dE_dT(2:end).*dT./(2*TM.*h) ...
%           + dE_dT(1:end-1).*(I-DM./TM).*dU./(2*h.*UM) ...
%           + dE_dT(1:end-1)./(2*TM).*CfM - dCD_dT(1:end-1)/2 ...
%           + EM./(2*TM).*dCf_dT(1:end-1) - EM./(2*TM.^2).*CfM;
%       
% df2_dT2=  - EM./(TM.*h) + EM./TM.^2.*dT./(2*h) + EM.*DM./TM.^2.*dU./(2*h.*UM) ...
%           + dE_dT(2:end)./h + dE_dT(2:end).*dT./(2*TM.*h) ...
%           + dE_dT(2:end).*(I-DM./TM).*dU./(2*h.*UM) ...
%           + dE_dT(2:end)./(2*TM).*CfM - dCD_dT(2:end)/2 ...
%           + EM./(2*TM).*dCf_dT(2:end) - EM./(2*TM.^2).*CfM;
% 
% df2_dD1= - EM./TM.*dU./(2*h.*UM) - dCD_dD(1:end-1)/2 + EM./(2*TM).*dCf_dD(1:end-1) ...
%          - dE_dD(1:end-1).*DM./TM.*dU./(2*h.*UM) + dE_dD(1:end-1)./(2*TM).*CfM  ;
% df2_dD2= - EM./TM.*dU./(2*h.*UM) - dCD_dD(2:end)/2 + EM./(2*TM).*dCf_dD(2:end) ...
%          - dE_dD(2:end).*DM./TM.*dU./(2*h.*UM) + dE_dD(2:end)./(2*TM).*CfM  ;
% 
% df2_dU1= - EM.*(I-DM./TM)./(h.*UM) - EM.*(I-DM./TM).*dU./(2*h.*UM.^2) ...
%          - dCD_dU(1:end-1)/2 +  EM./(2*TM).*dCf_dU(1:end-1);
% df2_dU2=   EM.*(I-DM./TM)./(h.*UM) - EM.*(I-DM./TM).*dU./(2*h.*UM.^2) ...
%          - dCD_dU(2:end)/2 +  EM./(2*TM).*dCf_dU(2:end);
%}

% switch to m as variable

%derivates of D,U in respect to m
dD1_dm= zeros(N-1,N); dD2_dm= zeros(N-1,N);
tmp=m./U.^2;
for k=1:N-1
    dD1_dm(k,:)=tmp(k)*D(k,:); % node "1"
    dD2_dm(k,:)=tmp(k+1)*D(k+1,:); % node "2"
end
% dDi_dmj=1/Ui delta_ij - mi/ui^2 dUi_dmj
dD1_dm=-dD1_dm + [diag(1./U(1:end-1)), zeros(N-1,1)];
dD2_dm=-dD2_dm + [zeros(N-1,1),diag(1./U(2:end))];
dU1_dm=[diag(1./U(1:end-1)), zeros(N-1,1)];
dU2_dm=[zeros(N-1,1),diag(1./U(2:end))];
   
% total derivates of equations in respect to m
df1_dm= zeros(N-1,N); df2_dm= zeros(N-1,N);
for k=1:N-1
     % equation 1-> momentum
    df1_dm(k,:)=   df1_dD1(k)*dD1_dm(k,:) + df1_dD2(k)*dD2_dm(k,:) ...
                 + df1_dU1(k)*dU1_dm(k,:) + df1_dU2(k)*dU2_dm(k,:);
    % equation 2-> shape parameter
    df2_dm(k,:)=   df2_dD1(k)*dD1_dm(k,:) + df2_dD2(k)*dD2_dm(k,:) ...
                 + df2_dU1(k)*dU1_dm(k,:) + df2_dU2(k)*dU2_dm(k,:); 
end


% create Jacobi matrix for Newton System

% contribution of momentum eq
JT1= [diag(df1_dT1), zeros(N-1,1)]; % last node is never a "1" node
JT2= [zeros(N-1,1), diag(df1_dT2)]; % first node is never a "2" node
JTf1= JT1+JT2;
%Jmf1= df1_dm; % mass defect-> all nodes contribute to "1" and "2"


% contribution of shape parameter eq
JT1= [diag(df2_dT1), zeros(N-1,1)]; % last node is never a "1" node
JT2= [zeros(N-1,1), diag(df2_dT2)]; % first node is never a "2" node
JTf2= JT1+JT2;

%Total T part
JT=zeros(2*(N-1),N);
JT(1:2:end-1,1:1:N)=JTf1;
JT(2:2:end,1:1:N)=JTf2;

Jm=zeros(2*(N-1),N);
Jm(1:2:end-1,:)=df1_dm;
Jm(2:2:end,:)=df2_dm;

J=[JT,Jm];

rhs=zeros(2*(N-1),1);
rhs(1:2:end-1)=f1;
rhs(2:2:end)=f2;

%Set starting conditions to close LGS
  
% set TM and mM of LE panel to zero
  Tin=zeros(1,2*N);
  Tin(Nle-1:Nle)=1/2;
  min=zeros(1,2*N);
  min(end,N+Nle-1:N+Nle)=1/2;
    
  J=[J;Tin;min];
  rhs=[rhs;0;0];  
  
  
% %going over to m as Variable
% % nur Element i,j geht in Ableitung ein (falsch?)
% dU1_dm1=diag(D(1:end-1,1:end-1)); % Diagonale
% dU1_dm2=diag(D(1:end-1,2:end));   % rechte Nebendiagonale
% dU2_dm1=diag(D(2:end,1:end-1));   % linke Nebendiagonale
% dU2_dm2=diag(D(2:end,2:end));     % Diagonale
% dD1_dm1= 1./U(1:end-1) -m(1:end-1)./U(1:end-1).^2.*dU1_dm1 ; 
% dD1_dm2= 1./U(1:end-1) -m(1:end-1)./U(1:end-1).^2.*dU1_dm2 ; 
% dD2_dm1= 1./U(2:end) -m(2:end)./U(2:end).^2.*dU2_dm1 ; 
% dD2_dm2= 1./U(2:end) -m(2:end)./U(2:end).^2.*dU2_dm2 ;
% 
% df1_dm1=     df1_dD1*dD1_dm1+df1_dD2*dD2_dm1 ...
%            + df1_dU1*dU1_dm1+df1_dU2*dU2_dm1;
%     
% df2_dm2=     df2_dD1*dD1_dm1+df2_dD2*dD2_dm1 ...
%            + df2_dU1*dU1_dm1+df2_dU2*dU2_dm1;
%      
%  JT= [df1_dT1 , df1_dT2; df2_dT1, df2_dT2];
%  
%  
%  JM= [df1_dm1 , df1_dm2; df2_dm1, df2_dm2];
     


end

