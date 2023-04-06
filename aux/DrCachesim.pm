package DrCachesim;

use strict;
use warnings;

our $drdir="/home/elimtob/.local/opt/DynamoRIO";

sub new_cache {
   my $class = "cache";
   # NOTE: keys that do not map to references need to be exact DrCachesim config params
   # TODO how to use named params
   my $self = {
        type           => undef,
        core           => 0,
        size           => undef,
        assoc          => undef,
        inclusive      => undef,
        parent         => undef,
        prefetcher     => "none",
        replace_policy => "LRU",
        stats          => {
            "Hits"              => undef,
            "Misses"            => undef,
            "Compulsory misses" => undef,
            "Invalidations"     => undef,
            "Miss rate"         => undef,
            "Local miss rate"   => undef,
            "Child hits"        => undef,
            "Total miss rate"   => undef,
       }
   };
   bless $self, $class;
   return $self;
}

sub new_hierarchy {
   my $class = "hierarchy";
   my $self = {
        L1I => new_cache(),
        L1D => new_cache(),
        L2  => new_cache(),
        L3  => new_cache(),
   };
   bless $self, $class;
   return $self;
}

sub parse_results {
    my $H   = shift;
    my $cmd = shift;
    $cmd    = "cat aux/csim_res.txt";
    open(my $cmdout, '-|', $cmd) or die "Didn't work mate: $!";
    
    my $state = 0;
    my $c;
    while (my $l = <$cmdout>) {
        #print $l;
        if ($state == 0 && $l =~ /---- <application exited with code (\d+)> ----/) {
            die "App exited with error!\n" unless $1 == 0; # on nonzero exit code
            $state = 1;
        } elsif ($state == 1) {
            ($c) = $l =~ /\s*(L1I|L1D|L2|L3) stats:/;
            $state = 2 if $c;
        } elsif ($state == 2) {
            if ($l =~ /\s*(L1I|L1D|L2|L3) stats:/) {
                $c = $1;
                next;
            }
            my ($k, $v) = $l =~ s/(\d),(\d)/$1$2/r =~ /\s+([\w\s]+):\s+([\d.]+)%?/;
            #print "k=$k, v=$v\n";
            die "Regex matching failed\n" if $k eq "" || $v eq "";
            $$H{$c}->{stats}->{$k} = $v;
        }
    }
}

use File::Temp qw/ tempfile /;
sub create_cfg {
    my $H      = shift;
    my $tmpdir = "/tmp";
    #TODO enable real file output
    #my ($fh, $fname) = tempfile(DIR => "/tmp");

    my @C = ();
    my $params = qq#
        num_cores 1
    #;
    push @C, $params;

    foreach my $lvl (keys(%$H)) {
        my $c  = $H->{$lvl};
        my $kv = ();
        foreach my $k (keys(%$c)) {
            my $v = $c->{$k};
            # skip keys that map to references like "stats"
            next unless defined $v and ref $v eq "";
            print "k=$k, v=$v\n";
            push @$kv, "\t$k $v";
        }
        $kv = join "\n", @$kv;
        my $l = qq#
            $lvl {
                $kv
            }
        #;
        push @C, $l;
        #print "lvl=$lvl\n$l\n";
    }
    my $cfg = join "", @C;
    $cfg =~ s/ {2,}/ /g;
    print "$cfg\n";
}
