package Devel::System::Trace;

use strict;
use warnings;
use vars qw($VERSION $AUTHORITY);
use File::Temp 'tempfile';

$VERSION   = '0.0.2';
$AUTHORITY = 'cpan:SUKRIA';

my $package = 'Devel::System::Trace';
my $options = {};

# public methods

sub import {
    my ($package, %opts) = @_;
    my $caller = caller();
    
    # supported options
    $options->{$caller}{logfile} = $opts{logfile};
    $options->{$caller}{verbose} = $opts{verbose};
    $options->{$caller}{dry_run} = $opts{dry_run};

    # prepare tempfiles for redirections
    my ($fh, $tempfile) = tempfile();
    undef $fh;
    $options->{$caller}{tmp_stdout} = $tempfile;
    ($fh, $tempfile) = tempfile();
    undef $fh;
    $options->{$caller}{tmp_stderr} = $tempfile;

    # call the appropriate import function according to Perl's version
    ($] >= 5.010)
        ? _import_for_5_10(@_)
        : _import_default(@_);

    # redefine the "system" keyword
    *CORE::GLOBAL::system = sub { _system(@_) };
}

# unimport the module, appropriately according to Perl's version
sub unimport { 
    ($] >= 5.010)
        ? _unimport_for_5_10(@_)
        : _unimport_default(@_);
}

# private stuff

# with Perl >= 5.10 we can save the state of the module, lexically
sub _import_for_5_10 { 
    $^H{$package} = 1; 
}

# with older Perl, we save the state with a per-package basis.
sub _import_default {
    my $caller = caller(1);
    $options->{$caller}{is_active} = 1;
}

sub _unimport_for_5_10 {
    undef $^H{$package};
}

sub _unimport_default {
    my $caller = caller(1);
    $options->{$caller}{is_active} = 0;
}

# for Perl 5.10 runtime pragmas
sub _is_active {
    # retreive the hinthash in Perl 5.10
    if ($] >= 5.010) {
        my $hinthash = (caller(2))[10];
        return $hinthash->{$package};
    }
    # is the package active for calling module? 
    else {
        my $caller = caller(2);
        return $options->{$caller}{is_active};
    }
}

sub _system {
    my (@args) = @_;
    my $caller = caller(1);
    my $res = 0;

    # if the module is unloaded, don't overload system()
    return CORE::system(@_) unless _is_active() ;

    # if nothing special needed, just pass the batton to CORE::system
    return CORE::system(@_) unless 
        $options->{$caller}{logfile} or 
        $options->{$caller}{verbose} or
        $options->{$caller}{dry_run};

    # else, let's wrap it!
    my $tmp_stdout = $options->{$caller}{tmp_stdout};
    my $tmp_stderr = $options->{$caller}{tmp_stderr};

    # saving STDOUT
    open my $stdout, ">&STDOUT" or die "Can't dup STDOUT: $!";
    open my $stderr, ">&STDERR" or die "Can't dup STDERR: $!";

    # redirecting STDOUT to $tempfile
    open   STDOUT, '>', $tmp_stdout;
    select STDOUT; $| = 1; # unbuffered
    
    open   STDERR, '>', $tmp_stderr;
    select STDERR; $| = 1; # unbuffered

    # calling the system call if not in dry_run mode
    $res = CORE::system(@args) unless $options->{$caller}{dry_run};
    
    # restoring old STDOUT & STDERR
    close STDOUT;
    close STDERR;
    
    open STDOUT, ">&", $stdout or die "Can't restore stdout: $!";
    open STDERR, ">&", $stderr or die "Can't restore stderr: $!";
    
    select STDERR;
    select STDOUT;

    # reading output
    open READFILE, $tmp_stdout;
    my @stdout = <READFILE>;
    close READFILE;
    open READFILE, $tmp_stderr;
    my @stderr = <READFILE>;
    close READFILE;

    unlink $tmp_stdout;
    unlink $tmp_stderr;

    # now, do what needed
    if ($options->{$caller}{verbose}) {
        print _format_output(join(" ", @args), join("\n", @stdout), join("\n", @stderr));
    }
    if ($options->{$caller}{logfile}) {
        open LOGFILE, '>>', $options->{$caller}{logfile} or 
            die "unable to open file ".$options->{$caller}{logfile}." for writing: $!";
        print LOGFILE _format_output(join(" ", @args), join("\n", @stdout), join("\n", @stderr));
        close LOGFILE;
    }

    return $res;
}

sub _format_output($$$)
{
    my ($cmd, $stdout, $stderr) = @_;
    my $str = "$cmd\n";

    if (defined $stdout) {
        $str .= "STDOUT:\n";
        $str .= "$stdout";
    }
    
    if (defined $stderr) {
        $str .= "STDERR:\n";
        $str .= "$stderr";
    }
    return $str;
}

1;
__END__
=pod

=head1 NAME

Devel::System::Trace

=head1 DESCRIPTION

This module is designed for tracing every call made to the system() command.
It can be useful if you want to track down what external calls are made in a
given script.

B<Under Perl 5.10>, this pragam is lexical, you can import it (use
Devel::System::Trace) and unimport it (no Devel::System::Trace) as many times
as you like, in lexical blocks ; it will works as expected.

B<Under older Perl interpreters>, the scope of the pragma is a package : you can
chose to import or unimport it in a package. But be aware that once a "no
Devel::System::Trace" is used, the pragma is disabled for the current package
for ever (and that means, from the begining of runtime).

=head1 CONFIGURATION

When using the pragma, you can choose to change the behaviour of any system()
calls made later inthe script.

    use Devel::System::Trace %options;

The following options are supported : 

=over 4

=item B<verbose => 1|0> : if set to true, commands, STDERR and STDOUT are grabbed, then
printed to stdout.

=item B<logfile> => 1|0 : if set to true, commands, STDERR and STDOUT are logged to the
given file.

=item B<dry_run> => 1|0 : if set to true, disable the calls to system.

=back

With no options given, the pragma is disabled : system() will behave unaltered.

=head1 EXAMPLES

    # redirecting every system() outputs to a logfile
    package Foo;
    use Devel::System::Trace logfile => './foo.log';
    ...

    # disabling system() calls and outputing to stdout the calls
    package Bar;
    use Devel::System::Trace dry_run => 1, 
                             verbose => 1;

=head1 AUTHOR

This module was written by Alexis Sukrieh E<lt>sukria+perl@sukria.netE<gt>.

Thanks to Raphaël Garcia Suarez for his quick help and suggestions for Perl
5.10 / 5.8 integration.

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Alexis Sukrieh.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
