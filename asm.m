% һ��Practical��ASM�������ڱȽϺͲ���
% ������磺z = 1/2x'Gx + c'x, s.t. Ax>b������

% 2014.12.6
% ��һ

% Input:
% G: QP�������
% c: QP�������
% A: QP�������(Լ������ϵ����
% b: QP�������(Լ������ϵ����
% x: ASM��ʼ��(���е�)
% w����ʼ���Ӧ�Ļ���Լ������ʼWork Set��

% Output:
% xStar: ���õ������ŵ�
% zStar: ���ŵ��Ӧ��Ŀ�꺯��
% iterStar: ASM�ĵ�������

function [xStar, zStar, iterStar, finalAS, failFlag] = asm(G,invG,c,A,b,x,w,maxIter) 


[mc,ndec] = size(A);
iterStar = 0;
failFlag = 0;

% Give Warrings if the initial point is infeasible!
if min(A*x-b) < -1e-6
   error('Infeasible initial point!'); 
   %display('Infeasible initial point!');
   %return;
end


for i = 1:maxIter
    if i == maxIter
        failFlag = 1;
        disp('maxIter reached!');
        xStar = zeros(ndec,1);
        finalAS = [];
        %error('maxIter reached!');
    end
        
    
    iterStar = iterStar + 1;
    g = G*x+c;
    
    % ����w׼��A��b
    % ÿ�����ڵ�setSize����Ҫ
    setSize = length(w);
    Aw = zeros(setSize,ndec);
    bw = zeros(setSize,1);
   for j = 1:setSize
      Aw(j,:)  = A(w(j),:);
   end
   
   % ����ʽԼ������
   if setSize == ndec
       p = zeros(ndec,1);
   else
       [p, ~, ~] = eqp(G,invG,g,Aw,bw,zeros(ndec,1),setSize);
   end
    
   
   if (isZero(p,1e-4) == 1)  % ע�������p��������ĸ�����������������p�Ƿ����0ֱ���ж�
       % lambda = (G*x+c)./Aw(); 
       lambda = linsolve(Aw',g);    % ������������һ����������Ⱑ����
       if max(isnan(lambda)) == 1
           disp('Equation solve fails,try resolve.');
           %error('Equation solve fails,try resolve.');
           % ���ﳢ��һ�������Խ���Ԫ�صķ���
           [rAw,cAw] = size(Aw);
           lambda = linsolve((Aw+0.001*eye(rAw,cAw))',g);
           if max(isnan(lambda)) == 1
               error('Resolve fails.');
           end
           %error('Equation solve fails');
       end
       if (setSize == 0 || min(lambda) >= 0)
           xStar = x;
           finalAS = w;
           if ~isempty(w)
               disp('Not empty optimal active set.');
           end
           break;
       else
           [~,index] = min(lambda);
           w(index) = [];   % Matlab�ж�̬ɾ����һ���е�����
       end
   else
       notW = w2notW(w,mc);
       Anotw = zeros(mc-setSize,ndec);
       bnotw = zeros(mc-setSize,1);
       for j = 1:mc-setSize
           Anotw(j,:)  = A(notW(j),:);
           bnotw(j) = b(notW(j));
       end
       
       % ����alpha
       %numAlpha = 0;
       hasFirst = 0;
       %minAlpha = 1;
       for j = 1:mc-setSize
           ap = Anotw(j,:)*p; 
           if (ap < 0)
              if (hasFirst == 0)
                  minAlpha = (bnotw(j)-Anotw(j,:)*x)/ap;
                  indexMin = j;
                  hasFirst = 1;
              else
                  tmpAlpha = (bnotw(j)-Anotw(j,:)*x)/ap;                                    
                  
                  if (tmpAlpha < minAlpha)
                      minAlpha = tmpAlpha;
                      indexMin = j;
                  end
              end              
           end
       end
       alpha = min([1,minAlpha]);
       x = x + alpha * p;
       if (alpha < 1)
           tmpW = w;
           w = zeros(setSize+1,1);
           w(1:setSize) = tmpW;
           w(setSize+1) = notW(indexMin);
       end
   end
end

zStar = 1/2*xStar'*G*xStar + c'*xStar;
end