
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
freebsd
cd /usr/ports/devel/subversion && make install clean
cd /usr/local/www && svn co svn://svn.setun.net/dcppp/trunk/examples/stat dcstat
cd /usr/ports/databases/p5-DBD-mysql && make install clean
cd /usr/local/www/dcstat
cp config.pl.dist config.pl
ee config.pl
