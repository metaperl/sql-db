use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 10;
use Test::Exception;
use Test::Memory::Cycle;
use SQL::DB::Schema;

can_ok('SQL::DB::Schema', qw(new add tables table));

my $schema = SQL::DB::Schema->new;
isa_ok($schema, 'SQL::DB::Schema');

my @table = (
    table => 'persons',
    columns => [
        [ name => 'id', primary => 1, type => 'integer'],
        [ name => 'name', type => 'varchar'],
    ],
);

my @table2 = (
    table => 'addresses',
    columns => [
        [ name => 'id', primary => 1, type => 'integer'],
        [ name => 'city', type => 'varchar'],
    ],
);

my $table = $schema->add(@table);
isa_ok($table, 'SQL::DB::Table');

ok($schema->add(\@table2));

isa_ok($schema->table('persons'), 'SQL::DB::Table');
is($schema->table('persons'), $table, 'Table match');

throws_ok {
    $schema->table('notexist');
} qr/not associated with/;

is($schema->tables, 2, 'tables size');
isa_ok(($schema->tables)[0], 'SQL::DB::Table');

memory_cycle_ok($schema, 'memory cycle');


__END__

use strict;
use warnings;
use lib 't/lib';
use Test::More tests => 87;
use Test::Exception;
use Test::Memory::Cycle;
use SQL::DB::Test::Schema;
use SQL::DB::Schema;

# Class and Object methods
can_ok('SQL::DB::Schema', qw(define_tables new tables table arow acol query));

# Functions
can_ok('SQL::DB::Schema', qw/
    coalesce
    count
    max
    min
    sum
    LENGTH
    cast
    upper
    lower
    case
    EXISTS
    now
    nextval
    currval
    setval
/);

SQL::DB::Schema->import(qw/
    coalesce
    count
    max
    min
    sum
    LENGTH
    cast
    upper
    lower
    case
    EXISTS
    now
    nextval
    currval
    setval
/);


throws_ok {
    SQL::DB::Schema->new('unknown');
} qr/not been defined/;


my $s = SQL::DB::Schema->new('artists');
isa_ok($s, 'SQL::DB::Schema', '->new empty');
memory_cycle_ok($s, 'schema memory');

my $artist = $s->table('artists')->arow;
isa_ok($artist, 'SQL::DB::Schema::ARow::artists');


foreach my $t (
    [coalesce('col1', 'col2')->as('col'),
        'COALESCE(col1, col2) AS col' ],
    [count('*'),
        'COUNT(*)'],
    [count('id')->as('count_id'),
        'COUNT(id) AS count_id'],
    [max('length'),
        'MAX(length)'],
    [max('length')->as('max_length'),
        'MAX(length) AS max_length'],
    [min('length'),
        'MIN(length)'],
    [min('length')->as('min_length'),
        'MIN(length) AS min_length'],
    [sum('length'),
        'SUM(length)'],
    [sum('length')->as('sum_length'),
        'SUM(length) AS sum_length'],
    [LENGTH('length'),
        'LENGTH(length)'],
    [LENGTH('length')->as('length_length'),
        'LENGTH(length) AS length_length'],
    [cast($artist->name->as('something')),
        'CAST(artists1.name AS something)'],
    [upper('length'),
        'UPPER(length)'],
    [lower('length'),
        'LOWER(length)'],
    [EXISTS('something'),
        'EXISTS(something)'],
    [case('col',when => 'x', then => 1),
        'CASE col WHEN ? THEN ? END'],
    [case('col',when => 'x', then => 1, when => 'y', then => 2),
        'CASE col WHEN ? THEN ? WHEN ? THEN ? END'],
    [case('col',when => 'x', then => 1, else => '2'),
        'CASE col WHEN ? THEN ? ELSE ? END'],
    [case('col END FROM BAD WHEN COND > 1',when => 'x', then => 1),
        'CASE col WHEN ? THEN ? END'],
    [case(when => 'x', then => 1),
        'CASE WHEN ? THEN ? END'],
    [now(),
        'NOW()'],
    [now()->as('now'),
        'NOW() AS now'],
    [nextval('length'),
        "nextval('length')"],
    [currval('length'),
        "currval('length')"],
    [setval('length', 1),
        "setval('length', 1)"],
    [setval('length', 1, 1 ),
        "setval('length', 1, true)"],
    [setval('length', 1, 0 ),
        "setval('length', 1, false)"],

    ){

    isa_ok($t->[0], 'SQL::DB::Schema::Expr');
    is($t->[0], $t->[1], $t->[1]);
    memory_cycle_ok($t->[0], 'memory cycle');
}


__END__

my $table;

eval {$table = $sql->define};
like($@, qr/usage: define/, '->define usage');

eval {$table = $sql->define('cds')};
like($@, qr/usage: define/, '->define usage def');

eval {$sql->table('cds');};
like($@, qr/has not been defined/, '->table not defined');

eval {$sql->arow;};
like($@, qr/usage: arow/, '->arow usage');

eval {$sql->arow('Unknown');};
like($@, qr/has not been defined/, '->arow table not defined');

eval {$sql = SQL::DB::Schema->new({});};
like($@, qr/usage: new/, '->new requires arrayref');

@schema = Schema->get;
$sql = SQL::DB::Schema->new(@schema);
isa_ok($sql, 'SQL::DB::Schema', '->new with array');
isa_ok($sql->table('cds'), 'SQL::DB::Schema::Table');

@schema = Schema->get;
eval{use warnings FATAL => 'all'; $sql->define($schema[0]);};
like($@, qr/already defined/, 'redefine check');

my @many = $sql->table('artists')->has_many;
ok(@many > 0, 'Artists has many something');
isa_ok($many[0],'SQL::DB::Schema::Column', 'Artists has many');


