use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'diffBackup',
    AUTHOR              => q{"mucha" <"">},
    VERSION_FROM        => 'lib/diffBackup.pm',
    ABSTRACT_FROM       => 'lib/diffBackup.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'diffBackup-*' },
);
