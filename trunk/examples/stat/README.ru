��� ���?
��� ��� ����� ���������� � ���������� DC �����

���������:

���������� ������:
cpan DBI Bundle::DBD::mysql DBD::SQLite
win: ����� ppm

��������� ������ �� svn:
svn co svn://svn.setun.net/dcppp/trunk/ dcppp
��� � ��������� ����� ������ ����� 
http://search.cpan.org/dist/Net-DirectConnect/

���� � examples/stat

����������� config.pl.dist � config.pl 
��������������� config.pl
 �������� �������� sqlite ������ mysql
 ����� �������������� ����� ��������� ��������� � stat.cgi dcstat.conf stat.pl statlib.pm

��������� �������� 
 perl stat.pl dc.hub.ru dc.hub.com:41111 1.2.3.4

���������� ���������� ��������
 perl stat.cgi > stat.html

���������� �������� � �����
 �������� ��� dcstat.conf
 ��� �������� � htdocs
 �� ������ ��������� ������ ���� � ������� ��� ���� ���� sqlite

������������.



====
freebsd:
cd /usr/ports/devel/subversion && make install clean
cd /usr/local/www && svn co svn://svn.setun.net/dcppp/trunk/examples/stat dcstat
cd /usr/local/www/dcstat && svn co svn://svn.setun.net/dcppp/trunk/lib/Net

cd /usr/ports/databases/p5-DBD-mysql && make install clean
cd /usr/ports/www/apache22 && make install clean
cd /usr/local/www/dcstat
cp config.pl.dist config.pl
ee config.pl
ln -s dcstat.conf /usr/local/etc/apache22/Includes/
echo 'apache22_enable="YES"' >> /etc/rc.conf.local
/usr/local/etc/rc.d/apache22 restart
perl stat.pl dc.hub.ru otherhub.com:4111
http://localhost/dcstat
