use 5.006000;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Net::DirectConnect::TigerHash',
    VERSION_FROM      => 'lib/Net/DirectConnect/TigerHash.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Net/DirectConnect/TigerHash.pm', # retrieve abstract from module
       AUTHOR         => 'Charlie & <proler@gmail.com>') : ()),
    LIBS              => [''], # e.g., '-lm'
    DEFINE            => '-I./linuxdcpp/ -I../linuxdcpp/', # e.g., '-DHAVE_SOMETHING'
	# Insert -I. if you add *.h files later:
    INC               => '-I.', # e.g., '-I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
    'CC'                => 'g++',
    'LD'                => '$(CC)',
);
