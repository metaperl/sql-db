use strict;
use warnings;
use Test::More tests => 16;
BEGIN {
    use_ok('SQL::DB::Table');
}
require_ok('t/Schema.pm');


can_ok('SQL::DB::Table', qw(
    new
    setup_schema
    setup_table
    setup_class
    setup_columns
    setup_primary
    setup_unique
    setup_index
    setup_foreign
    setup_type
    setup_engine
    setup_default_charset
    setup_tablespace
    name
    class
    columns
    column_names
    column
    primary_columns
    schema
    sql_create_table
    sql_create_indexes
    sql_create
));

my $table = SQL::DB::Table->new(@{Schema->Artist});
isa_ok($table, 'SQL::DB::Table');
like($table->name, qr/artists/, 'name');
ok($table->columns, 'columns');

my @cols = $table->columns;
ok(@cols == 2, '2 columns');
isa_ok($cols[0], 'SQL::DB::Column');

my @colnames = $table->column_names;
ok(@colnames == 2, '2 column names');
ok($colnames[0] eq 'name', 'First col is name?');

isa_ok($table->column('name'), 'SQL::DB::Column');
ok($table->column('name')->name eq 'name', 'Column name is name.');

like($table->sql_create_table, qr/CREATE TABLE artists/, 'SQL');
like($table->sql_create_table, qr/PRIMARY KEY/, 'SQL');
like($table->sql_create_table, qr/UNIQUE/, 'SQL');


my $cd = SQL::DB::Table->new(@{Schema->CD});
$cd->column('artist')->references($table->column('id'));

is($cd->column('artist')->references, $table->column('id'), 'references');

