% ���һ���жϸ����������Ƿ�Ϊ0�ĺ���
% ������x�е�ÿһ�С����ֵtheta����Ϊ����������xΪ0
% ��һ
% 2014.12.8



function flag = isZero(x,theta)
flag = 1;

for i = 1:length(x)
   if (abs(x(i)) > theta) 
       flag = 0;
       break;
   end
end

end