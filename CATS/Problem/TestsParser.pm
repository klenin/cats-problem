package CATS::Problem::Parser;

use strict;
use warnings;

use CATS::Testset;
use CATS::Formal::Formal;

use CATS::Constants;

sub apply_test_rank
{
    my ($v, $rank) = @_;
    defined $v && $rank or return $v;
    #$v = '' unless defined $v;
    $v =~ s/%n/$rank/g;
    $v =~ s/%0n/sprintf("%02d", $rank)/eg;
    $v =~ s/%00n/sprintf("%03d", $rank)/eg;
    $v =~ s/%%/%/g;
    $v;
}

sub get_formal_validator
{
    my ($validator) = @_;
    my $formal_validator = $validator || {};
    defined $formal_validator->{type} && (
            $formal_validator->{type} == $cats::formal ||
               $formal_validator->{type} == $cats::formal_module
        ) && return $formal_validator;
    undef;
}

sub check_syntax
{
    CATS::Formal::Formal::check_syntax(@_);
}

sub validate_test_by_formal
{
    (my CATS::Problem::Parser $self, my $test) = @_;
    my $formal_input = get_formal_validator($test->{input_validator});
    my $formal_output = get_formal_validator($test->{output_validator});
    if ($test->{in_file} && $formal_input){
        if ($test->{out_file} && $formal_output){
            return CATS::Formal::Formal::validate(
                {INPUT => $self->get_src($formal_input), OUTPUT => $self->get_src($formal_output)},
                {INPUT => $test->{in_file}, OUTPUT => $test->{out_file}},
                {all => 'text'}
            );
        }
        return CATS::Formal::Formal::validate(
            {INPUT => $self->get_src($formal_input)}, {INPUT => $test->{in_file}}, {all => 'text'}
        ) || $formal_output && check_syntax(
            {INPUT => $self->get_src($formal_input), OUTPUT => $self->get_src($formal_output)},
            {all => 'text'}
        );
    } elsif ($test->{out_file} && $formal_output) {
        return CATS::Formal::Formal::validate(
            {OUTPUT => $self->get_src($formal_output)}, {OUTPUT => $test->{out_file}}, {all => 'text'}
        ) || $formal_input && check_syntax(
            {INPUT => $self->get_src($formal_input), OUTPUT => $self->get_src($formal_output)},
            {all => 'text'}
        );
    } elsif ($formal_input && $formal_output){
        return check_syntax(
            {INPUT => $self->get_src($formal_input), OUTPUT => $self->get_src($formal_output)},
            {all => 'text'}
        );
    } elsif ($formal_input){
        return check_syntax(
            {INPUT => $self->get_src($formal_input)},
            {all => 'text'}
        );
    } elsif ($formal_output){
        return check_syntax(
            {OUTPUT => $self->get_src($formal_output)},
            {all => 'text'}
        );
    }
}

sub test_validators_to_ids
{
    (my CATS::Problem::Parser $self, my $test) = @_;
    my $in_v = $test->{input_validator};
    my $out_v = $test->{output_validator};
    $in_v && ($test->{input_validator_id} = $in_v->{src_id} || $in_v->{id});
    $out_v && ($test->{output_validator_id} = $out_v->{src_id} || $out_v->{id});
    undef $test->{input_validator};
    undef $test->{output_validator};
}

sub validate_test
{
    (my CATS::Problem::Parser $self, my $test) = @_;
    defined $test->{in_file} || $test->{generator_id}
        or return 'No input source';
    defined $test->{in_file} && $test->{generator_id}
        and return 'Both input file and generator';
    (defined $test->{param} && $test->{param} ne '' || $test->{gen_group}) && !$test->{generator_id}
        and return 'Parameters without generator';
    defined $test->{out_file} || $test->{std_solution_id}
        or return 'No output source';
    defined $test->{out_file} && $test->{std_solution_id}
        and return 'Both output file and standard solution';
    my $err = $self->validate_test_by_formal($test);
    $err && return $err;
    $self->test_validators_to_ids($test);
    undef;
}

sub set_test_attr
{
    my CATS::Problem::Parser $self = shift;
    my ($test, $attr, $value) = @_;
    defined $value or return;
    defined $test->{$attr}
        and return $self->error("Redefined attribute '$attr' for test #$test->{rank}");
    $test->{$attr} = $value;
}

