fid = fopen('training_set.csv', 'w');

%% ��ʼ������
for i=1:34
    eval(strcat('CONT',num2str(i),'=[];')); % Լ��������
end

All_data=xlsread('Power_Gas_Data.xlsx','A4:R169');


%% �����������
Data_of_traditional_generators=All_data(1:8,6:16);  % ��ͳ�������ȼ����ȼú�������в��� 
Data_of_branches=All_data(1:38,1:4);            % ����֧·�����в���
Data_of_buses=All_data(44:67,15:17);            % �����ڵ�����в���
Data_of_time_dependence=All_data(16:39,6:9);    % ��ʱ����صĵ�������������������Ϊ����
No_of_buses=size(Data_of_buses,1);              % �ڵ�����
No_of_traditional_generators=size(Data_of_traditional_generators,1);    % ��ͳ�������ȼ����ȼú�������� 
No_of_branches=size(Data_of_branches,1);        % �����ڵ������
Power_base=0.1;                                 % �����й����ʱ�ôֵ (��λ��GW)
t=Data_of_time_dependence(:,1);                 % ʱ���

for j=1:length(t)
    fprintf(fid,'powerfactor%d,',j);
end

for j=1:length(t)
    fprintf(fid,'gasfactor%d,',j);
end

for j=1:No_of_traditional_generators
    for t0=1:length(t)
        fprintf(fid,'power_generation%d_%d,',j,t0);
    end
end

fprintf(fid,'optimal_solution\n');

%% ������������
Data_of_pipelines=All_data(15:38,11:18);        % �����ܵ������в���
Data_of_compressors=All_data(44:46,1:3);        % ����ѹ���������в���
Data_of_storages=All_data(57:60,1:7);           % �������ܵ����в���
Data_of_wells=All_data(51:52,1:4);              % �������������в���
Data_of_gas_nodes=All_data(44:63,9:13);         % �����ڵ�����в���
No_of_wells=size(Data_of_wells,1);              % ��������
No_of_storages=size(Data_of_storages,1);        % ������������
No_of_gas_nodes=size(Data_of_gas_nodes,1);      % �����ڵ�����
No_of_pipelines=size(Data_of_pipelines,1);      % �����ܵ�������
No_of_compressors=size(Data_of_compressors,1);  % ѹ����������

Wind_turbine_located=All_data(9:10,6);
No_of_wind_turbines=size(Wind_turbine_located,1); % ȷ���������

%% �������������������Ķ����������ɾ����
WindFarmOutput=ones(1,24)*0.5;

%% ����Ŀ�꺯��
CuP=Data_of_traditional_generators(:,4);              % ÿ����������ı߼ʳɱ� (M$/GWh)
CkA=Data_of_buses(:,3);                   % �����и��ɳɱ� (M$/GWh)
CwG=Data_of_wells(:,4);                   % ��Ȼ���и��ɳɱ� (M$/MSm3)
CsS=Data_of_storages(:,7);                % ��Ȼ�����ܳɱ� (M$/MSm3)
CiB=Data_of_gas_nodes(:,5);               % �����и��ɳɱ� (M$/MSm3)

Pmax=Data_of_traditional_generators(:,2);            % ����������� (GW)
Pmin=Data_of_traditional_generators(:,3);            % ����������� (GW)

c=binvar(No_of_traditional_generators,length(t),'full');       % �����Ƿ��������е���������������ģ����Ψһ�볡���޹صı�����
pp=sdpvar(No_of_traditional_generators,length(t),'full');    % �������
pg=sdpvar(No_of_wells,length(t),'full');         % ���������� (MSm3/h)
np=sdpvar(No_of_buses,length(t),'full');         % �����и��� (GWh)
qst_out=sdpvar(No_of_storages,length(t),'full'); % ������ܵ���������
ng=sdpvar(No_of_gas_nodes,length(t),'full');     % �����и��� (MSm3)
wc=sdpvar(No_of_wind_turbines,length(t),'full'); % ������ (GW)
Cwu=[0;0];          % ����ɱ�����ʱ��������
CONT1=[CONT1,pp(:)>=0,ng(:)>=0,np(:)>=0,wc(:)>=0];

