use strict;
use warnings;
use File::Basename;
use File::Compare;
use File::Spec;
use File::Slurp;
use Cwd qw(abs_path);
use lib dirname(dirname(dirname(dirname(abs_path($0)))));
my $clear = 0;
my @tests;
BEGIN {
    #register tests
    push @tests, map {run => \&run_parser_test, file => $_} => <parser/*.fd>;
    push @tests, map {
        run => \&run_validator_test,
        file => $_,
        prepare => \&prepare_testlib_validator,
        validate => \&testlib_validate,
        name => 'testlib'
    } => <validator/*.fd>;
    push @tests, map {
        run => \&run_validator_test,
        file => $_,
        prepare => \&prepare_universal_validator,
        validate => \&universal_validate,
        name => 'universal'
    } => <validator/*.fd>;
}

use Test::More tests => 2 + scalar @tests;
my @suffix_to_save = qw(.fd .in .ans);

sub compare_files_ok {
    my ($file1, $file2, $comment) = @_;
    ok(compare($file1, $file2) == 0, $comment);
}

sub in {
    my ($e, @a) = @_;
    for (@a){
        return 1 if $e eq $_;
    }
    return 0;
}

sub clear {
    my ($dir) = @_;
    if ($clear) {
        print "cleaning directory $dir...\n";
        my @exclude = ("$dir/testlib.h", map <$dir/*$_> => @suffix_to_save);
        my @all = grep !in($_, @exclude) => <$dir/*>;
        unlink @all;
    }
}

sub prepare_testlib_validator {
    my ($file) = @_;
    my ($name, $dir, $suffix) = fileparse($file, '.fd');
    CATS::Formal::Formal::generate_and_write(
        {'INPUT' => $file}, 'testlib_validator', "$dir$name.cpp"
    );
    my $compile =
        "g++ -enable-auto-import -o $dir$name.exe $dir$name.cpp";
    print "compiling... $file -> testlib\n";
    system($compile);
    if ($? >> 8) {
        fail("$file - not compiled -> testlib");
        return ;
    }
    return "$dir$name.exe";
}

sub testlib_validate {
    my ($test_file, $executable) = @_;
    $executable = File::Spec->canonpath($executable);
    $test_file = File::Spec->canonpath($test_file);
    return `$executable < $test_file 2>&1`;
}

sub prepare_universal_validator {
    return {
        INPUT => $_[0]
    };
}

sub universal_validate {
    my ($test_file, $from) = @_;
    return CATS::Formal::Formal::validate($from, {INPUT => $test_file});
}

sub run_parser_test {
    my ($test_obj) = @_;
    my $file = $test_obj->{file};
    my ($name, $dir, $suffix) = fileparse($file, '.fd');
    CATS::Formal::Formal::generate_and_write(
        {'INPUT' => $file}, 'xml', "$dir$name.out"
    );
    compare_files_ok("$dir$name.ans", "$dir$name.out", $file);
}

sub run_validator_test {
    my ($test_obj) = @_;
    my $file = $test_obj->{file};
    my $prepare = $test_obj->{prepare};
    my $validate = $test_obj->{validate};
    my $validator_name = $test_obj->{name};
    my ($name, $dir, $suffix) = fileparse($file, '.fd');
    my $prepared = $prepare->($file) || return;
    my @sub_tests = <$dir$name.*.in>;
    subtest $file => sub {
        plan tests => scalar @sub_tests;
        for my $st (@sub_tests) {
            my $in_name = $dir . basename($st, '.in');
            $in_name =~ /.*(fail|ok)\.\d+$/;
            my $should_be_ok = $1 eq 'ok';
            my $output = $validate->($st, $prepared) || '';
            my $res = $output && !$should_be_ok || !$output && $should_be_ok;
            write_file("$in_name.$validator_name.out", $output);
            ok($res, "$st - $validator_name");
        }
    }
}

sub run_validator_tests{
    my ($validator_id, $prepare, $validate, @validator_tests) = @_;
    for my $file (@validator_tests) {
        my ($name, $dir, $suffix) = fileparse($file, '.fd');
        my $prepared = $prepare->($file) || return;
        my @sub_tests = <$dir$name.*.in>;
        subtest $file => sub {
            for my $st (@sub_tests) {
                my $in_name = $dir . basename($st, '.in');
                $in_name =~ /.*(fail|ok)\.\d+$/;
                my $should_be_ok = $1 eq 'ok';
                my $output = $validate->($st, $prepared) || '';
                my $res = $output && !$should_be_ok || !$output && $should_be_ok;
                write_file("$in_name.$validator_id.out", $output);
                ok($res, "$st - $validator_id");
            }
        }
    }
}

BEGIN {use_ok('CATS::Formal::Formal')};
require_ok('CATS::Formal::Formal');

$_->{run}->($_) for @tests;

clear('parser');
clear('validator');

1;
