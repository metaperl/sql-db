use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 9;
use Test::Memory::Cycle;
use SQL::DB::Schema qw(define_tables);
use SQL::DB::Test::Schema;

use_ok('SQL::DB::Schema::Query');
can_ok('SQL::DB::Schema::Query', qw/
    new
    acolumns
    bind_types
    st_where
    st_insert_into
    st_insert
    st_values
    st_update
    st_select
    st_distinct
    st_for_update
    st_from
    st_on
    st_inner_join
    st_left_outer_join
    st_left_join
    st_right_outer_join
    st_right_join
    st_full_join
    st_full_outer_join
    st_cross_join
    st_union
    st_intersect
    st_group_by
    st_order_by
    st_limit
    st_offset
    st_delete
    st_delete_from
/);

my $s = SQL::DB::Schema->new(qw/artists cds/);

my $artist = $s->arow('artists');

my $q;


$q = $s->query(
    select => [$artist->id],
#    where  => $artist->id > 0 && $artist->id < 10,
);
is($q, 'SELECT
    artists1.id
', 'select');
memory_cycle_ok($q, 'memory cycle');


$q = $s->query(
    update => [$artist->id->set(4)],
);
is($q, 'UPDATE
    artists
SET
    id = ?
', 'update');
memory_cycle_ok($q, 'memory cycle');


my $acol = $s->acol('id');
$q = $s->query(
    select => [$acol],
);
is($q, 'SELECT
    id
', 'select with acol');
memory_cycle_ok($q, 'memory cycle');

my ($artists,$cds) = $s->arow(qw/artists cds/);
is($artists->_join($cds), "artists2.id = cds1.artist", '_join');
