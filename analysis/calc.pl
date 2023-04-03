use DBI;
use strict;
use warnings;

STDOUT->autoflush(1);

my $dbfile = "/home/elimtob/Workspace/mymemtrace/traces/imagick_r-test.db";

my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","") || die "Noope";

my $stmt = $dbh->prepare("SELECT SUM(REFS) from ROW_COUNT");
$stmt->execute();
my $ans = $stmt->fetch;
my $rows = $$ans[0];
print("Total number of rows: $rows\n");

$stmt = $dbh->prepare("select ADDR >> 6 from MEMREFS;");
$stmt->execute();

my %hist   = ();
my $kmin   = 0;
my $max    = 0;
my $count  = 0;
my $gcount = 0;
$hist{$kmin} = $rows;

while (my $ans = $stmt->fetch) {
    my $cl = $$ans[0];
    if (exists($hist{$cl})) {
        $hist{$cl}++;
    } else {
        $hist{$cl} = 1;
        $count++;
    }
    $max = $hist{$cl} unless $max >= $hist{$cl};
    $kmin = $cl unless $hist{$kmin} <= $hist{$cl};
    $gcount++;
    printf(" %6.2f%% done\r", $gcount / $rows * 100) if $gcount % 10000 == 0;
}
print("\n");
print("Max = $max, Min = $hist{$kmin}, Total = $count\n");
