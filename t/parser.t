use strict;
use warnings;

use FindBin;
use Test::More tests => 18;
use Test::Exception;

use lib '..';
use lib $FindBin::Bin;

use CATS::Problem::Parser;
use ParserMockup;

sub parse { ParserMockup::make(@_)->parse }

sub wrap_xml { qq~<?xml version="1.0" encoding="Utf-8"?><CATS version="1.0">$_[0]</CATS>~ }

sub wrap_problem {
    wrap_xml(qq~
<Problem title="Title" lang="en" tlimit="5" mlimit="6" inputFile="input.txt" outputFile="output.txt">
$_[0]
</Problem>
~)
}

subtest 'trivial errors', sub {
    plan tests => 5;
    throws_ok { parse({ 'text.x' => 'zzz' }); } qr/xml not found/, 'no xml';
    throws_ok { parse({ 'text.xml' => 'zzz' }); } qr/error/, 'bad xml';
    throws_ok { parse({
        'text.xml' => '<?xml version="1.0" encoding="Utf-8"?><ZZZ/>',
    }); } qr/ZZZ/, 'no CATS 1';
    throws_ok { parse({
        'text.xml' => '<?xml version="1.0" encoding="Utf-8"?><Problem/>',
    }); } qr/Problem.+CATS/, 'no CATS 2';
    TODO: {
        local $TODO = 'Should validate on end_CATS, not end_Problem';
        throws_ok { parse({ 'text.xml' => wrap_xml('') }) } qr/error/, 'missing Problem';
    }
};

subtest 'header', sub {
    plan tests => 11;
    my $d = parse({
        'test.xml' => wrap_xml(q~
<Problem title="Title" lang="en" author="A. Uthor" tlimit="5" mlimit="6" wlimit="100B"
    saveOutputPrefix="100B" saveInputPrefix="200B" saveAnswerPrefix="300B" inputFile="input.txt" outputFile="output.txt">
<Checker src="checker.pp"/>
</Problem>~),
    'checker.pp' => 'begin end.',
    })->{description};
    is $d->{title}, 'Title', 'title';
    is $d->{author}, 'A. Uthor', 'author';
    is $d->{lang}, 'en', 'lang';
    is $d->{time_limit}, 5, 'time';
    is $d->{memory_limit}, 6, 'memory';
    is $d->{save_output_prefix}, 100, 'saveOutputPrefix';
    is $d->{save_input_prefix}, 200, 'saveInputPrefix';
    is $d->{save_answer_prefix}, 300, 'saveAnswerPrefix';
    is $d->{write_limit}, 100, 'write';
    is $d->{input_file}, 'input.txt', 'input';
    is $d->{output_file}, 'output.txt', 'output';
};

subtest 'missing', sub {
    plan tests => 5;
    throws_ok { parse({
        'test.xml' => wrap_xml(q~
<Problem title="Title" tlimit="5" mlimit="6" inputFile="input.txt" outputFile="output.txt"/>~),
    }) } qr/lang/, 'missing lang';
    throws_ok { parse({
        'test.xml' => wrap_xml(q~
<Problem title="Title" lang="en" mlimit="6" inputFile="input.txt" outputFile="output.txt"/>~),
    }) } qr/tlimit/, 'missing time limit';
    is parse({
        'test.xml' => wrap_xml(q~
<Problem title="Title" lang="en" tlimit="5" inputFile="input.txt" outputFile="output.txt">
<Checker src="checker.pp"/>
</Problem>~),
        'checker.pp' => 'begin end.',
    })->{description}->{memory_limit}, 200, 'default memory limit';
    throws_ok { parse({
        'test.xml' => wrap_xml(q~
<Problem title="Title" lang="en" tlimit="5" mlimit="6" inputFile="input.txt"/>~),
    }) } qr/outputFile/, 'missing output file';
    throws_ok { parse({
        'test.xml' => wrap_xml(q~
<Problem title="Title" lang="en" tlimit="5" mlimit="6" inputFile="input.txt" outputFile="output.txt"/>~),
    }) } qr/checker/, 'missing checker';
};

subtest 'rename', sub {
    plan tests => 2;
    throws_ok { parse({
        'test.xml' => wrap_xml(q~
<Problem title="New Title" lang="en" tlimit="5" mlimit="6" inputFile="input.txt" outputFile="output.txt"/>~),
    }, { old_title => 'Old Title' }) } qr/rename/, 'unexpected rename';
    is parse({
        'test.xml' => wrap_xml(q~
<Problem title="Old Title" lang="en" tlimit="5" mlimit="6" inputFile="input.txt" outputFile="output.txt">
<Checker src="checker.pp"/>
</Problem>~),
        'checker.pp' => 'begin end.',
    }, { old_title => 'Old Title' })->{description}->{title}, 'Old Title', 'expected rename';
};

subtest 'sources', sub {
    plan tests => 8;

    is parse({
        'test.xml' => wrap_problem(q~<Checker src="checker.pp"/>~),
        'checker.pp' => 'checker1',
    })->{checker}->{src}, 'checker1', 'checker';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Checker src="chk.pp"/>~),
    }) } qr/checker.*chk\.pp/, 'no checker';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Checker src="chk.pp"/>
