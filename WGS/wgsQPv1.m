%% An implementation of WGS method to solve convex QP problems
% Please refer to the article: A WEIGHTED GRAM-SCHMIDT METHOD FOR CONVEX QUADRATIC PROGRAMMING
% This m-function solves the following convex QP prroblem:
% minimize c^T*x + 1/2*x^T*H*x
% subject to lx <= x, x <= ux, AAx >= lg
% The frame of the active-set method comes from Chapter 16 of the book:
% NUMERICAL OPTIMIZATION, 2006
% 
% August 8th, 2015
% ע��v1����8��20�յ�����ɵ�һ����ȷ�汾������Ϊ��ʱ̫���������Ҫ�ں����汾�н����Ż�
% ���ﱣ��һ����ȷ�汾��ʹ�ú����ڴ�����������ʱ����Իظ���������


%% Matrix dimension 
% H:  ndec*ndec;    % ndec = nv + nf;    
% Hv: nv*nv;
% Hf: nf*nf;
% R:  ndec*ndec;
% Rv: nv*nv;
% Rf: nf*nf;
% C:  t*ndec;       % t = nf+ml;
% If: nf*nf;
% A:  ml*ndec;
% Av: ml*nv;
% Af: ml*nf;
% Lv: ml*ml;
% Yv: nv*ml;
% g:  ndec*1;
% gv: nv*1;
% gf: nf*1;
% uv: nv*1;
% wv: nv*1;
% vl: ml*1;

%clc;clear;

%% Test data
% %Data1  
% H = [ 4.5267, -3.9095,  0.6937, -7.1302,  1.2138, -0.9079;
%      -3.9095, 42.3583, -7.1494, 11.0149, -1.0405,  0.7782;
%       0.6937, -7.1494,  3.3094, -2.8661,  0.3464, -0.2591;
%      -7.1302, 11.0149, -2.8661, 41.4638, -6.8516,  5.1248;
%       1.2138, -1.0405,  0.3464, -6.8516,  3.2103, -0.9053;
%      -0.9079,  0.7782, -0.2591,  5.1248, -0.9053,  2.6771];
% c = [16.8930; -53.6424; 9.4920; -47.2980; 7.3800; -5.5200];
% lub= [-2;-2;-2;-2;-2;-2;2;2;2;2;2;2];
% lg = [-3;-3;-3;-3;-3;-3];
% nbc = length(lub)/2;
% AA = [-1,  1,  0,       0,       0,       0;
%     -0.0704,  1.3926, -0.2460,  0.1840,  0,       0;
%     -0.2467,  0.2115, -0.0704,  1.3926, -0.2460,  0.1840;
%        1, -1,  0,       0,       0,       0;
%     0.0704, -1.3926,  0.2460, -0.1840,  0,       0;
%     0.2467, -0.2115,  0.0704, -1.3926,  0.2460, -0.1840];
% wf = [7];
% wl = [1];
% nf = 1;
% ml = 1;
% x = [2;-1;0;0;0;0];

% %Data2
% H = [ 7,    8.2,  8.7, 7;
%       8.2,  9.8, 10.2, 8;
%       8.7, 10.2, 11.7, 9;
%       7,    8,    9,  10];
% c = [1;1;2;3];
% lub= [-4;-4;-4;-4;4;4;4;4];
% lg = [2;-3];
% nbc = length(lub)/2;
% AA = [1,1,0,0;0,1,0,1];
% wf = [3];
% wl = [1,2];
% nf = 1;
% ml = 2;
% x = [2;0;-4;-3];

% %Data3
% H = [ 7,    8.2,  8.7, 7;
%       8.2,  9.8, 10.2, 8;
%       8.7, 10.2, 11.7, 9;
%       7,    8,    9,  10];
% c = [1;1;2;3];
% lub= [-4;-4;-4;-4;4;4;4;4];
% lg = [2;1];
% nbc = length(lub)/2;
% AA = [1,1,0,0;1,0,1,0];
% wf = [];
% wl = [1];
% nf = 0;
% ml = 1;
% x = [3;0;0;-4]; % ��ȷ�Ĳ��Գ�ʼֵ
% % x = [3;0;0;-3]; % ����Error�õĴ����ֵ