sub add_test
{
    (my CATS::Problem::Parser $self, my $atts, my $rank) = @_;
    $rank =~ /^\d+$/ && $rank > 0 && $rank < 1000
        or $self->error("Bad rank: '$rank'");
    my $t = $self->{problem}{tests}->{$rank} ||= { rank => $rank };
    $self->set_test_attr($t, 'points', $atts->{points});
    push @{$self->{current_tests}}, $t;
}

sub parse_test_rank
{
    (my CATS::Problem::Parser $self, my $rank_spec) = @_;
    keys %{CATS::Testset::parse_test_rank(
        $self->{problem}{testsets}, $rank_spec, sub { $self->error(@_) })};
}

sub start_tag_Test
{
    (my CATS::Problem::Parser $self, my $atts) = @_;
    if ($atts->{rank} eq '*') { #=~ /^\s*\*\s*$/)
        $self->{current_tests} = [ $self->{test_defaults} ||= {} ];
        $self->set_test_attr($self->{test_defaults}, 'points', $atts->{points});
    } else {
        $self->{current_tests} = [];
        $self->add_test($atts, $_) for $self->parse_test_rank($atts->{rank});
    }
}

sub start_tag_TestRange
{
    (my CATS::Problem::Parser $self, my $atts) = @_;
    $atts->{from} <= $atts->{to}
        or $self->error('TestRange.from > TestRange.to');
    $self->{current_tests} = [];
    $self->add_test($atts, $_) for ($atts->{from}..$atts->{to});
    $self->warning("Deprecated tag 'TestRange', use 'Test' instead");
}

sub end_tag_Test
{
    my CATS::Problem::Parser $self = shift;
    undef $self->{current_tests};
}

sub do_In_src
{
    (my CATS::Problem::Parser $self, my $test, my $attr) = @_;
    my $src = apply_test_rank($attr, $test->{rank});
    ('in_file', $self->{source}->read_member($src, "Invalid test input file reference: '$src'"));
}

sub do_In_param
{
    ('param', apply_test_rank($_[2], $_[1]->{rank}))
}

sub do_In_use
{
    (my CATS::Problem::Parser $self, my $test, my $attr) = @_;
    my $use = apply_test_rank($attr, $test->{rank});
    ('generator_id', $self->get_imported_id($use) || $self->get_named_object($use)->{id});
}

sub do_In_genAll
{
    (my CATS::Problem::Parser $self, my $test, my $attr) = @_;
    my $gg = $self->{gen_groups};
    ('gen_group', $gg->{$test->{generator_id}} ||= 1 + keys %$gg);
}

sub start_tag_In
{
    (my CATS::Problem::Parser $self, my $atts) = @_;

    my @t = @{$self->{current_tests}};

    for my $attr_name (qw/src param/) {
        defined(my $attr_value = $atts->{$attr_name}) or next;
        my $n = "do_In_$attr_name";
        $self->set_test_attr($_, $self->$n($_, $attr_value)) for @t;
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
            "Generator group $gen_group created for tests " . join ',', map $_->{rank}, @t) if $gen_group;
    }
    if (defined $atts->{validate}) {
        for (@t) {
            my $validate = apply_test_rank($atts->{validate}, $_->{rank});
            $self->set_test_attr($_, 'input_validator',
                $self->get_object_by_name($validate));
        }
    }
}

sub start_tag_Out
{
    (my CATS::Problem::Parser $self, my $atts) = @_;

    my @t = @{$self->{current_tests}};

    if (defined $atts->{src}) {
        for (@t) {
            my $src = apply_test_rank($atts->{'src'}, $_->{rank});
            $self->set_test_attr($_, 'out_file', $self->{source}->read_member($src, "Invalid test output file reference: '$src'"));
        }
    }
    if (defined $atts->{'use'}) {
        for (@t) {
            my $use = apply_test_rank($atts->{'use'}, $_->{rank});
            $self->set_test_attr($_, 'std_solution_id', $self->get_named_object($use)->{id});
        }
    }
    if (defined $atts->{validate}) {
        for (@t) {
            my $validate = apply_test_rank($atts->{validate}, $_->{rank});
            $self->set_test_attr($_, 'output_validator',
                $self->get_object_by_name($validate));
        }
    }
}

sub apply_test_defaults
{
    my CATS::Problem::Parser $self = shift;
    my $d = $self->{test_defaults};
    for my $attr (qw(generator_id input_validator_id output_validator_id param std_solution_id points gen_group)) {
        $d->{$attr} or next;
        $_->{$attr} ||= $d->{$attr} for values %{$self->{problem}{tests}};
    }
}


1;