<Checker src="chk.pp"/>
~),
        'chk.pp' => 'checker1',
    }) } qr/checker/, 'duplicate checker';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Solution/>~),
    }) } qr/Solution.src/, 'no solution src';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Solution src="zzz"/>~),
    }) } qr/Solution.name/, 'no solution nme';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Checker src="chk.pp"/>
<Solution name="sol1" src="sol"/>
~),
        'chk.pp' => 'checker1',
    }) } qr/sol/, 'missing solution';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Checker src="chk.pp"/>
<Solution name="sol1" src="chk.pp"/>
<Solution name="sol1" src="chk.pp"/>
~),
        'chk.pp' => 'checker1',
    }) } qr/sol1/, 'duplicate solution';

    my $sols = parse({
        'test.xml' => wrap_problem(q~
<Checker src="chk.pp"/>
<Solution name="sol1" src="chk.pp"/>
<Solution name="sol2" src="chk.pp"/>
~),
        'chk.pp' => 'checker1',
    })->{solutions};
    is_deeply [ map $_->{path}, @$sols ], [ 'chk.pp', 'chk.pp' ], 'two solutions';
};

subtest 'text', sub {
    plan tests => 11;
    my $p = parse({
        'test.xml' => wrap_problem(q~
<Checker src="checker.pp"/>
<ProblemStatement>problem
statement</ProblemStatement>
<ProblemConstraints>$N = 0$</ProblemConstraints>
<InputFormat>x, y, z</InputFormat>
<OutputFormat>single number</OutputFormat>
<Explanation>easy</Explanation>~),
        'checker.pp' => 'z',
    });
    is $p->{statement}, "problem\nstatement", 'statement';
    is $p->{constraints}, '$N = 0$', 'constraints';
    is $p->{input_format}, 'x, y, z', 'input';
    is $p->{output_format}, 'single number', 'output';
    is $p->{explanation}, 'easy', 'explanation';

    my $p1 = parse({
        'test.xml' => wrap_problem(q~
<Checker src="checker.pp"/>
<ProblemStatement>outside<b  class="  z  " > inside </b></ProblemStatement>
<ProblemConstraints>before<include src="incl"/>after</ProblemConstraints>~),
        'checker.pp' => 'z',
        'incl' => 'included'
    });
    is $p1->{statement}, 'outside<b class="  z  "> inside </b>', 'tag reconstruction';
    is $p1->{constraints}, 'beforeincludedafter', 'include';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<ZZZ></ZZZ>~),
    }) } qr/ZZZ/, 'unknown tag';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<ProblemStatement><include/></ProblemStatement>
<Checker src="checker.pp"/>~),
        'checker.pp' => 'z',
    }) } qr/include/, 'no incude src';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<ProblemStatement><include src="qqq"/></ProblemStatement>
<Checker src="checker.pp"/>~),
        'checker.pp' => 'z',
    }) } qr/qqq/, 'bad incude src';

    throws_ok { parse({
        'text.xml' => wrap_problem(q~
<ProblemStatement><ProblemConstraints></ProblemConstraints></ProblemStatement>~),
    }); } qr/Unexpected.*ProblemConstraints/, 'ProblemConstraints inside ProblemStatement';
};

subtest 'picture-attachment', sub {
    plan tests => 19;
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<ProblemStatement><img/></ProblemStatement>~),
    }) } qr/picture/i, 'img without picture';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<ProblemStatement><img picture="qqq"/></ProblemStatement>~),
    }) } qr/qqq/, 'img with bad picture';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<ProblemStatement><a attachment="zzz"/></ProblemStatement>~),
    }) } qr/zzz/, 'a with bad attachment';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<ProblemStatement><object attachment="zzz"/></ProblemStatement>~),
    }) } qr/zzz/, 'object with bad attachment';

    for my $tag (qw(Picture Attachment)) {
        throws_ok { parse({
            'test.xml' => wrap_problem(qq~<$tag/>~),
        }) } qr/src/, "$tag without src";

        throws_ok { parse({
            'test.xml' => wrap_problem(qq~<$tag src="test"/>~),
        }) } qr/name/, "$tag without name";

        throws_ok { parse({
            'test.xml' => wrap_problem(qq~<$tag src="xxxx" name="yyyy"/>~),
        }) } qr/xxxx/, "$tag with bad src";
    }

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Picture src="p1" name="p1" />~),
        'p1' => 'p1data',
    }) } qr/extension/, 'bad picture extension';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Attachment src="a1.txt" name="a1" />
<ProblemStatement><img picture="a1"/></ProblemStatement>
~),
        'a1.txt' => 'a1data',
    }) } qr/a1/, 'img references attachment';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Picture src="p1.txt" name="p1" />
