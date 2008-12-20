#use 5.010000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
%_ = (    NAME              => 'Net::DirectConnect',
    VERSION_FROM      => 'lib/Net/DirectConnect.pm', # finds $VERSION
    INSTALLDIRS => 'site',
#    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
#    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
#      (ABSTRACT_FROM  => 'lib/Net/DirectConnect.pm', # retrieve abstract from module
#       AUTHOR         => 'A. U. Thor <a.u.thor@a.galaxy.far.far.away>') : ()    ),

);

WriteMakefile(
%_
);

sub MY::postamble { qq{

docs : README

README: $_{VERSION_FROM}
	pod2text $_{VERSION_FROM} > README
	}
		}
