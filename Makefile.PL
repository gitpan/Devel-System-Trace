use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'Devel::System::Trace',
    VERSION_FROM => 'lib/Devel/System/Trace.pm',
    PREREQ_PM => {
    },
    ABSTRACT => 'Pragma for tracing system() calls.',
    test => {TESTS => join( ' ', glob( 't/*.t' ))},
)