<ProblemStatement><a attachment="p1"/></ProblemStatement>
~),
        'p1.txt' => 'p1data',
    }) } qr/p1/, 'a references picture';

    my $p = parse({
        'test.xml' => wrap_problem(q~
<Picture src="p1.img" name="p1" />
<Attachment src="a1.txt" name="a1" />
<ProblemStatement>
text <img picture="p1"/> <a attchment="a1"/>
</ProblemStatement>
<Checker src="checker.pp"/>
~),
        'checker.pp' => 'z',
        'p1.img' => 'p1data',
        'a1.txt' => 'a1data',
    });

    is scalar @{$p->{pictures}}, 1, 'pictures count';
    is $p->{pictures}->[0]->{name}, 'p1', 'picture 1 name';
    is $p->{pictures}->[0]->{src}, 'p1data', 'picture 1 data';
    is scalar @{$p->{attachments}}, 1, 'attachments count';
    is $p->{attachments}->[0]->{name}, 'a1', 'attachment 1 name';
    is $p->{attachments}->[0]->{src}, 'a1data', 'attachment 1 data';
};

subtest 'tag stack', sub {
    plan tests => 7;
    throws_ok { parse({
        'test.xml' => wrap_xml(q~<ProblemStatement/>~),
    }) } qr/ProblemStatement.+Problem/, 'ProblemStatement outside Problem';
    throws_ok { parse({
        'test.xml' => wrap_xml(q~<Checker/>~),
    }) } qr/Checker.+Problem/, 'Checker outside Problem';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Problem/>~),
    }) } qr/Problem.+CATS/, 'Problem inside Problem';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<In/>~),
    }) } qr/In.+Test/, 'In outside Test';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Out/>~),
    }) } qr/Out.+Test/, 'Out outside Test';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<SampleIn/>~),
    }) } qr/SampleIn.+Sample/, 'SampleIn outside Sample';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<SampleOut/>~),
    }) } qr/SampleOut.+Sample/, 'SampleOut outside SampleTest';
};

subtest 'apply_test_rank', sub {
    plan tests => 5;
    is CATS::Problem::Parser::apply_test_rank('abc', 9), 'abc', 'No rank';
    is CATS::Problem::Parser::apply_test_rank('a%nc', 9), 'a9c', '1 digit';
    is CATS::Problem::Parser::apply_test_rank('a%0nc', 9), 'a09c', '2 digits';
    is CATS::Problem::Parser::apply_test_rank('a%00nc', 9), 'a009c', '3 digits';
    is CATS::Problem::Parser::apply_test_rank('a%%%nc', 9), 'a%9c', 'Escape';
};

subtest 'sample', sub {
    plan tests => 34;

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Sample/>~),
    }) } qr/Sample.rank/, 'Sample without rank';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Sample rank="2"><SampleIn>q</SampleIn><SampleOut>w</SampleOut></Sample>~),
    }) } qr/Missing.*1/, 'missing sample';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Sample rank="1"/>~),
    }) } qr/Neither.*1 in_file/, 'missing in_file';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Sample rank="1"><SampleIn>w</SampleIn></Sample>~),
    }) } qr/Neither.*1 out_file/, 'missing out_file';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Sample rank="1"><SampleIn src="t01.in"/></Sample>~),
    }) } qr/'t01.in'/, 'Sample with nonexinsting input file';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Sample rank="1"><SampleIn src="t01.in"/><SampleOut src="t01.out"/></Sample>~),
        't01.in' => 'z',
    }) } qr/'t01.out'/, 'Sample with nonexinsting output file';
    throws_ok { parse({
            'test.xml' => wrap_problem(q~
<Sample rank="1"><SampleIn src="s"><tt>zz</tt></SampleIn><SampleOut>ww</SampleOut></Sample>~),
        's' => 'a',
    }) } qr/Both.*1 in_file/, 'Sample with duplicate input';
    throws_ok { parse({
            'test.xml' => wrap_problem(q~
<Sample rank="1"><SampleIn><tt>zz</tt></SampleIn><SampleOut src="s">ww</SampleOut></Sample>~),
        's' => 'a',
    }) } qr/Both.*1 out_file/, 'Sample with duplicate output';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Sample rank="1"><SampleIn src="t01.in"/><SampleIn src="t01.in"/></Sample>~),
        't01.in' => 'z',
    }) } qr/Redefined.*in_file/, 'Sample with duplicate input file';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Sample rank="1"><SampleOut src="t01.in"/><SampleOut src="t01.in"/></Sample>~),
        't01.in' => 'z',
    }) } qr/Redefined.*out_file/, 'Sample with duplicate output file';

    {
        my $p = parse({
            'test.xml' => wrap_problem(q~
<Sample rank="1"><SampleIn src="s"/><SampleOut src="s"/></Sample>
<Sample rank="2"><SampleIn>aaa</SampleIn><SampleOut>bbb</SampleOut></Sample>
<Checker src="checker.pp"/>~),
            'checker.pp' => 'zz',
            's' => 'sss',
        });
        is scalar(keys %{$p->{samples}}), 2, 'Sample count';
        my $s1 = $p->{samples}->{1};
        is $s1->{rank}, 1, 'Sample 1 rank';
        is $s1->{in_file}, 'sss', 'Sample 1 In src';
        is $s1->{out_file}, 'sss', 'Sample 1 Out src';
        my $s2 = $p->{samples}->{2};
        is $s2->{rank}, 2, 'Sample 2 rank';
        is $s2->{in_file}, 'aaa', 'Sample 2 In';
        is $s2->{out_file}, 'bbb', 'Sample 2 Out';
    }
    {
        my $p = parse({
            'test.xml' => wrap_problem(q~
<Sample rank="1-3"><SampleIn src="s%n"/><SampleOut src="out"/></Sample>
<Checker src="checker.pp"/>~),
            'checker.pp' => 'zz',
            's1' => 's11',
            's2' => 's22',
            's3' => 's33',
            'out' => 'out',
        });
        is scalar(keys %{$p->{samples}}), 3, 'Sample range count';
        for (1..3) {
            my $s = $p->{samples}->{$_};
            is $s->{rank}, $_, "Sample range $_ rank";
            is $s->{in_file}, "s$_$_", "Sample range $_ In src";
            is $s->{out_file}, 'out', "Sample range $_ Out src";
        }
    }
    {
        my $p = parse({
            'test.xml' => wrap_problem(q~
<Sample rank="1-2"><SampleIn><b>cc</b></SampleIn><SampleOut src="s%0n"/></Sample>
<Checker src="checker.pp"/>~),
            'checker.pp' => 'zz',
            's01' => 's11',
            's02' => 's22',
        });
        is scalar(keys %{$p->{samples}}), 2, 'Sample range count';
        for (1..2) {
            my $s = $p->{samples}->{$_};
            is $s->{rank}, $_, "Sample range $_ rank";
            is $s->{in_file}, '<b>cc</b>', "Sample range $_ In";
            is $s->{out_file}, "s$_$_", "Sample range $_ Out src";
        }
    }
};

subtest 'test', sub {
    plan tests => 41;

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test/>~),
    }) } qr/Test.rank/, 'Test without rank';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="2"/>~),
    }) } qr/Missing test #1/, 'Missing test 1';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1"/>~),
    }) } qr/No input source for test 1/, 'Test without In';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1"><In/></Test>~),
    }) } qr/No input source for test 1/, 'Test with empty In';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1"><In src="t01.in"/></Test>~),
    }) } qr/'t01.in'/, 'Test with nonexinsting input file';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1"><In src="t01.in"/><In src="t01.in"/></Test>~),
        't01.in' => 'z',
    }) } qr/Redefined attribute 'in_file'/, 'Test with duplicate In';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1"><In src="t01.in"/></Test>~),
        't01.in' => 'z',
    }) } qr/No output source for test 1/, 'Test without Out';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1"><In src="t01.in"/><Out/></Test>~),
        't01.in' => 'z',
    }) } qr/No output source for test 1/, 'Test with empty Out';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1"><In src="t01.in"/><Out src="t02.out"/></Test>~),
        't01.in' => 'z',
    }) } qr/'t02.out'/, 'Test with nonexinsting output file 1';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1-2"><In src="t01.in"/><Out src="t%0n.out"/></Test>~),
        't01.in' => 'z',
    }) } qr/'t01.out', 't02.out'/, 'Test with nonexinsting output file 2';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1"><In src="t01.in"/><Out src="t01.out"/><Out src="t01.out"/></Test>~),
        't01.in' => 'z',
        't01.out' => 'q',
    }) } qr/Redefined attribute 'out_file'/, 'Test with duplicate Out';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Test rank="1" points="A"><In src="t01.in"/><Out src="t01.out"/></Test>~),
        't01.in' => 'z',
        't01.out' => 'q',
    }) } qr/Bad points/, 'Bad points';

    {
        my $p = parse({
            'test.xml' => wrap_problem(q~
<Test rank="1"><In src="t01.in"/><Out src="t01.out"/></Test>
<Checker src="checker.pp"/>~),
            't01.in' => 'z',
            't01.out' => 'q',
            'checker.pp' => 'z',
        });
        is scalar(keys %{$p->{tests}}), 1, 'Test 1';
        my $t = $p->{tests}->{1};
        is $t->{rank}, 1, 'Test 1 rank';
        is $t->{in_file}, 'z', 'Test 1 In src';
        is $t->{out_file}, 'q', 'Test 1 Out src';
    }

    {
        my $p = parse({
            'test.xml' => wrap_problem(q~
<Test rank="1-2" points="5"><In src="t%n.in"/><Out src="t%n.out"/></Test>
<Checker src="checker.pp"/>~),
            't1.in' => 't1in', 't1.out' => 't1out',
            't2.in' => 't2in', 't2.out' => 't2out',
            'checker.pp' => 'z',
        });
        is scalar(keys %{$p->{tests}}), 2, 'Apply %n';
        for (1..2) {
            my $t = $p->{tests}->{$_};
            is $t->{rank}, $_, "Apply $_ rank";
            is $t->{points}, 5, "Apply $_ points";
            is $t->{in_file}, "t${_}in", "Apply $_ In src";
            is $t->{out_file}, "t${_}out", "Apply $_ Out src";
        }
    }

    {
        my $p = parse({
            'test.xml' => wrap_problem(q~
<Generator name="gen" src="gen.pp"/>
<Solution name="sol" src="sol.pp"/>
<Test rank="1-5"><In use="gen" param="!%n"/><Out use="sol"/></Test>
<Checker src="chk.pp"/>~),
            'gen.pp' => 'z',
            'sol.pp' => 'z',
            'chk.pp' => 'z',
        });
        is scalar(keys %{$p->{tests}}), 5, 'Gen %n';
        for (1, 2, 5) {
            my $t = $p->{tests}->{$_};
            is $t->{rank}, $_, "Gen $_ rank";
            is $t->{param}, "!$_", "Gen $_ param";
            is $t->{generator_id}, 'gen.pp', "Gen $_ In";
            is $t->{std_solution_id}, 'sol.pp', "Gen $_ Out";
        }
    }

    {
        my $parser = ParserMockup::make({
            'test.xml' => wrap_problem(q~
<Test rank="1" points="1"><In src="in"/><Out src="out"/></Test>
<Test rank="2"><In src="in"/><Out src="out"/></Test>
<Checker src="checker.pp" style="testlib"/>~),
            'in' => 'in', 'out' => 'out',
            'checker.pp' => 'z',
        });
        my $p = $parser->parse;
        my $w = $parser->logger->{warnings};
        is scalar @$w, 1, 'point/no-point warnings count';
        is $w->[0], 'Points are defined for tests: 1 but not 2', 'point/no-point warning';
        is scalar(keys %{$p->{tests}}), 2, 'point/no-point tests count';
    }

};

