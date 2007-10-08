package SQL::DB::Row;
use strict;
use warnings;
use Carp qw(croak);
use constant ORIGINAL => 0;
use constant MODIFIED => 1;
use constant STATUS   => 2;


sub make_class_from {
    my $proto = shift;
    @_ || croak 'make_class_from() requires arguments';

    my @methods;
    my @tablecolumns;
    foreach my $obj (@_) {
        my $method;
        my $set_method;
        if (UNIVERSAL::can($obj, '_column')) {        # AColumn
            ($method = $obj->_as) =~ s/^t\d+\.//;
            $set_method = 'set_'. $method;
            push(@methods, [$method, $set_method, $obj->_column]);
            push(@tablecolumns, $obj->_column->table->name .'.'. $obj->_column->name);
        }
        elsif (UNIVERSAL::can($obj, 'table')) {      # Column
            $method = $obj->name;
            $set_method = 'set_'. $method;
            push(@methods, [$method, $set_method, $obj]);
            push(@tablecolumns, $obj->table->name .'.'. $obj->name);
        }
        elsif (UNIVERSAL::can($obj, '_as')) {         # Expr
            $method = $obj->_as;
            push(@methods, [$method, undef, undef]);
            push(@tablecolumns, $method);
        }
        else {
            croak 'MultiRow takes AColumns, Columns or Exprs: '. ref($obj);
        }
    }

    my $class = $proto .'::'. join('_', @tablecolumns);

    no strict 'refs';
    my $isa = \@{$class . '::ISA'};
    if (defined @{$isa}) {
        return $class;
    }
    push(@{$isa}, $proto);


    my $defaults = {};

    my $i = 0;
    foreach my $def (@methods) {
        # index/position in array
        ${$class.'::_index_'.$def->[0]} = $i;
        push(@{$class.'::_columns'}, $def->[2]);

        if (UNIVERSAL::isa($def->[2], 'SQL::DB::Schema::Column')) {
            if ($def->[2]->inflate) {
                push(@{$class.'::_inflate'}, $i);
                *{$class.'::_inflate'.$i} = $def->[2]->inflate;
            }
            if ($def->[2]->deflate) {
                push(@{$class.'::_deflate'}, $i);
                *{$class.'::_deflate'.$i} = $def->[2]->deflate;
            }
            if (defined $def->[2]->default) {
                $defaults->{$def->[0]} = $def->[2]->default;
            }
        }

        # accessor
        *{$class.'::'.$def->[0]} = sub {
            my $self = shift;
            my $pos  = ${$class.'::_index_'.$def->[0]};
            return $self->[$self->[STATUS]->[$pos]]->[$pos];
        };

        # modifier
        if ($def->[1]) {
            *{$class.'::'.$def->[1]} = sub {
                my $self = shift;
                if (!@_) {
                    croak $def->[1] . ' requires an argument';
                }
                my $pos  = ${$class.'::_index_'.$def->[0]};
                $self->[STATUS]->[$pos] = 1;
                $self->[MODIFIED]->[$pos] = shift;
                return;
            };
        }
        $i++;
    }


    *{$class.'::new_from_arrayref'} = sub {
        my $proto      = shift;
        my $finalclass = ref($proto) || $proto;

        my $valref = shift ||
            croak 'new_from_arrayref requires ARRAYREF argument';
        ref($valref) eq 'ARRAY' ||
            croak 'new_from_arrayref requires ARRAYREF argument';

        my $self  = [
            $valref,                   # ORIGINAL
            [],                        # MODIFIED
            [map {ORIGINAL} (1..scalar @methods)], # STATUS
        ];
    
        bless($self, $finalclass);
        return $self;
    };


    *{$class.'::new'} = sub {
        my $proto = shift;
        my $incoming;


        if (ref($_[0]) and ref($_[0]) eq 'HASH') {
            $incoming = shift;
        }
        else {
            $incoming = {@_};
        }

        my $hash  = {};
        map {$hash->{$_} = $defaults->{$_}} keys %$defaults;
        map {$hash->{$_} = $incoming->{$_}} keys %$incoming;

        my @array = ();
        while (my ($key,$val) = each %$hash) {
            my $i = ${$class.'::_index_'.$key};
            if (defined($i)) {
                if (ref($val) and ref($val) eq 'CODE') {
                    $array[$i] = &$val;
                }
                else {
                    $array[$i] = $val;
                }
            }
        }

        my $self = $class->new_from_arrayref(\@array);

        my $finalclass = ref($proto) || $proto;
        bless($self, $finalclass);
        return $self;
    };


    *{$class.'::q_insert'} = sub {
        my $self = shift;
        $self->_deflate;

        my @cols = @{$class .'::_columns'};
        
        my $arows   = {};
        my $columns = {};
        my $values  = {};

        my $i = 0;
        foreach my $col (@cols) {
            next unless($col);
            my $status = $self->[STATUS]->[$i];

            my $colname = $col->name;
            my $tname   = $col->table->name;

            if (!exists($arows->{$tname})) {
                $arows->{$tname}   = $col->table->arow();
                $columns->{$tname} = [];
                $values->{$tname}  = [];
            }

            push(@{$columns->{$tname}}, $arows->{$tname}->$colname);
            push(@{$values->{$tname}}, $self->[$status]->[$i]);

            $i++;
        }

        my @queries;
        foreach my $tname (keys %{$columns}) {
            next unless(@{$columns->{$tname}});
            push(@queries, [
                insert => $columns->{$tname},
                values => $values->{$tname},
            ]);
        }
        $self->_inflate;
        return @queries;
    };


    *{$class.'::q_update'} = sub {
        my $self = shift;
        $self->_deflate;

        my @cols = @{$class .'::_columns'};
        
        my $arows   = {};
        my $updates = {};
        my $where   = {};

        my $i = 0;
        foreach my $col (@cols) {
            next unless($col);

            my $colname = $col->name;
            my $tname   = $col->table->name;

            if (!exists($arows->{$tname})) {
                $arows->{$tname}   = $col->table->arow();
                $updates->{$tname} = [],
            }

            if ($col->primary and !$where->{$tname}) {
                $where->{$tname} =
                   ($arows->{$tname}->$colname == $self->[ORIGINAL]->[$i]);
            }
            elsif ($col->primary) {
                $where->{$tname} =
                    ($where->{$tname} &
                    ($arows->{$tname}->$colname == $self->[ORIGINAL]->[$i]));
            }

            if ($self->[STATUS]->[$i] == MODIFIED) {
                push(@{$updates->{$tname}},
                    $arows->{$tname}->$colname->set($self->[MODIFIED]->[$i])
                );
            }
            $i++;
        }

        my @queries;
        foreach my $table (keys %{$updates}) {
            next unless(@{$updates->{$table}});
            push(@queries, [
                update => $updates->{$table},
                ($where->{$table} ? (where  => $where->{$table}) : ()),
            ]);
        }
        $self->_inflate;
        return @queries;
    };

    return $class;
}