% %Data 4~5
% %load failedData1
% %load failedData2
% %load failedData3
% %load failedData4
% load failedData5
% H = H_ori;
% c = c_ori;
% x = x_ori;
% wf = [];
% wl = [];
% nf = 0;
% ml = 0;


%% API declaration
% It is required that the H is ordered that last nf variables are fixed
% wf is the initial working set for bound constraints
% wl is the initial working set for general constraints

function xStar = wgsQPv1(H,c,AA,lx,ux,lg,wf,wl,nf,ml,x)
alpha = [];

lub = [lx;ux];
nbc = length(lub)/2;

% Parameters setting
maxIter = 200;

[ngc,ndec] = size(AA);
nv = ndec - nf;

% Here we check whether the intial x is feasible with given constraints
for i = 1:ndec
    if x(i) < lub(i)-0.000001 || x(i) > lub(i+ndec)+0.000001
        error('Initial x infeasible with bound constraint!');
    end   
end
if min(AA*x - lg) < -0.000001
    error('Initial x infeasible with general constraint!');
end

% Here we check whether the initial x accords with the initial working set
for i = 1:length(wf)
    consIndex = wf(i);
    xIndex = mod(consIndex,ndec);
    if xIndex == 0
        xIndex = ndec;
    end
    if x(xIndex) ~= lub(consIndex)
        error('Initial x does not fit with initial working set! (Bound constraint)');
    end        
end
for i = 1:length(wl)
    consIndex = wl(i);
    if AA(consIndex,:)*x ~= lg(consIndex)
        error('Initial x does not fit with initial working set! (General constraint)');
    end
end

% Here order is used to keep track of the order change of decision
% variables
order = 1:ndec;
order = order';
origin = order;
PiGlobal = eye(ndec,ndec);      % һ��ȫ�ֵ��Ŷ��������Լ�¼ȫ�ַ�Χ�ڶ� x �� pernmute
H_ori = H;                      % H �ı��ݣ������������ H �� permute �Ƿ���ȷ����
c_ori = c;
x_ori = x;

% ������� bound constraint ��Ӧ�� x ���ٿ��� nf ��λ���ϣ���������Ҫ�����ǵ�������Ӧ��λ����ȥ
% If the last nf items of x is not according with the initial bound constraints
% we should adjust it to meet the requirement of the algorithm
for i = 1:length(wf)
    Pi = eye(ndec,ndec);
    boundIndex = wf(i);
    fixedIndex = mod(boundIndex,ndec);
    if fixedIndex==0
        fixedIndex = ndec;
    end
    fixedPos = nv+1;
    if fixedIndex <= nv  % means the fixed item of x is in the first nv rows, needs adjustment
        Pi(fixedIndex,fixedIndex) = 0;
        Pi(fixedPos,fixedPos) = 0;
        Pi(fixedIndex,fixedPos) = 1;
        Pi(fixedPos,fixedIndex) = 1;
        order = Pi*order;
        H = Pi'*H*Pi;
        c = Pi*c;
        PiGlobal = Pi*PiGlobal;
    end
end
% Note that the order of x variable in the code is never permuted
gx = PiGlobal*(c_ori + H_ori*x);
gv = gx(1:nv,:);
gf = gx(nv+1:ndec);
cv = c(1:nv);
cf = c(nv+1:ndec);

%------------------Check the rightness of input parameter------------------
if length(wf) ~= nf
    error('Fixed constraints number error!');
end
if length(wl) ~= ml
    error('General constraints number error!');
end
%--------------------------------------------------------------------------

t = nf + ml;
nv = ndec - nf;

Hv = H(1:nv,1:nv);
Hf = H(nv+1:ndec,nv+1:ndec);
K = H(1:nv,nv+1:ndec);

R = chol(H);        % Cholesky factorization
Rv = R(1:nv,1:nv);
Rf = R(nv+1:ndec,nv+1:ndec);
S = R(1:nv,nv+1:ndec);