Objective=sum(CuP'*diag(Pmin)*c);       % Ŀ�꺯�����볡���޹صĳɱ�
Objective=Objective+sum(CuP'*pp+CwG'*pg+CkA'*np+CsS'*qst_out+CiB'*ng+Cwu'*wc); % Ŀ�꺯�����볡���йصĳɱ�

%% ����Լ������1���֣�: �������Լ��
rup=sdpvar(No_of_traditional_generators,length(t),'full');     % �������� (GW)
rdown=sdpvar(No_of_traditional_generators,length(t),'full');   % �������� (GW)
CONT2=[CONT2,rup(:)>=0,rdown(:)>=0];

Eq=pp(:,:)-diag(Pmax-Pmin)*c;      % ����pp<=c(Pmax-Pmin)�����ƻ������
CONT3=[CONT3,Eq(:)<=0];    
pp_initial=sdpvar(8,1,'full');
CONT3=[CONT3,Pmin<=pp_initial,pp_initial<=Pmax];
for t0=2:length(t)
    CONT4=[CONT4,pp(:,t0)+c(:,t0).*Pmin==pp(:,t0-1)+c(:,t0-1).*Pmin+rup(:,t0)-rdown(:,t0)];      % ���������µĹ�ϵ
end              %#ok<*AGROW> % Constraints as in Eq.(2)
CONT4=[CONT4,pp(:,1)+c(:,1).*Pmin==pp_initial+rup(:,1)-rdown(:,1)];    %���������µĹ�ϵ����t=1ʱ�̣�

RU=Data_of_traditional_generators(:,8);                % ���������� (GWh)
RD=Data_of_traditional_generators(:,7);                % ���������� (GWh)

for t0=1:length(t)
	CONT5=[CONT5,rup(:,t0)<=RU];       % ������������
	CONT6=[CONT6,rdown(:,t0)<=RD];     % ������������
end


Wdown=Data_of_wells(:,2);          % ������������ (MSm3/h)
Wup=Data_of_wells(:,3);            % ������������ (MSm3/h)

for t0=1:length(t)
    CONT7=[CONT7,Wdown<=pg(:,t0)<=Wup];   % ��������������С
end


%% ����Լ������2���֣�: ��������Լ��
sl=sdpvar(No_of_storages,length(t),'full');    % ���ܴ��� (MSm3)
qst_in=sdpvar(No_of_storages,length(t),'full');   % ע��ȼ���� (MSm3/h)
CONT8=[CONT8,sl(:)>=0];
Ssdown=Data_of_storages(:,2);      % ���ܴ������� (MSm3)
Ssup=Data_of_storages(:,3);        % ���ܴ������� (MSm3)
IR=Data_of_storages(:,4);      % ���ע��ȼ���� (MSm3/h)
WR=Data_of_storages(:,5);      % ����ȡȼ���� (MSm3/h)

for t0=2:length(t)
    CONT9=[CONT9,sl(:,t0)==sl(:,t0-1)+qst_in(:,t0)-qst_out(:,t0),Ssdown<=sl(:,t0)<=Ssup];   % ���ܴ���ƽ�ⷽ��
    CONT10=[CONT10,0<=qst_in(:,t0)<=IR,0<=qst_out(:,t0)<=WR]; % ���ܽ���Լ��
end

sl_initial=Data_of_storages(:,6);   % ���ܳ�ֵ

CONT11=[CONT11,sl(:,1)==sl_initial+qst_in(:,1)-qst_out(:,1),Ssdown<=sl(:,1)<=Ssup];
CONT12=[CONT12,0<=qst_in(:,1)<=IR,0<=qst_out(:,1)<=WR];

%The above constraints correspond to Eq.(8)(9)

R=(8.31446e-5)/(16.0425e-3);        % �������峣�� (m3bar/kgK)
T=273.15+8;                           % �¶� (K)
Z=0.8;                                % ѹ��ϵ�� (���������Z=1)
rou0=0.7156;                         % ��������µ������ܶ� (kg/m3)
qij_in=sdpvar(No_of_pipelines,length(t),'full');    % �ܵ�ij�ڽڵ�i�Ľ����� (MSm3/h)
qij_out=sdpvar(No_of_pipelines,length(t),'full');   % �ܵ�ij�ڽڵ�j�ĳ����� (MSm3/h)
qij_average=sdpvar(No_of_pipelines,length(t),'full');
qij_average(:)=(qij_in(:)+qij_out(:))/2;
p=sdpvar(No_of_gas_nodes,length(t),'full');         % �ڵ���ѹ(bar)
pij=sdpvar(No_of_pipelines,length(t),'full');       % �ܵ�ƽ����ѹ (bar)
mij=sdpvar(No_of_pipelines,length(t),'full');       % �ܵ�ƽ��ȼ������ (MSm3)

for j=1:No_of_pipelines
    pij(j,:)=(p(Data_of_pipelines(j,1),:)+p(Data_of_pipelines(j,2),:))/2;  %�ܵ�ƽ����ѹ���ʽ
    if ~isnan(Data_of_pipelines(j,3))       %����ܵ�����ѹ������
        mij(j,:)=(pi/4*Data_of_pipelines(j,3)*Data_of_pipelines(j,4)^2/R/T/Z/rou0)*pij(j,:)/1e6;
        % ��������ѹ�Ĺ�ϵ���򵥶��Ծ���pV=nRT)
    end
