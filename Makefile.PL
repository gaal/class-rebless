use ExtUtils::MakeMaker;

require 5.00502;

WriteMakefile(
    NAME                => 'Class::Rebless',
    VERSION_FROM        => 'lib/Class/Rebless.pm',
    PREREQ_PM           => { 'Scalar::Util' => '1.01', },
);