sub _inflate {
    my $self = shift;
    my $class = ref($self);

    no strict 'refs';
    foreach my $i (@{$class .'::_inflate'}) {
        my $inflate = *{$class .'::_inflate'.$i};
        $self->[$self->[STATUS]->[$i]]->[$i] =
            &$inflate($self->[$self->[STATUS]->[$i]]->[$i]);
    }
    return $self;
}


sub _deflate {
    my $self = shift;
    my $class = ref($self);

    no strict 'refs';
    foreach my $i (@{$class .'::_deflate'}) {
        my $deflate = *{$class .'::_deflate'.$i};
        $self->[$self->[STATUS]->[$i]]->[$i] =
            &$deflate($self->[$self->[STATUS]->[$i]]->[$i]);
    }
    return $self;
}



1;
__END__


=head1 NAME

SQL::DB::Row - description

=head1 SYNOPSIS

  use SQL::DB::Row;

=head1 DESCRIPTION

B<SQL::DB::Row> is ...

=head1 METHODS

=head2 make_class_from


=head2 new_from_arrayref

Create a new object from values contained a reference to an ARRAY. The
array values must be in the same order as the definition of the class.

=head2 new



=head2 _inflate



=head2 _deflate



=head1 FILES



=head1 SEE ALSO

L<Other>

=head1 AUTHOR

Mark Lawrence E<lt>nomad@null.netE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 Mark Lawrence <nomad@null.net>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

=cut

# vim: set tabstop=4 expandtab:
