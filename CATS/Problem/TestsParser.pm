package CATS::Problem::Parser;

use strict;
use warnings;

use CATS::Testset;

sub apply_test_rank {
    my ($v, $rank) = @_;
    defined $v && $rank or return $v;
    #$v = '' unless defined $v;
    $v =~ s/%n/$rank/g;
    $v =~ s/%0n/sprintf("%02d", $rank)/eg;
    $v =~ s/%00n/sprintf("%03d", $rank)/eg;
    $v =~ s/%%/%/g;
    $v;
}

sub validate_test {
    my ($test) = @_;
    defined $test->{in_file} || $test->{generator_id}
        or return 'No input source';
    defined $test->{in_file} && $test->{generator_id}
        and return 'Both input file and generator';
    (defined $test->{param} && $test->{param} ne '' || $test->{gen_group}) && !$test->{generator_id}
        and return 'Parameters without generator';
    defined $test->{out_file} || $test->{std_solution_id} || $test->{snippet_name}
        or return 'No output source';
    1 < grep $_, defined $test->{out_file}, $test->{std_solution_id}, $test->{snippet_name}
        and return 'More than one of: output file, standard solution ans snippet';
    defined $test->{input_validator_param} && !$test->{input_validator_id}
        and return 'Attribute "validateParam" without "validate"';
    ($test->{points} // '0') =~ /^\d+$/
        or return 'Bad points';
    undef;
}

sub set_test_attr {
    my CATS::Problem::Parser $self = shift;
    my ($test, $attr, $value) = @_;
    defined $value or return;
    defined $test->{$attr}
        and return $self->error("Redefined attribute '$attr' for test #$test->{rank}");
    $test->{$attr} = $value;
}

sub _validate_rank {
    (my CATS::Problem::Parser $self, my $rank) = @_;
    $rank =~ /^\d+$/ && $rank > 0 && $rank < 1000
        or $self->error("Bad rank: '$rank'");
}

sub add_test {
    (my CATS::Problem::Parser $self, my $atts, my $rank) = @_;
    $self->_validate_rank($rank);
    my $t = $self->{problem}->{tests}->{$rank} ||= { rank => $rank };
    $self->set_test_attr($t, 'points', $atts->{points});
    $self->set_test_attr($t, 'descr', $atts->{descr});
    push @{$self->{current_tests}}, $t;
}

sub parse_test_rank {
    (my CATS::Problem::Parser $self, my $rank_spec) = @_;
    sort { $a <=> $b } keys %{CATS::Testset::parse_test_rank(
        $self->{problem}->{testsets}, $rank_spec, sub { $self->error(@_) })};
}

sub start_tag_Test {
    (my CATS::Problem::Parser $self, my $atts) = @_;
    if ($atts->{rank} eq '*') { #=~ /^\s*\*\s*$/)
        $self->{current_tests} = [ $self->{test_defaults} ||= {} ];
        $self->set_test_attr($self->{test_defaults}, 'points', $atts->{points});
    }
    else {
        $self->{current_tests} = [];
        $self->add_test($atts, $_) for $self->parse_test_rank($atts->{rank});
    }
}

sub start_tag_TestRange {
    (my CATS::Problem::Parser $self, my $atts) = @_;
    $atts->{from} <= $atts->{to}
        or $self->error('TestRange.from > TestRange.to');
    $self->{current_tests} = [];
    $self->add_test($atts, $_) for ($atts->{from}..$atts->{to});
    $self->warning("Deprecated tag 'TestRange', use 'Test' instead");
}

sub end_tag_Test {
    my CATS::Problem::Parser $self = shift;
    delete $self->{current_test_data};
    delete $self->{current_tests};
}

sub do_In_src {
    (my CATS::Problem::Parser $self, my $test, my $attr) = @_;
    my $src = apply_test_rank($attr, $test->{rank});
    (
        in_file => $self->{source}->read_member($src, "Invalid test input file reference: '$src'"),
        in_file_name => $src);
}

sub do_In_param {
    (param => apply_test_rank($_[2], $_[1]->{rank}))
}

sub do_In_use {
    (my CATS::Problem::Parser $self, my $test, my $attr) = @_;
    my $use = apply_test_rank($attr, $test->{rank});
    (generator_id => $self->get_imported_id($use) || $self->get_named_object($use)->{id});
}

sub do_In_genAll {
    (my CATS::Problem::Parser $self, my $test, my $attr) = @_;
    my $gg = $self->{gen_groups};
    (gen_group => $gg->{$test->{generator_id}} ||= 1 + keys %$gg);
}

sub do_In_hash {
    (my CATS::Problem::Parser $self, my $test, my $attr) = @_;
    my ($alg) = $attr =~ /^\$(.+)\$(.+)$/
        or $self->error("Invalid hash format '$attr' for test #$test->{rank}");
    $alg =~ /^(md5|sha)$/
        or $self->error("Unknown hash algorithm '$alg' for test #$test->{rank}");
    (hash => $attr);
}

sub start_tag_In {
    (my CATS::Problem::Parser $self, my $atts) = @_;

    my @t = @{$self->{current_tests}};

    for my $attr_name (qw/src param hash/) {
        defined(my $attr_value = $atts->{$attr_name}) or next;
        my $n = "do_In_$attr_name";
        for my $test (@t) {
            my %update = $self->$n($test, $attr_value);
            $self->set_test_attr($test, $_, $update{$_}) for sort keys %update;
        }
    }
    if (defined $atts->{'use'}) {
        my $gen_group = $atts->{genAll} ? ++$self->{gen_groups} : undef;
        for (@t) {
            my $use = apply_test_rank($atts->{'use'}, $_->{rank});
            $self->set_test_attr($_, 'generator_id',
                $self->get_imported_id($use) || $self->get_named_object($use)->{id});
            # TODO
            $self->set_test_attr($_, 'gen_group', $gen_group);
        }
        $self->note(
            "Generator group $gen_group created for tests " . CATS::Testset::pack_rank_spec(map $_->{rank}, @t))
            if $gen_group;
    }
    if (defined $atts->{validate}) {
        for (@t) {
            my $validate = apply_test_rank($atts->{validate}, $_->{rank});
            $self->set_test_attr($_, 'input_validator_id',
                $self->get_imported_id($validate) || $self->get_named_object($validate)->{id});
        }
    }
    if (defined $atts->{validateParam}) {
        for (@t) {
            my $validate_param = apply_test_rank($atts->{validateParam}, $_->{rank});
            $self->set_test_attr($_, 'input_validator_param', $validate_param);
        }
    }
    $self->current_tag->{is_literal} = 1;
    $self->current_tag->{stml} = \($self->{current_test_data}->{in_file} = '');
}

sub start_tag_Out {
    (my CATS::Problem::Parser $self, my $atts) = @_;

    my @t = @{$self->{current_tests}};

    if (defined $atts->{src}) {
        my (@invalid);
        for (@t) {
            my $src = apply_test_rank($atts->{'src'}, $_->{rank});
            if (defined (my $m = $self->{source}->read_member($src))) {
                $self->set_test_attr($_, 'out_file', $m);
                $self->set_test_attr($_, 'out_file_name', $src);
            }
            else {
                push @invalid, $src;
            }
        }
        @invalid and
            $self->error('Invalid test output file references: ' . join ', ', map "'$_'", sort @invalid);
    }
    if (defined $atts->{'use'}) {
        for (@t) {
            my $use = apply_test_rank($atts->{'use'}, $_->{rank});
            $self->set_test_attr($_, 'std_solution_id', $self->get_named_object($use)->{id});
        }
    }
    if (defined $atts->{snippet}) {
        for (@t) {
            my $snippet = apply_test_rank($atts->{snippet}, $_->{rank});
            $self->get_named_object($snippet, 'snippet');
            $self->set_test_attr($_, 'snippet_name', $snippet);
        }
    }
    $self->current_tag->{is_literal} = 1;
    $self->current_tag->{stml} = \($self->{current_test_data}->{out_file} = '');
}

sub end_tag_InOut {
    my ($self, $in_out) = @_;
    $self->end_stml;
    my $t = $self->{current_test_data}->{$in_out};
    return if $t eq '';
    $self->set_test_attr($_, $in_out, $t) for @{$self->{current_tests}};
}

sub end_tag_In { $_[0]->end_tag_InOut('in_file') }
sub end_tag_Out { $_[0]->end_tag_InOut('out_file') }

sub apply_test_defaults {
    my CATS::Problem::Parser $self = shift;
    my $d = $self->{test_defaults};
    for my $attr (qw(generator_id input_validator_id param std_solution_id points gen_group in_file out_file)) {
        defined $d->{$attr} or next;
        $_->{$attr} //= $d->{$attr} for values %{$self->{problem}->{tests}};
    }
}

sub start_tag_Testset {
    (my CATS::Problem::Parser $self, my $atts) = @_;
    my $n = $atts->{name};
    my $problem = $self->{problem};
    $problem->{testsets}->{$n} and $self->error("Duplicate testset '$n'");
    $self->parse_test_rank($atts->{tests});
    $problem->{testsets}->{$n} = my $ts = {
        id => $self->{id_gen}->($self, "Test_set_with_name_$n"),
        map { $_ => $atts->{$_} } qw(name tests points comment hideDetails depends_on)
    };
    $ts->{hideDetails} ||= 0;
    ($ts->{points} // 0) =~ /^\d+$/ or $self->error("Bad points for testset '$n'");
    $self->note("Testset $n added");
}

sub validate_testsets {
    (my CATS::Problem::Parser $self) = @_;
    my $all_testsets = $self->{problem}->{testsets};
    for my $ts (sort keys %$all_testsets) {
        CATS::Testset::validate_testset(
        $all_testsets, $self->{problem}->{tests}, $ts, sub { $self->error(@_) }) or return;
    }
}

my %quiz_types = (checkbox => 2, radiogroup => 2, text => 1);
sub _quiz_type_choices { $quiz_types{$_[0]} == 2 }

sub _quiz_init_test {
    (my CATS::Problem::Parser $self, my $tag, my $rank) = @_;
    if (!$tag->{rank}) {
        $tag->{rank} = $rank //= ++$self->{quiz_rank};
        $self->_validate_rank($rank);
    }
    else {
        $rank = $tag->{rank};
    }
    $self->{problem}->{tests}->{$rank} ||= { rank => $rank, in_file => $rank };
}

sub start_tag_Quiz {
    (my CATS::Problem::Parser $self, my $atts, my $el) = @_;

    $self->{has_quizzes} = 1;

    my $c = $self->current_tag;
    $c->{type} = $atts->{type};
    $quiz_types{$c->{type}} or $self->error(
        "Unknown quiz type '$c->{type}', must be one of: " . join ', ', sort keys %quiz_types);

    if (0 < grep exists $atts->{$_}, qw(descr points rank)) {
        my $t = $self->_quiz_init_test($c, $atts->{rank});
        $self->set_test_attr($t, 'points', $atts->{points});
        $self->set_test_attr($t, 'descr', $atts->{descr});
    }

    if (_quiz_type_choices($c->{type})) {
        $c->{correct} = [];
        $c->{choice_count} = 0;
    }
    $c->{content} = $self->build_tag($el, $atts);
}

sub end_tag_Quiz {
    (my CATS::Problem::Parser $self, my $atts, my $el) = @_;

    my $c = $self->current_tag;
    ${$self->parent_tag->{stml}} .= $c->{content} . "</$el>";
    if (_quiz_type_choices($c->{type}) && @{$c->{correct}}) {
        $c->{type} eq 'radiogroup' && @{$c->{correct}} > 1
            and $self->error("Multiple correct choices for Quiz.radiogroup");
        my $t = $self->_quiz_init_test($c);
        $self->set_test_attr($t, 'out_file', join ' ', @{$c->{correct}});
    }
}

sub start_tag_Text {
    (my CATS::Problem::Parser $self, my $atts, my $el) = @_;
    ${$self->current_tag->{stml}} = $self->build_tag($el, $atts);
}

sub end_tag_Text {
    (my CATS::Problem::Parser $self, my $atts, my $el) = @_;
    $self->parent_tag->{content} .= ${$self->current_tag->{stml}} . "</$el>";
    undef $self->current_tag->{stml};
}

sub start_tag_Choice {
    (my CATS::Problem::Parser $self, my $atts, my $el) = @_;
    my $p = $self->parent_tag;
    _quiz_type_choices($p->{type})
        or $self->error("Choice tag inside Quiz.$p->{type}, must be inside one of: " .
            join ', ', sort grep _quiz_type_choices($_), keys %quiz_types);
    ++$p->{choices_count};
    push @{$p->{correct}}, $p->{choices_count} if $atts->{correct};
    delete $atts->{correct};
    ${$self->current_tag->{stml}} = $self->build_tag($el, $atts);
}

sub end_tag_Choice {
    (my CATS::Problem::Parser $self, my $atts, my $el) = @_;
    $self->parent_tag->{content} .= ${$self->current_tag->{stml}} . "</$el>";
    undef $self->current_tag->{stml};
}

sub start_tag_Answer {
    (my CATS::Problem::Parser $self, my $atts, my $el) = @_;
    $_ eq 'text' or $self->error("Answer tag inside Quiz.$_, must be inside Quiz.text")
        for $self->parent_tag->{type};
    ${$self->current_tag->{stml}} = '';
}

sub end_tag_Answer {
    (my CATS::Problem::Parser $self, my $atts, my $el) = @_;
    my $t = $self->_quiz_init_test($self->parent_tag);
    $self->set_test_attr($t, 'out_file', ${$self->current_tag->{stml}});
    undef $self->current_tag->{stml};
}

1;
