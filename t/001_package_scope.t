#!/usr/bin/perl

use strict;
use warnings;
use Test::More 'no_plan';

{
    package Foo;
    use Devel::System::Trace;
    no Devel::System::Trace;

    package Baz;
    
    use Devel::System::Trace 
        logfile => 'log.txt', verbose => 0;

    system('./t/helloworld.pl');

    package Bar;
    use Devel::System::Trace 
        logfile => 'log2.txt', dry_run => 1, verbose => 0;
    system('./t/helloworld.pl');
}

my @buf;
open FIC, 'log.txt' or die $!;
@buf = <FIC>;
close FIC;

my @expected = ("./t/helloworld.pl\n",
                "STDOUT:\n" => "Hello World!\n", 
                "STDERR:\n" => "Hey! at ./t/helloworld.pl line 4.\n");
is_deeply(\@buf, \@expected, 'Baz logfile looks good');
unlink 'log.txt';

open FIC, 'log2.txt' or die $!;
@buf = <FIC>;
close FIC;

@expected = ("./t/helloworld.pl\n", "STDOUT:\n", "STDERR:\n");
is_deeply(\@buf, \@expected, 'Bar logfile looks good');
unlink 'log2.txt';

