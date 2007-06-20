use strict;
use warnings;
use Test::More;
use Scalar::Util qw(refaddr);

BEGIN {
    if (!eval {require DBD::SQLite;1;}) {
        plan skip_all => "DBD::SQLite not installed: $@";
    }
    else {
        plan tests => 4;
    }

}

use_ok('SQL::DB');
require_ok('t/testlib/Schema.pm');

$SQL::DB::DEBUG = 1;

our $schema;
$schema = SQL::DB::Schema->new(Schema->get) unless($schema);

isa_ok($schema, 'SQL::DB::Schema', 'Schema');

our $db = SQL::DB->connect(
#    "dbi:SQLite:/tmp/sqldb$$.db",undef,undef,
    'dbi:Pg:dbname=test;port=5433', 'rekudos', 'rekudos',
    {PrintError => 0, RaiseError => 1},
    $schema,
) unless($db);

isa_ok($db, 'SQL::DB', 'DB');

$db->deploy;

my $arow = $db->arow('tracks');
$db->delete(
    columns => [$arow->id],
);
$arow = $db->arow('cds');
$db->delete(
    columns => [$arow->id],
);
$arow = $db->arow('artists');
$db->delete(
    columns => [$arow->id],
#        where => $arow->id == 4,
);

while (my $str = <DATA>) {
    chomp($str);
    my @values = split(',',$str);

    my $rem = $db->arow(shift @values);

    my $q = $db->insert(
            columns => [$rem->_columns],
            values  => [@values],
    );
}

my $track = $db->arow('tracks');

my @objs = $db->select(
    columns   => [ $track->id,$track->title,
                  $track->cd->year,$track->cd->artist->name ],
    distinct => 1,
    where    => ( $track->length < 248 ) &
              ! ($track->cd->year > 1997), #&
#                  $track->title->like('%Life%'),
    order_by => [ $track->title ],
#    limit => '2',
);

#  print $query,"\n";

foreach my $obj (@objs) {
    print $obj->id,', ',$obj->title,', ',$obj->name,"\n";
}

@objs = $db->select(
    columns   => [ $track->id->func('count'), $track->length->func('max') ],
    where     =># ( $track->length < 248 ) &
                 ! ($track->cd->year > 1997),
);

#  print $query,"\n";

foreach my $obj (@objs) {
    print 'Track Count: '. $obj->count_id ."\n";
    print 'Max length: ' . $obj->max_length ."\n";
}



my $cd = $db->arow('cds');
$db->update(
    columns => [$cd->year],
    set     => [2006],
    where    => $cd->id == 10,
);

my $q =  $schema->select(
    columns   => [ $track->id,$track->title,
                  $track->cd->year,$track->cd->artist->name ],
    distinct => 1,
    where    => ( $track->length < 248 ) &
              ! ($track->cd->year > 1997), #&
#                  $track->title->like('%Life%'),
    order_by => [ $track->title ],
#    limit => '2',>select(
);
my $q2 =  $schema->select(
    columns   => [ $track->id->func('count'),$track->title,
                  $track->cd->year,$track->cd->artist->name ],
    distinct => 1,
    where    => ( $track->length < 248 ) &
              ! ($track->cd->year > 1997), #&
#                  $track->title->like('%Life%'),
    union => $q,
    order_by => [ $track->title ],
#    limit => '2',
);
print $q2;


END {
    unlink "/tmp/sqldb$$.db";
}
__DATA__
artists,1,Queen
artists,2,INXS
cds,1,A Kind of Magic,1986,1
cds,2,A Night at the Opera,1978,1
tracks,1,2,Death on Two Legs (Dedicated to.......),223
tracks,2,2,Lazing On A Sunday Afternoon,67
tracks,3,2,I'm in Love with My Car,187
tracks,4,2,You're My Best Friend,170
tracks,5,2,39,211
tracks,6,2,Sweet Lady,243
tracks,7,2,Seaside Rendezvous,135
tracks,8,2,The Prophet's Song,501
tracks,9,2,Love of My Life,219
tracks,10,2,Good Company,203
tracks,11,2,Bohemian Rhapsody,355
tracks,12,2,God Save the Queen,138
tracks,13,2,I'm in Love with My Car,208
tracks,14,2,You're My Best Friend,172
tracks,15,2,One Vision,310
tracks,16,2,A Kind of Magic,264
tracks,17,2,One Year of Love,266
tracks,18,2,Pain Is So Close to Pleasure,261
tracks,19,2,Friends Will Be Friends,247
tracks,20,2,Who Wants to Live Forever,305
tracks,21,2,Gimme the Prize,274
tracks,22,2,Don't Lose Your Head,278
tracks,23,2,Princes of the Universe,212