end

for t0=2:length(t)
    for ll=1:No_of_pipelines
        if ~isnan(Data_of_pipelines(ll,3))
            CONT17=[CONT17,mij(ll,t0,:)==mij(ll,t0-1,:)-qij_in(ll,t0,:)+qij_out(ll,t0,:)];
            % �ܵ���ѹ�����ȼ���Ĺ�ϵʽ
        end  
    end
end

mij_initial=sdpvar(No_of_pipelines,1,'full');
p_initial=sdpvar(No_of_gas_nodes,1,'full');
CONT13=[CONT13,Data_of_gas_nodes(:,3)<=p_initial<=Data_of_gas_nodes(:,2)];
CONT14=[CONT14,mij_initial>=0]; %��ʼ����

p_initial=[60.0469;60.0173;60.0042;53.1064;20.0122;30.0085;45.0116;53.1017;
   45.0000;66.1992;66.1984;66.1974;66.1950;53.0914;52.9544;52.5592;66.1365;
   76.4437;69.2551;65.4440];
for j=1:No_of_pipelines
     if ~isnan(Data_of_pipelines(j,3))
         mij_initial(j,1)=(pi/4*Data_of_pipelines(j,3)*Data_of_pipelines(j,4)^2 ...
         /R/T/Z/rou0)*(p_initial(Data_of_pipelines(j,1))+p_initial(Data_of_pipelines(j,2)))/2/1e6;
            CONT15=[CONT15,mij(j,1)==mij_initial(j,1)-qij_in(j,1)+qij_out(j,1)];
     end
end

%% ����ڵ�������������ʱ�䡢�������ı�
flow_direction=Data_of_pipelines(:,7);
for j=1:No_of_pipelines
    CONT16=[CONT16,flow_direction(j)*p_initial(Data_of_pipelines(j,1))>=flow_direction(j)*p_initial(Data_of_pipelines(j,2))];
    CONT16=[CONT16,flow_direction(j)*p(Data_of_pipelines(j,1),:)>=flow_direction(j)*p(Data_of_pipelines(j,2),:)];
    CONT16=[CONT16,flow_direction(j)*qij_average(j,:)>=0];
end

%% ��������Լ������2���֣�������
Fkl=Data_of_branches(:,4);
theta=sdpvar(No_of_buses,length(t),'full');
fp=sdpvar(No_of_branches,length(t),'full'); %��������
for t0=1:length(t)
    CONT20=[CONT20,-Fkl<=fp(:,t0)<=Fkl];
end

for j=1:No_of_branches
    CONT21=[CONT21,fp(j,:)==(theta(Data_of_branches(j,1),:)-theta(Data_of_branches(j,2),:))/Data_of_branches(j,3)];
end

%% ��������Լ������3���֣����ڵ�Լ��
for t0=1:length(t)
    CONT22=[CONT22,Data_of_gas_nodes(:,3)<=p(:,t0)<=Data_of_gas_nodes(:,2)];
end

for j=1:No_of_compressors
    CONT23=[CONT23,p(Data_of_compressors(j,1),:)<=p(Data_of_compressors(j,2),:)<=p(Data_of_compressors(j,1),:)*Data_of_compressors(j,3)];
end
penalty_factor=[1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1]'*ones(1,24)*2e-6;

for j=1:No_of_pipelines
    if flow_direction(j)==1
        CONST=sqrt((3600/1e6)^2*1e5*(pi/4)^2*Data_of_pipelines(j,4)^5/Data_of_pipelines(j,3)/Data_of_pipelines(j,5)/R/T/Z/rou0^2);
         if CONST<sqrt(1e-13)
             display('error!');
         end
        for t0=1:length(t)
            CONT34=[CONT34,norm([1/CONST*qij_average(j,t0),p(Data_of_pipelines(j,2),t0)],2)...
                <=p(Data_of_pipelines(j,1),t0)]; 
            CONT34=[CONT34,1/CONST*qij_average(j,t0)+p(Data_of_pipelines(j,2),t0)>=p(Data_of_pipelines(j,1),t0)];
            Objective=Objective+penalty_factor(j,t0)*(p(Data_of_pipelines(j,1),t0)-p(Data_of_pipelines(j,2),t0));
        end
    elseif flow_direction(j)==-1
        CONST=sqrt((3600/1e6)^2*1e5*(pi/4)^2*Data_of_pipelines(j,4)^5/Data_of_pipelines(j,3)/Data_of_pipelines(j,5)/R/T/Z/rou0^2);
         if CONST<sqrt(1e-13)
             display('error!');
         end
          for t0=1:length(t)
              CONT34=[CONT34,1/CONST*qij_average(j,t0)+p(Data_of_pipelines(j,2),t0)<=p(Data_of_pipelines(j,1),t0)];
              CONT34=[CONT34,norm([1/CONST*qij_average(j,t0),p(Data_of_pipelines(j,1),t0)],2)<=p(Data_of_pipelines(j,2),t0)];
          Objective=Objective+penalty_factor(j,t0)*(p(Data_of_pipelines(j,2),t0)-p(Data_of_pipelines(j,1),t0));
          end
    end