subtest 'testest', sub {
    plan tests => 20;

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Testset/>~),
    }) } qr/Testset.name/, 'Testset without name';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Testset name="ts"/>~),
    }) } qr/Testset.tests/, 'Testset without tests';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Testset name="ts" tests="X"/>~),
    }) } qr/Unknown testset 'X'/, 'Testset with bad tests 1';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Testset name="ts" tests="1-"/>~),
    }) } qr/Bad element/, 'Testset with bad tests 2';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Testset name="ts" tests="1"/>
<Testset name="ts" tests="2"/>~),
    }) } qr/Duplicate testset 'ts'/, 'Duplicate testset';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Testset name="ts" tests="1" points="X"/>~),
    }) } qr/Bad points for testset 'ts'/, 'Bad points';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Testset name="ts" tests="1"/>~),
    }) } qr/Undefined test 1 in testset 'ts'/, 'Undefined test';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Test rank="1-10"><In src="t"/><Out src="t"/></Test>
<Testset name="ts1" tests="1" depends_on="ts2"/>
<Testset name="ts2" tests="2" depends_on="ts1"/>
<Checker src="checker.pp"/>~),
            't' => 'q',
            'checker.pp' => 'z',
    }) } qr/Testset 'ts1' both contains and depends on test 1/, 'Recursive dependency via testest';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Test rank="1-10"><In src="t"/><Out src="t"/></Test>
<Testset name="ts1" tests="1" depends_on="ts2"/>
<Testset name="ts2" tests="2" depends_on="1"/>
<Checker src="checker.pp"/>~),
            't' => 'q',
            'checker.pp' => 'z',
    }) } qr/Testset 'ts1' both contains and depends on test 1/, 'Recursive dependency via test';

    {
        my $p = parse({
            'test.xml' => wrap_problem(q~
<Test rank="1-10"><In src="t"/><Out src="t"/></Test>
<Testset name="ts1" tests="2-5,1" comment="blabla"/>
<Testset name="ts2" tests="ts1,7" hideDetails="1"/>
<Testset name="ts3" tests="10" depends_on="ts1,6"/>
<Checker src="checker.pp"/>~),
            't' => 'q',
            'checker.pp' => 'z',
        });
        is scalar(keys %{$p->{testsets}}), 3, 'Testset count';

        my $ts1 = $p->{testsets}->{ts1};
        is $ts1->{name}, 'ts1', 'Testset 1 name';
        is $ts1->{tests}, '2-5,1', 'Testset 1 tests';
        is $ts1->{comment}, 'blabla', 'Testset 1 comment';
        is $ts1->{hideDetails}, 0, 'Testset 1 hideDetails';

        my $ts2 = $p->{testsets}->{ts2};
        is $ts2->{name}, 'ts2', 'Testset 2 name';
        is $ts2->{tests}, 'ts1,7', 'Testset 2 tests';
        is $ts2->{hideDetails}, 1, 'Testset 2 hideDetails';

        my $ts3 = $p->{testsets}->{ts3};
        is $ts3->{name}, 'ts3', 'Testset 3 name';
        is $ts3->{tests}, '10', 'Testset 2 tests';
        is $ts3->{depends_on}, 'ts1,6', 'Testset 3 depends_on';
    }
};

subtest 'validator', sub {
    plan tests => 8;
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Validator/>~),
    }) } qr/Validator.src/, 'Validator without source';
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Validator src="t"/>~),
    }) } qr/Validator.name/, 'Validator without name';
    my $p = parse({
        'test.xml' => wrap_problem(q~
<Validator name="val" src="t.pp" inputFile="*STDIN"/>
<Checker src="t.pp"/>
<Test rank="1"><In src="t" validate="val"/><Out src="t"/></Test>~),
        't.pp' => 'q',
        't' => 'w',
    });
    is @{$p->{validators}}, 1, 'validator count';
    my $v = $p->{validators}->[0];
    is $v->{name}, 'val', 'validator name';
    is $v->{src}, 'q', 'validator source';
    is $v->{inputFile}, '*STDIN', 'validator inputFile';
    is keys(%{$p->{tests}}), 1, 'validator test count';
    is $p->{tests}->{1}->{input_validator_id}, 't.pp', 'validator test validate';
};

