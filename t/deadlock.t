use strict;
use warnings;
use Test::More;
use Git::Wrapper;

my $git = Git::Wrapper->new(".", git_binary => "./t/deadlock_helper.sh");

sub _timeout (&) {
    my ($code) = @_;

    my $timeout = 0;
    eval {
        local $SIG{ALRM} = sub { $timeout = 1; die "TIMEOUT\n" };
        # 5 seconds should be more than enough time to fail properly
        alarm 5;
        $code->();
        alarm 0;
    };

    return $timeout;
}

my $timeout = _timeout { $git->RUN("test", -STDIN => "test1\ntest2\n") };
is $timeout, 0, "didn't deadlock";

done_testing();