end

sum_mij=mij(1,24);
sum_mij_initial=mij_initial(1,1);

for j=1:No_of_pipelines
    if ~isnan(Data_of_pipelines(j,3))
        sum_mij=sum_mij+mij(j,24);
        sum_mij_initial=sum_mij_initial+mij_initial(j);
    end
end
sum_mij=sum_mij-mij(1,24);
sum_mij_initial=sum_mij_initial-mij_initial(1,1);
CONT34=[CONT34,sum_mij>=sum_mij_initial];
                                          
%% ��������Լ������1���֣����ڵ�ƽ�ⷽ��
rng(11);
No_of_total_samples=10000;
for iter=1:No_of_total_samples
CONT_IN_ITER=[];
coeff=0.05;
power_random=repmat(rand([1,length(t)])*coeff*2-coeff,No_of_buses,1);
gas_random=repmat(rand([1,length(t)])*coeff*2-coeff,No_of_gas_nodes,1);
%coeff_random=[-0.014543177,-0.001505967,-0.095728368,0.054179327,-0.010676401,-0.05232802,0.004573537,0.068010039,-0.080667087,-0.016786791,-0.017169382,0.01117177,0.037443677,0.010908408,0.071978547,0.082306737,-0.077455883,-0.060086125,0.025047892,-0.071135621,-0.007947131,0.094142994,0.057843909,-0.007643817,0.073299105,0.017070787,-0.077443272,0.005375228,0.039849971,0.098027011,0.063618332,0.049285089,-0.030742331,-0.007935341,0.004357366,-0.058442356,-0.021675493,-0.024309012,0.006386945,-0.026773437,0.056916603,0.05682926,0.091892814,0.010806745,0.016219822,0.056655795,-0.092633379,0.095361228];
%coeff_random=ones([1,length(t)*2])*-0.03;
%power_random=repmat(coeff_random(1:24),No_of_buses,1);
%gas_random=repmat(coeff_random(25:48),No_of_gas_nodes,1);
LkP=Data_of_buses(:,2)*Data_of_time_dependence(:,3)'.*(1+power_random);       % ������������
LiG=Data_of_gas_nodes(:,4)*Data_of_time_dependence(:,2)'.*(1+gas_random);    % ������������
no_meaning=sdpvar(No_of_buses,length(t),'full');


CONT_IN_ITER=[CONT_IN_ITER,no_meaning(:)==0];
temp=no_meaning;        %��ʼ��temp������ָ���ǽ���ýڵ�ĵ���

for j=1:No_of_branches
    %��ӳ���
    temp(Data_of_branches(j,1),:)=temp(Data_of_branches(j,1),:)-fp(j,:);
    temp(Data_of_branches(j,2),:)=temp(Data_of_branches(j,2),:)+fp(j,:);
end

for j=1:No_of_traditional_generators
    %��ӻ������
    temp(Data_of_traditional_generators(j,1),:)=temp(Data_of_traditional_generators(j,1),:)+pp(j,:)+c(j,:)*Pmin(j);
end

for j=1:No_of_buses
    temp(j,:)=temp(j,:)+np(j,:);
end

for j=1:No_of_wind_turbines
    temp(Wind_turbine_located(j),:)=temp(Wind_turbine_located(j),:)+WindFarmOutput-wc(j,:);
end

CONT_IN_ITER=[CONT_IN_ITER,temp==LkP];

% ����Compressor���֣���ʱ��Ϊ����Ҫ����������ͬʱ������Լ��flow in=flow out��
for j=1:No_of_pipelines
    if isnan(Data_of_pipelines(j,3))
        CONT_IN_ITER=[CONT_IN_ITER,qij_out(j,:)==qij_in(j,:)];
    end
end