%% Compute pStar for the first iteration
Yv = [];
Lv = [];
A = [];
% If ml = 0, which means there is no general constraints
if ml == 0
    pvStar = linsolve(Hv,-gv);
    p = [pvStar;zeros(nf,1)];
    p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
else
    % A is the general constraint in the current working set
    for i = 1:ml
        A = [A;AA(wl(i),:)*PiGlobal];
    end
    if isempty(A)
        error('A should not be empty!');
    else
        Av = A(:,1:nv);
        Af = A(:,nv+1:ndec);
    end
    
    % Do the factorization
    invRv = inv(Rv);
    if ~isempty(A)
        AinvR = Av*invRv;
        [Qtmp,Rtmp] = qr(AinvR');   % To achieve WGS factorization
        Yv = Qtmp(:,1:ml);
        Lv = Rtmp(1:ml,:)';
    end
    
    % Initial value of auxiliary vectors
    uv = linsolve(Rv',gv);
    vl = Yv'*uv;
    wv = Yv*vl-uv;
    pvStar = linsolve(Rv,wv);
    p = [pvStar;zeros(nf,1)];
    p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
end

% �Ӽ���õ�p��ʼÿ���ڵĵ���
for iter = 1:maxIter
    
    if iter == maxIter
        error('Maximum iteration reached!');
    end
        
    %% Decide the changes in the working set according to pStar
    if (isZero(p,1e-9) == 1)            % Check whether pStar is zero vector
        if ml == 0
            lambdaf = zeros(nf,1);
            % ��Ϊ�Լ�������������е�������ʽ��ͬ��������Ҫ�� lub �Ĺ�����
            % ����������Ҫ��һ������ lub ��Ӧ�� gf �ĺ�벿�ֱ��
            for i = 1:nf
                if wf(i) <= nbc
                    lambdaf(i) = gf(i);
                else
                    lambdaf(i) = -gf(i);
                end
            end            
            lambdal = [];
            lambda = [lambdaf;lambdal];
        else
            lambdal = linsolve(Lv',vl);           
            K = H(1:nv,nv+1:ndec);
            
            lambdaf = gf + K'*pvStar - Af'*lambdal;
            lambdaff = gf_tilde - Af'*lambdal;
            % ��Ϊ�Լ�������������е�������ʽ��ͬ��������Ҫ�� lub �Ĺ�����
            % ����������Ҫ��һ������ lub ��Ӧ�� gf �ĺ�벿�ֱ��
            for i = 1:nf
                if wf(i) > nbc
                   lambdaf(i) = -lambdaf(i);
                end
            end
            lambda = [lambdaf;lambdal];
        end
        if ((isempty(wf) && isempty(wl)) || min(lambda) >= 0)     % Final solution reached
            xStar = x;
            %finalAS = w;
            break;      % Quit iteration from here
        else
            minlambdal = min(lambdal);
            minlambdaf = min(lambdaf);         
            if (isempty(lambdal) || (~isempty(lambdaf) && minlambdaf < minlambdal))
                %% Delete a bound constraint
                [~,index] = min(lambdaf);
                indexJ = mod(wf(index),nbc);
                if indexJ == 0
                    indexJ = nbc;
                end
                indexJ = find(order==indexJ);
                wf(index) = wf(1);
                wf(1) = [];
                % Other updates can be implemented here ...
                if indexJ <= nv
                    error('Bound constraints must be in last nf rows');
                end
                % ����Ҫ����H���϶�����Ҫ�ѱ�ɾ�� fixed constraint ��Ӧ�� x �Ӻ� nf �ᵽǰ nv ��
                % Order permutation
                Pi = eye(ndec,ndec);        % ���� Pi ʵ�ֵĹ��ܾ��ǰ�indexJ�к�nv+1�е���
                Pi(indexJ,indexJ) = 0;
                Pi(nv+1,nv+1) = 0;
                Pi(indexJ,nv+1) = 1;
                Pi(nv+1,indexJ) = 1;
                order = Pi*order;
                PiGlobal = Pi*PiGlobal;
                                
                H = Pi'*H*Pi;
                gx = [gv;gf];
                gx = Pi * gx;
                gv = gx(1:nv+1,:);
                gf = gx(nv+2:ndec);
                c = [cv;cf];
                c = Pi * c;
                cv = c(1:nv+1);
                cf = c(nv+2:ndec);
                                
                h = H(nv+1,1:nv)';
                eta = H(nv+1,nv+1);
                r = linsolve(Rv',h);
                rau = (eta-r'*r)^(1/2);
                Rv_bar = [Rv,r;zeros(1,nv),rau];
                Rv = Rv_bar;
                Hv = Rv'*Rv;                                  
                
                nv = nv + 1;
                nf = nf - 1;
                
                % Second storage option to update gf;
                Hf = H(nv+1:ndec,nv+1:ndec);
                K = H(1:nv,nv+1:ndec);
                x_order = PiGlobal*x;
                xv = x_order(1:nv,:);
                xf = x_order(nv+1:ndec,:);
                m = Hf*xf+cf;
                gf_tilde = m+K'*xv;
                
                % �����¼A����Ϊ�˺�����֤Af�ĸ��¶Բ���
                if ~isempty(A)
                    A = A*Pi;
                end
                
                if ml == 0
                    if (~isempty(wl))
                        error('Working set error!');
                    end
                    %----ע�������ڸ���Av��ʱ��˳���AҲ����һ�£������ں���У��Af----
                    Av = [];
                    Af = [];
                    wl = [];
                    Yv = [];
                    Lv = [];
                    A = [];                 
                    pvStar = linsolve(Hv,-gv);
                    p = [pvStar;zeros(nf,1)];
                    p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
                else
                    % Update Lv, Yv, Af, Av;
                    ev1 = zeros(nv,1);
                    ev1(nv,:) = 1;
                    q = linsolve(Rv_bar,ev1);
                    a = Af(:,indexJ-nv+1);
                    Af(:,indexJ-nv+1) = Af(:,1);
                    Af(:,1) = [];
                    Av_bar = [Av,a];
                    v = Av_bar * q;
                    LvvTrans = [Lv,v]';
                    LvvTransTmp = LvvTrans;
                    P = eye(ml+1,ml+1);
                    for i = 1:ml
                        [G,y] = planerot([LvvTransTmp(i,i);LvvTransTmp(ml+1,i)]);
                        tempP = formRot(G,i,ml+1,ml+1);
                        LvvTransTmp = tempP*LvvTransTmp;
                        %tempP*S'   % To check the rightness of tempP
                        P = tempP*P;
                    end
                    P = P';
                    LvvP = LvvTrans'* P; % Shoud has the form of (4.12) ~ (4.13)
                    Lv_bar = LvvP(:,1:ml);
                    YvP =[Yv,zeros(nv-1,1);zeros(1,ml),1]*P;
                    Yv_bar = YvP(:,1:ml);
                    z_bar = YvP(:,ml+1);
                    Lv = Lv_bar;
                    Yv = Yv_bar;
                    Av = Av_bar;
                    if max(max(abs(Lv*Yv'*Rv-Av))) > 0.0000001
                        error('Update error!');
                    end
                    
                    % ע�⣡�����Af�ĸ��������⣡��
                    
                    % �����Af�ĸ��½���У��
                    recoA = [Av,Af];
                    if max(max(abs(A-recoA))) > 0.0000001
                        error('Af update failed!');
                    end
                    
                    % Updates
                    uv_tilde = uv + alpha*wv;
                    gamma = gx(nv,:);
                    mu = (gamma - r'*uv_tilde)/rau;
                    uv_bar = [uv_tilde;mu];
                    vl_barv = P'*[vl;mu];
                    vl_bar = vl_barv(1:ml,:);
                    v = vl_barv(ml+1,:);
                    wv_bar = [(1-alpha)*wv;0]-v*z_bar;
                    % Update
                    uv = uv_bar;
                    vl = vl_bar;
                    wv = wv_bar;
                    pvStar = linsolve(Rv,wv);
                    p = [pvStar;zeros(nf,1)];
                    p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
                end               
                
            else
                %% Delete a general constraint
                [~,index] = min(lambdal);                
                % ���ָ��·�������ΪAv�ǶԻ�����������Ӱ��������
                % wl(index) = wl(ml);
                % wl(ml) = [];
                % ���ָ��·�����ΪAv�ĺ�����Ҳ���ܵ�Ӱ��
                wl(index) = [];                
                ml = ml - 1;
                if ml == 0          % There will be no general constraints in the working set
                    if (~isempty(wl))
                        error('Working set error!');
                    end
                    Av = [];
                    Af = [];
                    wl = [];
                    Yv = [];
                    Lv = [];
                    A = [];
                    pvStar = linsolve(Hv,-gv);
                    p = [pvStar;zeros(nf,1)];
                    p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
                else                % Related matrices need to be update
                    % ������ʵ����Ҫ��Av�ķֽ⣬Ҳ����Lv��Yv���и��£���Ϊ���ǽ�Av�е�index��һ�зŵ������һ�У������ж�˳�����϶���һ��
                    tmpS = Lv;
                    tmpS(ml+1,:) = Lv(index,:);        % Here use ml+1 because ml has been updated
                    tmpS(index:ml,:) = Lv(index+1:ml+1,:);
                    Stmp = tmpS;
                    % S*Yv'         % To check the rightness of S
                    P = eye(ml+1,ml+1);
                    for i = 0:ml+1 - index -1
                        [G,y] = planerot([Stmp(index+i,index+i);Stmp(index+i,index+1+i)]);
                        tempP = formRot(G,index+i,index+1+i,ml+1);
                        Stmp = (tempP*Stmp')';
                        %tempP*S'   % To check the rightness of tempP
                        P = tempP*P;
                    end
                    % S*P'          % To check whether equals L_tilda
                    Lv_tilde = tmpS*P';
                    Lv_bar = Lv_tilde(1:ml,1:ml);   % Lv_bar ����Ӧ���Ѿ���ԭ��һ����������
                    YP = Yv*P';     % Some problmes about the transpose!!!;����ط���Ҫ������ʱ�ٲ���һ��
                    Yv_bar = YP(:,1:ml);            % Yv_bar ����Ӧ���Ծ���һ��������
                    z_bar = YP(:,ml+1);
                    uv_bar = uv + alpha * wv;
                    tmpvl = P*vl;
                    vl_bar = tmpvl(1:ml,:);
                    v = tmpvl(ml+1,:);
                    wv_bar = (1-alpha)*wv - v*z_bar;                                                          
                    % Update
                    Lv = Lv_bar;
                    Yv = Yv_bar;
                    uv = uv_bar;
                    vl = vl_bar;
                    wv = wv_bar;
                    % Update Av and Af
                    Av(index,:) = [];
                    Af(index,:) = [];                    
                    A(index,:) = [];            %  ������²���Ҫ��ֻ�������ں���У��Af��
                    
                    % �����Af�ĸ��½���У��
                    recoA = [Av,Af];
                    if max(max(abs(A-recoA))) > 0.0000001
                        error('Af update failed!');
                    end
                    
                    % Check
                    if max(max(abs(Av-Lv*Yv'*Rv))) > 0.0000001
                        error('Av or Lv update fails');
                    end
                    % Compute p for the next iteration
                    pvStar = linsolve(Rv,wv);
                    p = [pvStar;zeros(nf,1)];
                    p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
                end
                
            end
        end
        
    else
        %% Calculate alpha
        % Note that here I did not keep the active constaint out for convenience
        alpha = 1;
        addBoundConstraint = 0;
        addGeneralConstraint = 0;   % ��������û�а���working set���Լ�����ų�
        for i = 1:nbc       % ������ͨ�����β���ķ���ȷ��һ�����ʵ�alphaֵ
            if p(i) < 0
                tmpAlpha = (lub(i)-x(i))/p(i);
                if tmpAlpha < alpha
                    alpha = tmpAlpha;
                    addBoundConstraint = 1;
                    boundIndex = i;
                end
            end
        end
        for i = nbc+1 : nbc*2
            if p(i-nbc) > 0
                tmpAlpha = (lub(i)-x(i-nbc))/p(i-nbc);
                if tmpAlpha < alpha
                    alpha = tmpAlpha;
                    addBoundConstraint = 1;
                    boundIndex = i;
                end
            end
        end
        
        for i = 1:ngc
            if (AA(i,:)*p < -0.000000001)
                tmpAlpha = (lg(i)-AA(i,:)*x)/(AA(i,:)*p);
                if (tmpAlpha < -0.0000001)
                    error('alpha less than zero!');
                end
                if (tmpAlpha < alpha)
                    alpha = tmpAlpha;
                    addGeneralConstraint = 1;
                    addBoundConstraint = 0;
                    generalIndex = i;
                end
            end
        end
        
        alpha = max([0,min([1,alpha])]);
        x = x + alpha * p;
        gx = PiGlobal*(c_ori + H_ori*x);
        gv = gx(1:nv,:);
        gf = gx(nv+1:ndec);
        
        % ���������ָ���gv��gf�ķ�������ʱ����ݼ�����ѡһ��
        
        % Second storage option to update gf;
        Hf = H(nv+1:ndec,nv+1:ndec);
        K = H(1:nv,nv+1:ndec);
        x_order = PiGlobal*x;
        xv = x_order(1:nv,:);
        xf = x_order(nv+1:ndec,:);
        m = Hf*xf+cf;
        gf_tilde = m+K'*xv;
        
        
        if (alpha < 1)
            if (addBoundConstraint == 1) && (addGeneralConstraint ==0)
                %% Adding a bound constraint
                wf = [boundIndex;wf];   % wf ��Լ��index��������Ҫע��
                % Other updates ...
                Pi = eye(nv,nv);                
                Pindec = eye(ndec,ndec);
                indexJ = mod(boundIndex,nbc);
                if indexJ == 0
                    indexJ = nbc;
                end                
                indexJ = find(order == indexJ);
                Pi(indexJ,indexJ) = 0;  Pindec(indexJ,indexJ) = 0;  
                Pi(nv,nv) = 0;          Pindec(nv,nv) = 0;
                Pi(indexJ,nv) = 1;      Pindec(indexJ,nv) = 1;
                Pi(nv,indexJ) = 1;      Pindec(nv,indexJ) = 1;
                order(1:nv,1) = Pi*order(1:nv,1);      % ����� Pi Ӧ�����𵽰�indexJ��λ���ϵı������������һλ������
                PiGlobal = Pindec*PiGlobal;
                %%----------------------Test Code--------------------------
                if PiGlobal'*order ~= origin
                    error('Permute record error!')
                end
                %%---------------------------------------------------------
                tmpS = Rv*Pi;              % Rv �������������󣬱� Pi ��λ֮����Ҫ�� Q �����ָ��������ǵ���ʽ
                Q = eye(nv,nv);
                for i = 1:nv-indexJ-1
                    [G,y] = planerot([tmpS(nv,indexJ);tmpS(nv-i,indexJ)]);
                    tempQ = formRot(G,nv,nv-i,nv);
                    %tempP*S'   % To check the rightness of tempP
                    tmpS = tempQ*tmpS;
                    Q = tempQ*Q;
                end
                for i = 1: nv - indexJ               
                    [G,y] = planerot([tmpS(i+indexJ-1,i+indexJ-1);tmpS(nv,i+indexJ-1)]);
                    tempQ = formRot(G,i+indexJ-1,nv,nv);
                    tmpS = tempQ*tmpS;
                    Q = tempQ*Q;
                end
                %Q*Rv*Pi       % Check the rightness of the Q and Pi,here Q*Rv*Pi should be upper-triangular matrix
                % ����� Q*Rv*Pi Ӧ���ܽ�Rv*Pi�ָ����ϣ��£�������
                Rv_hat = Q*Rv*Pi;
                % Updates
                % ��Ҫ���������һ�� H, cv, gv;                
                PiHvPi = Pi'*Hv*Pi;     % PiHvPi Ӧ���ǽ� indexJ ������Ľ��
                K = H(1:nv,nv+1:ndec);
                PiK = Pi*K;
                Hf = H(nv+1:ndec,nv+1:ndec);
                H = [PiHvPi,PiK;PiK',Hf];
                K = H(1:nv-1,nv:ndec);
                Hf = H(nv:ndec,nv:ndec);                     
                Hv = PiHvPi(1:nv-1,1:nv-1);
                Rv = Rv_hat(1:nv-1,1:nv-1);      
                
                % �����A����һ������֤����Af�ĸ��¶Բ���
                if ~isempty(A)
                    A = A*Pindec;
                end
            
                
                
                %%----------------------Test Code--------------------------
                if (origin'*H_ori*origin-order'*H*order) > 0.0000001
                    error('Permute on Hv failed!')
                end
                if max(max(abs(Rv-chol(Hv)))) >0.0000001
                    error('Rv is not the cholesky factorization of Hv?')
                end
                %%---------------------------------------------------------
                cv = Pi*cv;
                c = [cv;cf];
                cv = c(1:nv-1);
                cf = c(nv:ndec);                
                gv = Pi*gv;
                gx = [gv;gf];
                gv = gx(1:nv-1,:);
                gf = gx(nv:ndec);
                % Q: �����ǲ���Ӧ�ð� x �Ͷ�Ӧ��Լ������AAɶ��Ҳ permute һ��
                % A: ��ʱ�����ǣ���Ϊ�ڿ��� x ��Ӧ��Լ����ʱ���ǻ�� x ������ԭʼ��˳��������          
                nv = nv-1;
                nf = nf+1;
                
                % Second storage option to update gf;
                x_order = PiGlobal*x;
                xv = x_order(1:nv,:);
                xf = x_order(nv+1:ndec,:);
                m = Hf*xf+cf;
                gf_tilde = m+K'*xv;
                
                if ml == 0      % Situation that there is no general constraint in the working set.
                    %%----------------------Test Code----------------------
                    if (~isempty(Yv) || ~isempty(Lv))
                        error('Yv and Lv should be empty.');
                    end
                    %%-----------------------------------------------------
                    pvStar = linsolve(Hv,-gv);                  
                    p = [pvStar;zeros(nf,1)];
                    p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
                else
                    QYv = Q*Yv;
                    Y_tilde = QYv(1:nv,:);   % nv has been updated before
                    y_tilde = QYv(nv+1,:)';
                    tau = (1-y_tilde'*y_tilde)^(-1/2);
                    z = [-tau*Y_tilde*y_tilde;1/tau];
                    P = eye(ml+1,ml+1);
                    if ml > nv
                        error('Unsolvable.');
                    end
                    QYzTrans = ([QYv,z])';
                    LvTmp = [Lv,zeros(ml,1)];
                    AvTmp = LvTmp*QYzTrans*Rv_hat;
                    a = AvTmp(:,nv+1);
                    Af = [a,Af];
                    for i = 1:ml
                        % �������һ������� plane rotation �ķ���
                        [G,y] = planerot([QYzTrans(ml+1,nv+1);QYzTrans(ml+1-i,nv+1)]);
                        tmpP = formRot(G,ml+1,ml+1-i,ml+1);
                        QYzTrans = tmpP*QYzTrans;
                        P = tmpP*P;
                    end                    
                    P = P';
                    QYP = [QYv,z]*P;       % !! Here QYP should has the form of (4.4)
                    z = Q'*z;
                    Yv_bar = QYP(1:nv,1:ml);
                    LvP = [Lv,zeros(ml,1)]*P;
                    Lv_bar = LvP(:,1:ml);   % Here we can check the rightness of Av_bar = Lv_bar*Yv_bar'*Rv_bar;
                    % Update
                    Yv = Yv_bar;
                    Lv = Lv_bar;
                    Av = Lv*Yv'*Rv;
                    uv_baromega = Q*(uv+alpha*wv);
                    uv_bar = uv_baromega(1:nv,:);
                    v = (1-alpha)*z'*uv;
                    vl_baromega = P'*[vl;v];
                    vl_bar = vl_baromega(1:ml,:);
                    wv_barzero = Q*((1-alpha)*wv+v*z);
                    wv_bar = wv_barzero(1:nv,:);
                    % Update
                    uv = uv_bar;
                    vl = vl_bar;
                    wv = wv_bar;
                    
                    % �����Af�ĸ��½���У��
                    recoA = [Av,Af];
                    if max(max(abs(A-recoA))) > 0.0000001
                        error('Af update failed!');
                    end
                    
                    
                    % Compute p for the next iteration
                    pvStar = linsolve(Rv,wv);                   
                    p = [pvStar;zeros(nf,1)];                  
                    p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
                end                                
            elseif (addBoundConstraint == 0) && (addGeneralConstraint ==1)
                %% Adding a general constraint
                wl = [wl;generalIndex];
                ml = ml + 1;
                % Other updates ...
                a = PiGlobal*AA(generalIndex,:)';    % row a' is added
                invRv = inv(Rv);
                if (ml == 1)    % general constraint added to empty A
                    A = (a)';
                    Av = A(1,1:nv);
                    Af = A(1,nv+1:ndec);                    
                    AinvR = Av*invRv;
                    [Qtmp,Rtmp] = qr(AinvR');   % To achieve WGS factorization
                    Yv = Qtmp(:,1:ml);
                    Lv = Rtmp(1:ml,:)';
                    uv = linsolve(Rv',gv);
                    vl = Yv'*uv;
                    wv = Yv*vl-uv;
                else            % general constraint added to nonempty A
                    %a = (a'*invRv)';
                    q = linsolve(Rv',a(1:nv));                    
                    z_unnomalized = (eye(nv,nv)-Yv*Yv')*q;                    
                    tau = (1/(z_unnomalized'*z_unnomalized))^(1/2);    % The choice of tau is of no reference                    
                    z = tau*(eye(nv,nv)-Yv*Yv')*q;
                    Yv_bar = [Yv,z];
                    l = Yv'*q; 
                    gamma = z'*q;
                    Lv_bar = [Lv,zeros(ml-1,1);l',gamma];
                    %Lv_bar*Yv_bar' % For check
                    uv_bar = uv + alpha*wv;
                    v = (1-alpha)*z'*uv;
                    vl_bar = [vl;v];
                    wv_bar = (1-alpha)*wv+v*z;
                    % Update of Av and Af
                    A = [A;a'];
                    Av = [Av;a(1:nv)'];
                    Af = [Af;a(nv+1:ndec)'];                   
                    
                    % �����Af�ĸ��½���У��
                    recoA = [Av,Af];               
                    if max(max(abs(A-recoA))) > 0.0000001
                        error('Af update failed!');
                    end
                    
                    
                    % Update
                    Yv = Yv_bar;
                    Lv = Lv_bar;
                    uv = uv_bar;
                    vl = vl_bar;
                    wv = wv_bar;
                    % Check
                    if max(max(Av-Lv*Yv'*Rv))>0.000001
                        error('Av or Lv update fails');
                    end
                end
                % Compute p for the next iteration
                pvStar = linsolve(Rv,wv);
                p = [pvStar;zeros(nf,1)];
                p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
                
            else
                error('Add constraint error!');
            end
        else    % �� alpha == 1 ʱ������ working set ���������һ�� p
            if ml == 0
                %%----------------------Test Code----------------------
                if (~isempty(Yv) || ~isempty(Lv))
                    error('Yv and Lv should be empty.');
                end
                %%-----------------------------------------------------
                pvStar = linsolve(Hv,-gv);
                p = [pvStar;zeros(nf,1)];
                p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
            else                
                % ��ʱ��Ȼ Lv �� Yv û�䣬��gv �����˱仯�����Ҫ���� u��v �� w
                uv = linsolve(Rv',gv);
                vl = Yv'*uv;
                wv = Yv*vl-uv;
                pvStar = linsolve(Rv,wv);
                p = [pvStar;zeros(nf,1)];
                p = PiGlobal' * p;        % ���������� p �ָ����ܺ� origin ��Ӧ�����ķ���
            end
        end
    end
    
    
end
%end