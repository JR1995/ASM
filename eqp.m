% һ��Practical������ʽԼ����QP����ĳ�������Ϊÿ����ASM��������
% ������磺z = 1/2x'Gx + c'x, s.t. Ax=b������

% 2014.12.6
% ��һ

% Input:
% G:    QP�������
% invG: G������棬����Schur-Complement��������ⷽ����
% c:    QP�������
% A:    QP�������(Լ������ϵ����
% b:    QP�������(Լ������ϵ����

% Output:
% xStar: ���õ������ŵ�
% zStar: ���ŵ��Ӧ��Ŀ�꺯��
% iterStar: ASM�ĵ�������

% 2014.12.6 ����ͨ��

function [xStar, zStar, iterStar] = eqp(G,invG,c,A,b,x,consNum) 

iterStar = 0;

% ����ʽԼ�������˻�Ϊ��Լ��������ʱ
if (consNum == 0)
   xStar = -invG*c;
   %zStar = 0.5 * xStar'*G*xStar + c'*xStar
   zStar = -1;
   return
end


%L = chol(A*invG*A','lower');
%L = cf(A*invG*A');
%for i = 1:20


iterStar = iterStar + 1;
h = A*x-b;
g = c+G*x;
equation_b = A*invG*g-h;
%lambda = luEvaluate(L,L',equation_b);

lambda = linsolve(A*invG*A',equation_b);

p = invG * (A'*lambda - g);
x = x + p;




%     if (max([abs(p)]) < 1e-8)
%         break;
%     end
% end
    
xStar = x;
zStar = -1;
%zStar = 0.5 * xStar'*G*xStar + c'*xStar;

end