no_meaning2=sdpvar(No_of_gas_nodes,length(t),'full');
CONT_IN_ITER=[CONT_IN_ITER,no_meaning2(:)==0];
temp2=no_meaning2;

for j=1:No_of_pipelines
    temp2(Data_of_pipelines(j,1),:)=temp2(Data_of_pipelines(j,1),:)-qij_out(j,:);
    temp2(Data_of_pipelines(j,2),:)=temp2(Data_of_pipelines(j,2),:)+qij_in(j,:);
end

for j=1:No_of_storages
    temp2(Data_of_storages(j,1),:)=temp2(Data_of_storages(j,1),:)+qst_out(j,:)-qst_in(j,:);
end

for j=1:No_of_wells
    temp2(Data_of_wells(j,1),:)=temp2(Data_of_wells(j,1),:)+pg(j,:);
end

for j=1:No_of_gas_nodes
    temp2(j,:)=temp2(j,:)+ng(j,:);
end

phi=[Data_of_traditional_generators(5,10),Data_of_traditional_generators(1,10),Data_of_traditional_generators(4,10)];
    Correlation=[2,5,14;                % ��һ�У���Ӧ�������ڵ�
             5,1,4;                 % �ڶ��У���Ӧ�ĵ����ڵ�
            15,1,13];               % �����У���Ӧ�Ļ������
for j=1:size(Correlation,2)
    temp2(Correlation(1,j),:)=temp2(Correlation(1,j),:)-phi(1,j)*(pp(Correlation(2,j),:)+c(Correlation(2,j),:)*Pmin(Correlation(2,j)));
end

CONT_IN_ITER=[CONT_IN_ITER,temp2==LiG];

%% ���÷�����Լ����������㹫ʽ��μ����£�
                                                                                       
Constraints=[CONT1,CONT2,CONT3,CONT4,CONT5,CONT6,CONT7,CONT8,CONT9,CONT10,CONT11,CONT12,CONT13,CONT14,...
    CONT15,CONT16,CONT17,CONT18,CONT19,CONT20,CONT21,CONT22,CONT23,CONT24,CONT25,CONT26,CONT27,CONT28,...
    CONT29,CONT30,CONT31,CONT32,CONT33,CONT34,CONT_IN_ITER];

%% �������������ĳ�ĩ��ϵʽ
ops=sdpsettings('solver','cplex','verbose',0);
sol=optimize(Constraints,Objective,ops);

%% ���������
if sol.problem==0
    Objective_value=value(Objective);
    Max_violations=[];
    for j=1:No_of_pipelines
        if flow_direction(j)==1
            CONST=sqrt((3600/1e6)^2*1e5*(pi/4)^2*Data_of_pipelines(j,4)^5/Data_of_pipelines(j,3)/Data_of_pipelines(j,5)/R/T/Z/rou0^2);        
            for t0=1:length(t)
                Objective_value=Objective_value-penalty_factor(j,t0)*(value(p(Data_of_pipelines(j,1),t0)-p(Data_of_pipelines(j,2),t0)));
                Max_violations=[Max_violations,(-(1/CONST*value(qij_average(j,t0)))^2-value(p(Data_of_pipelines(j,2),t0))^2+value(p(Data_of_pipelines(j,1),t0))^2)/value(p(Data_of_pipelines(j,1),t0))^2];
            end
        elseif flow_direction(j)==-1
            CONST=sqrt((3600/1e6)^2*1e5*(pi/4)^2*Data_of_pipelines(j,4)^5 ...
                 /Data_of_pipelines(j,3)/Data_of_pipelines(j,5)/R/T/Z/rou0^2);
            for t0=1:length(t)
                Objective_value=Objective_value-penalty_factor(j,t0)*(value(p(Data_of_pipelines(j,2),t0)-p(Data_of_pipelines(j,1),t0)));
                Max_violations=[Max_violations,(-(1/CONST*value(qij_average(j,t0)))^2-value(p(Data_of_pipelines(j,1),t0))^2+value(p(Data_of_pipelines(j,2),t0))^2)/value(p(Data_of_pipelines(j,2),t0))^2];
            end
        end
    end
    for i=1:length(t)
        fprintf(fid,'%d,',power_random(1,i));
    end
    for i=1:length(t)
        fprintf(fid,'%d,',gas_random(1,i));
    end

    for jj=1:No_of_traditional_generators
        for i=1:length(t)
            fprintf(fid,'%d,',value(pp(jj,i))+value(c(jj,i))*Pmin(jj));
        end
    end

    fprintf(fid,'%d\n',Objective_value);
else
    fprintf('error!');
end

end