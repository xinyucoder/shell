#!/bin/bash
#运行命令(yum -y install wget;wget 地址/start.sh -O start.sh;sh start.sh)
#此脚本一键安装Nginx1.18.0 PHP7.2 MySQL5.7
#URL为安装请求域名需加http或https结尾无/
function Install_exit(){
rm -rf *.sh *.zip *.gz *.rpm *repo *.tar nginx-1.18.0
}
function Install_finish(){
echo -e "\033[32m 脚本已安装完毕
您的API系统域名为:${sys_URL}
您的HTML前端域名为:${html_URL}
您的MySQL数据库密码为:${newpassword}
请妥善保管，谢谢！ \033[0m"
Install_exit
echo `date`
}
function Start(){
#安装PHP7.2
yum -y install wget
rm -rf /etc/yum.repos.d/*
wget -c ${URL}/yum/CentOS7-Base.repo -O /etc/yum.repos.d/CentOS-Base.repo
yum clean all
yum makecache
yum -y install epel-release
yum -y install zip unzip
yum remove php*
rpm -ivh https://mirrors.tuna.tsinghua.edu.cn/remi/enterprise/remi-release-7.rpm
rm -rf /etc/yum.repos.d/remi*
wget ${URL}/yum/remi.zip -O remi.zip
unzip remi.zip -d /etc/yum.repos.d/
yum clean all
yum makecache
yum -y install yum-utils
yum-config-manager --enable remi-php72
yum -y install php72 php72-php-common php72-php-fpm php72-php-cli php72-php-opcache php72-php-gd php72-php-mysqlnd php72-php-mbstring php72-php-pecl-redis php72-php-devel php72-php-recode php72-php-snmp php72-php-pecl-redis php72-php-sysvmsg php72-php-pcntl php72-php-mysqli php72-php-fileinfo
systemctl stop php72-php-fpm.service
sed -i "24c\user = nobody" /etc/opt/remi/php72/php-fpm.d/www.conf
sed -i "26c\group = nobody" /etc/opt/remi/php72/php-fpm.d/www.conf
mkdir -p /www/
chown -R nobody:nobody /www
chown -R nobody:nobody /var/opt/remi/php72/lib/php/session
systemctl start php72-php-fpm.service
systemctl enable php72-php-fpm.service
yum -y install redis
#更换yum为网易
#yum -y install wget
#rm -rf /etc/yum.repos.d/*
#wget -c ${URL}/yum/CentOS7-Base.repo -O /etc/yum.repos.d/CentOS-Base.repo
#yum clean all
#yum makecache
#yum -y install epel-release
#yum -y install zip unzip
#安装Nginx1.18.0
wget -c ${URL}/Nginx/nginx-1.18.0.tar.gz -O nginx-1.18.0.tar.gz
tar -zxvf nginx-1.18.0.tar.gz
yum install -y gcc-c++ 
yum install -y pcre pcre-devel 
yum install -y zlib zlib-devel 
yum install -y openssl openssl-devel
mkdir -p /var/temp/nginx
cd nginx-1.18.0/
./configure \
--prefix=/usr/local/nginx \
--pid-path=/var/run/nginx.pid \
--lock-path=/var/lock/nginx.lock \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--with-http_gzip_static_module \
--http-client-body-temp-path=/var/temp/nginx/client \
--http-proxy-temp-path=/var/temp/nginx/proxy \
--http-fastcgi-temp-path=/var/temp/nginx/fastcgi \
--http-uwsgi-temp-path=/var/temp/nginx/uwsgi \
--http-scgi-temp-path=/var/temp/nginx/scgi
make
make install
cd /usr/local/nginx/sbin
./nginx
ps -ef | grep nginx
cp /usr/local/nginx/sbin/nginx /bin/
wget -c ${URL}/Nginx/nginx.service -O /usr/lib/systemd/system/nginx.service
#开放80端口
	firewall-cmd --zone=public --add-port=80/tcp --permanent
	firewall-cmd --zone=public --add-port=80/udp --permanent
	firewall-cmd --zone=public --add-port=443/tcp --permanent
	firewall-cmd --zone=public --add-port=443/udp --permanent
	firewall-cmd --reload  # 配置立即生效
nginx -s stop
chown -R nobody:nobody /var/log/nginx
nginx
systemctl enable nginx
systemctl daemon-reload
#安装MySQL5.7
wget -c ${URL}/yum/mysql57-community-release-el7-8.noarch.rpm -O mysql57-community-release-el7-8.noarch.rpm
rpm -ivh /root/mysql57-community-release-el7-8.noarch.rpm --nodeps --force
rm -rf /etc/yum.repos.d/mysql-community.repo
rm -rf /etc/yum.repos.d/mysql-community-source.repo
wget ${URL}/yum/mysql-community.repo -O /etc/yum.repos.d/mysql-community.repo
wget ${URL}/yum/mysql-community-source.repo -O /etc/yum.repos.d/mysql-community-source.repo
yum -y remove mysql-libs mariadb-libs
yum -y install libaio
yum -y install mysql-community-common mysql-community-libs mysql-community-client mysql-community-server
/usr/sbin/setenforce 0
systemctl start mysqld
systemctl enable mysqld
systemctl daemon-reload
#pass=$(grep 'temporary password' /var/log/mysqld.log)
#password=${pass:90:999}
#更改MySQL密码
systemctl stop mysqld
wget ${URL}/MySQL/my.cnf1 -O /etc/my.cnf
systemctl start mysqld
mysql <<EOF
	use mysql
	UPDATE user SET authentication_string=PASSWORD("88888888") WHERE user='root';
	UPDATE user SET password=PASSWORD("88888888") WHERE user='root';
EOF
systemctl stop mysqld
wget ${URL}/MySQL/my.cnf2 -O /etc/my.cnf
systemctl start mysqld
mysql -uroot -p88888888 <<EOF
	set global validate_password_policy=0;
	set global validate_password_length=1;
	set password = password("${newpassword}");
	alter user 'root'@'localhost' password expire never;
	flush privileges;
EOF
echo "您的MySQL数据库密码为${newpassword}"
#自动配置API系统及前端系统
nginx -s stop
sed -i '2a\user nobody;' /usr/local/nginx/conf/nginx.conf
sed -i '33a\    include /usr/local/nginx/conf.d/*.conf;' /usr/local/nginx/conf/nginx.conf
nginx
mkdir -p /usr/local/nginx/conf.d
mkdir -p /www/wwwroot/${html_URL}
mkdir -p /www/wwwroot/${sys_URL}
wget ${URL}/Nginx/conf/html.conf -O /usr/local/nginx/conf.d/${html_URL}.conf
sed -i "3c\    server_name  ${html_URL};" /usr/local/nginx/conf.d/${html_URL}.conf
sed -i "4c\    root         /www/wwwroot/${html_URL};" /usr/local/nginx/conf.d/${html_URL}.conf
sed -i "21c\       root   /www/wwwroot/${html_URL};" /usr/local/nginx/conf.d/${html_URL}.conf
wget ${URL}/Nginx/conf/sys.conf -O /usr/local/nginx/conf.d/${sys_URL}.conf
sed -i "3c\    server_name  ${sys_URL};" /usr/local/nginx/conf.d/${sys_URL}.conf
sed -i "4c\    root         /www/wwwroot/${sys_URL}/public;" /usr/local/nginx/conf.d/${sys_URL}.conf
sed -i "14c\       root   /www/wwwroot/${sys_URL}/public;" /usr/local/nginx/conf.d/${sys_URL}.conf
nginx -s stop
nginx
wget ${URL}/web/html.zip -O /root/html.zip
unzip /root/html.zip -d /www/wwwroot/${html_URL}
wget ${URL}/web/sys.zip -O /root/sys.zip
unzip /root/sys.zip -d /www/wwwroot/${sys_URL}
Install_finish
}
function Second(){
clear
echo -e "\033[32m 欢迎使用*****一键脚本-自动安装进程即将开始
————————————————————————————————————————————————————
我们需要获取您的一些安装信息以保证程序可以正常运行 \033[0m"
read -p "请输入您的API系统域名并回车：" new1
export sys_URL="${new1}"
read -p "请输入您的HTML前端域名并回车：" new2
export html_URL="${new2}"
echo -n "请设置您的MySQL数据库密码(如不设置默认则为MySQL@.98K):"
	read mysql_p  
	if [[ $mysql_p == "" ]]
	 then 
		export newpassword="MySQL@.98K"
	 else
		export newpassword="${mysql_p}"
	fi
sleep 2
echo -e "\033[32m 好的，感谢您的配合，片刻后将进入自动配置阶段，运行完毕后会输出此次安装的信息，建议您截图保存 \033[0m"
sleep 5
Start
}
function First(){
clear
echo -e "\033[32m =========================================================================
                    【欢迎使用****一键脚本】
                    【交流群：****    联系QQ：*****】
                    【脚本官网：www.xxx.com】
                    【请使用Centos7.X 64bit系统进行安装】 
 请选择安装节点:
 1.大陆连接节点
 2.海外连接节点
 0.退出程序
PS:海内外连接节点仅仅是为了让安装达到最佳连接速度，请放心选择，均可正常使用此程序
by 联系QQ：*****
========================================================================= \033[0m"
read -p "请输入序号并回车:" mode
if [[ $mode == "0" ]]
	then 
	echo -e "退出程序：\033[32m退出\033[0m" ; 
	echo "程序正在退出...请稍后..." 
	Install_exit
	sleep 3	
	exit 
fi
if [[ $mode == "1" ]]
	then 
	echo -e "节点选择：\033[32m大陆节点\033[0m" ; 
	export URL="http://pan.itwuo.com/shell/lizong"
	Second
	sleep 1
fi
if [[ $mode == "2" ]]
	then 
	echo -e "节点选择：\033[32m海外节点\033[0m" ;  
	export URL="http://download.itwuo.com/shell/lizong"
	Second
	sleep 1
fi
}
First