subtest 'interactor', sub {
    plan tests => 6;
    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Interactor/>~),
    }) } qr/Interactor.src/, 'Interactor without source';

    my $p = parse({
        'test.xml' => wrap_problem(q~
<Interactor name="val" src="t.pp"/>
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q',
    });
    is $p->{interactor}->{src}, 'q', 'interactor source';

    my $parser = ParserMockup::make({
        'test.xml' => wrap_problem(q~<Interactor src="t.pp"/><Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q'
    });
    $parser->parse;
    is $parser->logger->{warnings}->[0], 'Interactor defined when run method is not interactive', 'interactor defined when not interactive';

    $parser = ParserMockup::make({
        'test.xml' => wrap_problem(q~<Run method="interactive" /><Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q'
    });
    $parser->parse;

    is $parser->logger->{warnings}->[0], 'Interactor is not defined when run method is interactive (maybe used legacy interactor definition)', 'interactor not defined';
    $parser = ParserMockup::make({
        'test.xml' => wrap_problem(q~
<Run method="interactive"/>
<Interactor src="t.pp"/>
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q'});
    $parser->parse;
    is @{$parser->logger->{warnings}}, 0, 'interactor normal tag definiton';

    $parser = ParserMockup::make({
        'test.xml' => wrap_problem(q~
<Interactor src="t.pp"/>
<Run method="interactive"/>
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q'
    });
    $parser->parse;
    is @{$parser->logger->{warnings}}, 0, 'interactor inverse tag definition';
};

subtest 'run method', sub {
    plan tests => 10;

    my $p = parse({
        'test.xml' => wrap_problem(q~
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q',
    });
    is $p->{run_method}, $cats::rm_default, 'default run method';

    $p = parse({
        'test.xml' => wrap_problem(q~
<Run method="default" />
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q',
    });
    is $p->{run_method}, $cats::rm_default, 'run method = default';

    $p = parse({
        'test.xml' => wrap_problem(q~
<Run method="interactive" />
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q',
    });
    is $p->{run_method}, $cats::rm_interactive, 'run method = interactive';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Run method="asd" />
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q',
    }) } qr/Unknown run method: /, 'bad run method';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~
<Run method="competitive" />
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q',
    }) } qr/Player count limit must be defined for competitive run method/, 'competetive without player count';

    my $parser = ParserMockup::make({
        'test.xml' => wrap_problem(q~
<Run method="default" players_count="1"/>
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q',
    });
    $p = $parser->parse;
    my $w = $parser->logger->{warnings};
    is scalar @$w, 1, 'players_count when not competitive warnings count';
    is $w->[0], 'Player count limit defined when run method is not competitive', 'players_count when not competitive warning';

    $p = parse({
        'test.xml' => wrap_problem(q~
<Run method="competitive" players_count="2,3-5"/>
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q',
    });
    is $p->{run_method}, $cats::rm_competitive, 'run method = competitive';
    is $p->{players_count}->[0], 2, 'run method = competitive, players_count = 2';

    $p = parse({
        'test.xml' => wrap_problem(q~
<Run method="competitive" players_count="2,4-5"/>
<Checker src="t.pp" style="testlib"/>~),
        't.pp' => 'q',
    });

    is_deeply $p->{players_count}, [ 2, 4, 5 ], 'run method = competitive, players_count = 2,4-5';
};

subtest 'memory unit suffix', sub {
    plan tests => 12;

    my $parse = sub {
        parse({
        'test.xml' => wrap_xml(qq~
<Problem title="asd" lang="en" tlimit="5" inputFile="asd" outputFile="asd" $_[0]>
<Checker src="checker.pp"/>
</Problem>~),
        'checker.pp' => 'begin end.',
        })->{description}
    };

    throws_ok { $parse->(q/mlimit="asd"/) } qr/Bad value of 'mlimit'/, 'bad mlimit asd';
    throws_ok { $parse->(q/mlimit="K"/) } qr/Bad value of 'mlimit'/, 'bad mlimit K';
    throws_ok { $parse->(q/mlimit="10K"/) } qr/Value of 'mlimit' must be in whole Mbytes/, 'mlimit 10K';
    is $parse->(q/mlimit="1024K"/)->{memory_limit}, 1, 'mlimit 1024K';
    is $parse->(q/mlimit="1M"/)->{memory_limit}, 1, 'mlimit 1M';
    is $parse->(q/mlimit="1"/)->{memory_limit}, 1, 'mlimit 1';

    throws_ok { $parse->(q/wlimit="asd"/) } qr/Bad value of 'wlimit'/, 'bad wlimit asd';
    throws_ok { $parse->(q/wlimit="K"/) } qr/Bad value of 'wlimit'/, 'bad wlimit K';
    is $parse->(q/wlimit="10B"/)->{write_limit}, 10, 'wlimit 10B';
    is $parse->(q/wlimit="2K"/)->{write_limit}, 2048, 'wlimit 2K';
    is $parse->(q/wlimit="1M"/)->{write_limit}, 1048576, 'wlimit 1M';
    is $parse->(q/wlimit="1"/)->{write_limit}, 1048576, 'wlimit 1';
};

subtest 'sources limit params', sub {
    plan tests => 60;

    my $test = sub {
        my ($tag, $getter) = @_;

        my $xml = $tag eq 'Checker' ? q~
        <Checker src="t.pp" style="testlib" %s/>"~ : qq~
        <$tag name="val" src="t.pp" \%s/><Checker src="t.pp" style="testlib"/>~;

        my $parse = sub {
            parse({
                'test.xml' => wrap_problem(sprintf $xml, $_[0]),
                'checker.pp' => 'begin end.', 't.pp' => 'q'
            })
        };

        throws_ok { $parse->(q/memoryLimit="asd"/) } qr/Bad value of 'memoryLimit'/, "bad memoryLimit asd: $tag";
        throws_ok { $parse->(q/memoryLimit="K"/) } qr/Bad value of 'memoryLimit'/, "bad memoryLimit K: $tag";
        throws_ok { $parse->(q/memoryLimit="10K"/) } qr/Value of 'memoryLimit' must be in whole Mbytes/, "memoryLimit 10K: $tag";
        is $getter->($parse->(q/memoryLimit="1024K"/))->{memory_limit}, 1, "memoryLimit 1024K: $tag";
        is $getter->($parse->(q/memoryLimit="1M"/))->{memory_limit}, 1, "memoryLimit 1M: $tag";
        is $getter->($parse->(q/memoryLimit="1"/))->{memory_limit}, 1, "memoryLimit 1: $tag";

        throws_ok { $parse->(q/writeLimit="asd"/) } qr/Bad value of 'writeLimit'/, "bad writeLimit asd: $tag";
        throws_ok { $parse->(q/writeLimit="K"/) } qr/Bad value of 'writeLimit'/, "bad writeLimit K: $tag";
        is $getter->($parse->(q/writeLimit="10B"/))->{write_limit}, 10, "writeLimit 10B: $tag";
        is $getter->($parse->(q/writeLimit="2K"/))->{write_limit}, 2048, "writeLimit 2K: $tag";
        is $getter->($parse->(q/writeLimit="1M"/))->{write_limit}, 1048576, "writeLimit 1M: $tag";
        is $getter->($parse->(q/writeLimit="1"/))->{write_limit}, 1048576, "writeLimit 1: $tag";
    };

    $test->('Generator', sub { $_[0]->{generators}[0] });
    $test->('Solution', sub { $_[0]->{solutions}[0] });
    $test->('Visualizer', sub { $_[0]->{visualizers}[0] });
    $test->('Checker', sub { $_[0]->{checker} });
    $test->('Interactor', sub { $_[0]->{interactor} });
};

subtest 'formal', sub {
    plan tests => 27;

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Formal/>~),
    }) } qr/Formal.name/, 'formal no name';

    throws_ok { parse({
        'test.xml' => wrap_problem(q~<Formal name="input"/>~),
    }) } qr/'Formal' tag without formal description/, 'formal empty';

    throws_ok{ parse ({
        'test.xml' => wrap_problem(q~
            <Formal name="input" src="input.fd">
                integer name=A;
            </Formal>
            <Checker src="t.pp"/>
        ~),
        't.pp' => 'q',
        'input.fd' => "integer name=B;"
    }) } qr/Redefined attribute 'src' for formal description input/, 'formal with src and inline code';

    {
        my $inline_code = "integer name=A;";
        my $p = parse({
            'test.xml'  => wrap_problem(qq~
            <Formal name="input">$inline_code</Formal>
            <Formal name="input2" src="input2.fd"/>
            <Checker src="t.pp"/>~
            ),
            't.pp'      => 'q',
            'input2.fd' => 'integer name=B;'
        });
        is @{$p->{formals}}, 2, 'formal count';
        my $i1 = $p->{formals}->[0];
        my $i2 = $p->{formals}->[1];
        is $i1->{name}, 'input', 'formal inline name';
        is $i2->{name}, 'input2', 'formal src name ';
        is $i1->{src}, $inline_code, 'formal inline code';
        is $i2->{src}, "integer name=B;", 'formal src code';
    }

    sub formal_test {
        my ($test, %files) = @_;
        parse({
            'test.xml' => wrap_problem(qq~
                <Checker src="t.pp"/>
                <Generator name="gen" src="t.pp"/>
                <Solution name="sol" src="t.pp"/>
                $test
            ~),
            't.pp' => 'q',
            %files
        });
    }

    throws_ok {
        formal_test(q~
            <Formal name="formal">i</Formal>
            <Test rank="1">
                <In use="gen" validate="formal"/>
                <Out use="sol" />
            </Test>
        ~,
    ) } qr/got 'i' at line 1 : 1/, 'formal check input';

    throws_ok {
        formal_test(q~
            <Formal name="formal">i</Formal>
            <Test rank="1">
                <In use="gen"/>
                <Out use="sol" validate="formal" />
            </Test>
        ~,
    ) } qr/got 'i' at line 1 : 1/, 'formal check output';

    throws_ok {
        formal_test(q~
            <Formal name="formal_in">i</Formal>
            <Formal name="formal_out">integer name=A;</Formal>
            <Test rank="1">
                <In use="gen" validate="formal_in"/>
                <Out use="sol" validate="formal_out" />
            </Test>
        ~,
    ) } qr/got 'i' at line 1 : 1/, 'formal check input and output (bad formal input)';

    throws_ok {
        formal_test(q~
            <Formal name="formal_in">integer name=A;</Formal>
            <Formal name="formal_out">i</Formal>
            <Test rank="1">
                <In use="gen" validate="formal_in"/>
                <Out use="sol" validate="formal_out" />
            </Test>
        ~,
    ) } qr/got 'i' at line 1 : 1/, 'formal check input and output (bad formal output)';


    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Test rank="1">
                <In src="1.in" validate="formal"/>
                <Out use="sol"/>
            </Test>
        ~, '1.in' => '100'
    ) } qr/expected integer in range from 0 to 10 but '100' given/, 'formal validate input';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Test rank="1">
                <In use="gen"/>
                <Out src="1.out" validate="formal"/>
            </Test>
        ~, '1.out' => '100'
    ) } qr/expected integer in range from 0 to 10 but '100' given/, 'formal validate output';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Test rank="1">
                <In src="1.in" validate="formal"/>
                <Out src="1.out" validate="formal"/>
            </Test>
        ~, '1.in' => '100', '1.out' => '1'
    ) } qr/expected integer in range from 0 to 10 but '100' given/, 'formal validate input and output (bad input)';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Test rank="1">
                <In src="1.in" validate="formal"/>
                <Out src="1.out" validate="formal"/>
            </Test>
        ~, '1.in' => '1', '1.out' => '100'
    ) } qr/expected integer in range from 0 to 10 but '100' given/, 'formal validate input and output (bad output)';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Test rank="1">
                <In src="1.in" validate="formal"/>
                <Out use="sol" validate="formal"/>
            </Test>
        ~, '1.in' => '100'
    ) } qr/expected integer in range from 0 to 10 but '100' given/, 'formal validate input and check output (bad input)';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Formal name="formal_out">i</Formal>
            <Test rank="1">
                <In src="1.in" validate="formal"/>
                <Out use="sol" validate="formal_out"/>
            </Test>
        ~, '1.in' => '1'
    ) } qr/got 'i' at line 1 : 1/, 'formal validate input and check output (bad formal output)';

    throws_ok {
        formal_test(q~
            <Formal name="formal">i</Formal>
            <Formal name="formal_out">integer name=A, range=[0, 10];</Formal>
            <Test rank="1">
                <In use="gen" validate="formal"/>
                <Out src="1.out" validate="formal_out"/>
            </Test>
        ~, '1.out' => '1'
    ) } qr/got 'i' at line 1 : 1/, 'formal check input and validate output (bad formal input)';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Test rank="1">
                <In use="gen" validate="formal"/>
                <Out src="1.out" validate="formal"/>
            </Test>
        ~, '1.out' => '100'
    ) } qr/expected integer in range from 0 to 10 but '100' given/, 'formal check input and validate output (bad output)';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Formal name="formal_out">i</Formal>
            <Test rank="1">
                <In use="gen" validate="formal"/>
                <Out src="1.out" validate="formal_out"/>
            </Test>
        ~, '1.out' => '100'
    ) }  qr/got 'i' at line 1 : 1/, 'formal check input and validate output (fallback to syntax check - bad formal output)';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Sample rank="1">
                <SampleIn validate="formal">100</SampleIn>
                <SampleOut validate="formal">1</SampleOut>
            </Sample>
        ~,
    ) } qr/expected integer in range from 0 to 10 but '100' given/, 'formal sample validation: inline - bad in';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Sample rank="1">
                <SampleIn validate="formal">1</SampleIn>
                <SampleOut validate="formal">100</SampleOut>
            </Sample>
        ~,
    ) } qr/expected integer in range from 0 to 10 but '100' given/, 'formal sample validation: inline - bad out';

    lives_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Sample rank="1">
                <SampleIn validate="formal">1</SampleIn>
                <SampleOut validate="formal">1</SampleOut>
            </Sample>
        ~,
    ) } 'formal sample validation: inline - all ok';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Sample rank="1">
                <SampleIn validate="formal" src="1.sample"/>
                <SampleOut validate="formal">1</SampleOut>
            </Sample>
        ~, '1.sample' => '100'
    ) }  qr/expected integer in range from 0 to 10 but '100' given/, 'formal sample validation: src - bad in';

    throws_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Sample rank="1">
                <SampleIn validate="formal">1</SampleIn>
                <SampleOut validate="formal" src="1.sample"/>
            </Sample>
        ~, '1.sample' => '100'
    ) } qr/expected integer in range from 0 to 10 but '100' given/, 'formal sample validation: src - bad out';

    lives_ok {
        formal_test(q~
            <Formal name="formal">integer name=A, range=[0, 10];</Formal>
            <Sample rank="1">
                <SampleIn validate="formal" src="1.sample"/>
                <SampleOut validate="formal" src="1.sample"/>
            </Sample>
        ~, '1.sample' => '1'
    ) } 'formal sample validation: src - all ok';

};
