package CATS::Formal::Functions;
use strict;
use warnings;

use Math::Trig;
use CATS::Formal::Expressions;

use constant Integer => 'CATS::Formal::Expressions::Integer';
use constant Float   => 'CATS::Formal::Expressions::Float';
use constant String  => 'CATS::Formal::Expressions::String';
use constant Record  => 'CATS::Formal::Expressions::Record';

my $cos_function;
my $sin_function;
my $tan_function;
my $cotan_function;
my $asin_function;
my $acos_function;
my $atan_function;
my $acotan_function;
my $sinh_function ;
my $cosh_function;
my $tanh_function;
my $cotanh_function;
my $asinh_function;
my $acosh_function;
my $atanh_function;
my $acotanh_function;
my $pi_function;
my $str_length_function;
my $seq_length_function;
my $abs_int_function;
my $abs_float_function;
my $substr_function;
my $str_to_int_function;
my $str_to_float_function;
my $int_to_float_function;
my $int_to_str_function;
my $float_to_int_function;
my $float_to_str_function;
my $seq_last_function;

BEGIN {

$cos_function = {
    name   => 'cos',
    params => ['is_number'],
    calc   => sub {
        Float->new(cos ${$_[0]});
    },
    return => Float,
};

$sin_function = {
    name   => 'sin',
    params => ['is_number'],
    calc   => sub {
        Float->new(sin ${$_[0]});
    },
    return => Float,
};

$tan_function = {
    name   => 'tan',
    params => ['is_number'],
    calc   => sub {
        Float->new(tan ${$_[0]})
    },
    return => Float,
};

$cotan_function = {
    name   => 'cotan',
    params => ['is_number'],
    calc   => sub {
        Float->new(cotan ${$_[0]})
    },
    return => Float,
};

$asin_function = {
    name   => 'asin',
    params => ['is_number'],
    calc   => sub {
        Float->new(asin ${$_[0]})
    },
    return => Float,
};

$acos_function = {
    name   => 'acos',
    params => ['is_number'],
    calc   => sub {
        Float->new(acos ${$_[0]})
    },
    return => Float,
};

$atan_function = {
    name   => 'atan',
    params => ['is_number'],
    calc   => sub {
        Float->new(atan ${$_[0]})
    },
    return => Float,
};

$acotan_function = {
    name   => 'acotan',
    params => ['is_number'],
    calc   => sub {
        Float->new(acotan ${$_[0]})
    },
    return => Float,
};

$sinh_function = {
    name   => 'sinh',
    params => ['is_number'],
    calc   => sub {
        Float->new(sinh ${$_[0]})
    },
    return => Float,
};

$cosh_function = {
    name   => 'cosh',
    params => ['is_number'],
    calc   => sub {
        Float->new(cosh ${$_[0]})
    },
    return => Float,
};

$tanh_function = {
    name   => 'tanh',
    params => ['is_number'],
    calc   => sub {
        Float->new(tanh ${$_[0]})
    },
    return => Float,
};

$cotanh_function = {
    name   => 'cotanh',
    params => ['is_number'],
    calc   => sub {
        Float->new(cotanh ${$_[0]})
    },
    return => Float,
};

$asinh_function = {
    name   => 'asinh',
    params => ['is_number'],
    calc   => sub {
        Float->new(asinh ${$_[0]})
    },
    return => Float,
};

$acosh_function = {
    name   => 'acosh',
    params => ['is_number'],
    calc   => sub {
        Float->new(acosh ${$_[0]})
    },
    return => Float,
};

$atanh_function = {
    name   => 'atanh',
    params => ['is_number'],
    calc   => sub {
        Float->new(atanh ${$_[0]})
    },
    return => Float,
};

$acotanh_function = {
    name   => 'acotanh',
    params => ['is_number'],
    calc   => sub {
        Float->new(acotanh ${$_[0]})
    },
    return => Float,
};

$pi_function = {
    name   => 'pi',
    params => [],
    calc   => sub {
        Float->new(pi)
    },
    return => Float
};

$str_length_function = {
    name   => 'length',
    params => ['is_string'],
    calc   => sub {
        Integer->new(length ${$_[0]})
    },
    return => Integer
};

$seq_length_function = {
    name   => 'length',
    params => ['is_array'],
    calc   => sub {
        Integer->new(scalar @{$_[0]});
    },
    return => Integer
};

$seq_last_function = {
    name => 'last',
    params => ['is_array'],
    calc => sub {
        $_[0]->[-1];
    },
    return => Record
};

$abs_int_function = {
    name => 'abs',
    params => ['is_int'],
    calc => sub {
        Integer->new(abs ${$_[0]});
    },
    return => Integer,
};

$abs_float_function = {
    name => 'abs',
    params => ['is_float'],
    calc => sub {
        Float->new(abs ${$_[0]});
    },
    return => Float
};

$substr_function = {
    name => 'substr',
    params => ['is_string', 'is_int', 'is_int'],
    calc => sub {
        String->new(substr ${$_[0]}, ${$_[1]}, ${$_[2]});
    },
    return => String,
};

$str_to_int_function = {
    name => 'integer',
    params => ['is_string'],
    calc => sub {
        Integer->new(${$_[0]});
    },
    return => Integer 
};

$float_to_int_function = {
    name => 'integer',
    params => ['is_float'],
    calc => sub {
        Integer->new(${$_[0]});
    },
    return => Integer
};

$str_to_float_function = {
    name => 'float',
    params => ['is_string'],
    calc => sub {
        Float->new(${$_[0]});
    },
    return => Float
};

$int_to_float_function = {
    name => 'float',
    params => ['is_int'],
    calc => sub {
        Float->new(${$_[0]});
    },
    return => Float
};


$int_to_str_function = {
    name => 'string',
    params => ['is_int'],
    calc => sub {
        String->new(${$_[0]});
    },
    return => String
};

$float_to_str_function = {
    name =>  'string',
    params => ['is_float'],
    calc => sub {
        String->new(${$_[0]});
    },
    return => String
};

};

use constant FUNCTIONS => [
    $cos_function,
    $sin_function,
    $tan_function,
    $cotan_function,
    $acos_function,
    $asin_function,
    $atan_function,
    $acotan_function,
    $cosh_function,
    $sinh_function,
    $tanh_function,
    $cotanh_function,
    $acosh_function,
    $asinh_function,
    $atanh_function,
    $acotanh_function,
    $pi_function,
    $str_length_function,
    $seq_length_function,
    $abs_int_function,
    $abs_float_function,
    $substr_function,
    $str_to_int_function,
    $str_to_float_function,
    $int_to_float_function,
    $int_to_str_function,
    $float_to_int_function,
    $float_to_str_function,
    $seq_last_function,
];

sub find {
    my ($name, $params) = @_;
    foreach my $f (@{FUNCTIONS()}){
        next if $f->{name} ne $name;
        my $count = @{$params};
        next if $count != scalar @{$f->{params}};
        my $r = 1;
        for(my $i = 0; $r && $i < $count; ++$i){
            my $t = $f->{params}->[$i];
            $r = $params->[$i]->$t;
        }
        return $f if $r;
    }
    return undef;
}

1;