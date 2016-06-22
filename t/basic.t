use strict;
use warnings;
use Test::More;

use File::Temp qw(tempdir);
use IO::File;
use Git::Wrapper;
use File::Spec;
use File::Path qw(mkpath);
use POSIX qw(strftime);
use Sort::Versions;
use Test::Deep;
use Test::Exception;

my $dir = tempdir(CLEANUP => 1);

my $git = Git::Wrapper->new($dir);

my $version = $git->version;
if ( versioncmp( $git->version , '1.5.0') eq -1 ) {
  plan skip_all =>
    "Git prior to v1.5.0 doesn't support 'config' subcmd which we need for this test."
}

diag( "Testing git version: " . $version );

$git->init; # 'git init' also added in v1.5.0 so we're safe

$git->config( 'user.name'  , 'Test User'        );
$git->config( 'user.email' , 'test@example.com' );

# make sure git isn't munging our content so we have consistent hashes
$git->config( 'core.autocrlf' , 'false' );
$git->config( 'core.safecrlf' , 'false' );

mkpath(File::Spec->catfile($dir, 'foo'));

IO::File->new(File::Spec->catfile($dir, qw(foo bar)), '>:raw')->print("hello\n");

is_deeply(
  [ $git->ls_files({ o => 1 }) ],
  [ 'foo/bar' ],
);

$git->add('.');
is_deeply(
  [ $git->ls_files ],
  [ 'foo/bar' ],
);

SKIP: {
  skip 'testing old git without porcelain' , 1 unless $git->supports_status_porcelain;

  is( $git->status->is_dirty , 1 , 'repo is dirty' );
}

my $time = time;
$git->commit({ message => "FIRST\n\n\tBODY\n" });

SKIP: {
  skip 'testing old git without porcelain' , 1 unless $git->supports_status_porcelain;

  is( $git->status->is_dirty , 0 , 'repo is clean' );
}

my @rev_list =
  $git->rev_list({ all => 1, pretty => 'oneline' });
is(@rev_list, 1);
like($rev_list[0], qr/^[a-f\d]{40} FIRST$/);

my $args = $git->supports_log_raw_dates ? { date => 'raw' } : {};
my @log = $git->log( $args );
is(@log, 1, 'one log entry');

my $log = $log[0];
is($log->id, (split /\s/, $rev_list[0])[0], 'id');
is($log->message, "FIRST\n\n\tBODY\n", "message");

throws_ok { $git->log( "--format=%H" ) } q{Git::Wrapper::Exception};

SKIP: {
  skip 'testing old git without raw date support' , 1
    unless $git->supports_log_raw_dates;

  my $log_date = $log->date;
  $log_date =~ s/ [+-]\d+$//;
  cmp_ok(( $log_date - $time ), '<=', 5, 'date');
}

SKIP:
{
  skip 'testing old git without no abbrev commit support' , 1
    unless $git->supports_log_no_abbrev_commit;

  $git->config( 'log.abbrevCommit', 'true' );

  @log = $git->log( $args );

  $log = $log[0];
  is($log->id, (split /\s/, $rev_list[0])[0], 'id');
}

SKIP:
{
  if ( versioncmp( $git->version , '1.6.3') eq -1 ) {
    skip 'testing old git without log --oneline support' , 3;
  }

  throws_ok { $git->log('--oneline') } qr/^unhandled/ , 'log(--oneline) dies';

  my @lines;
  lives_ok { @lines = $git->RUN('log' , '--oneline' ) } 'RUN(log --oneline) lives';
  is( @lines , 1 , 'one log entry' );
}

my @raw_log = $git->log({ raw => 1 });
is(@raw_log, 1, 'one raw log entry');

SKIP: {
  if ( $^O eq "MSWin32" ) {
    skip 'testing file permissions on Windows is unreliable; see also core.filemode', 1;
  }

  my $onemodif = $raw_log[0];
  my $excepted_mod = Git::Wrapper::File::RawModification->new(
    "foo/bar","A",'000000','100644','0000000000000000000000000000000000000000','ce013625030ba8dba906f756967f9e9ca394464a'
  );
  cmp_deeply($onemodif->modifications, $excepted_mod) or diag explain $onemodif->modifications, ' vs ', explain $excepted_mod;

  $git->RUN('mv', 'foo/bar', 'foo/bar-moved');
  $git->commit({ message => "move a file" });
  @raw_log = $git->log({ raw => 1, follow => 1 }, '-n1', '--', 'foo/bar-moved');
  is(@raw_log, 1, 'one raw log entry');
  ( $onemodif ) = $raw_log[0]->modifications;
  is $onemodif->score(), 100;
  is $onemodif->type(), 'R';
}

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

my $commit_count = 2;

SKIP: {
    if ( versioncmp( $git->version , '1.7.0.5') eq -1 ) {
      skip 'testing old git without commit --allow-empty-message support' , 1;
    }

    # Test empty commit message
    IO::File->new(">" . File::Spec->catfile($dir, qw(second_commit)))->print("second_commit\n");
    $git->add('second_commit');

    # If this fails there's a distinct danger it will hang indefinitely
    my $timeout = _timeout { $git->commit };
    ok !$timeout && $@, 'Attempt to commit interactively fails quickly'
        or diag "Timed out!";

    $timeout = _timeout {
      $git->commit({ message => "", 'allow-empty-message' => 1 });
    };

    if ( $@ && !$timeout ) {
      my $msg = substr($@,0,50);
      skip $msg, 1;
    }

    @log = $git->log();
    is(@log, 3, 'two log entries, one with empty commit message');
    $commit_count++;
};

my @out = $git->RUN('log','--format=%H');
cmp_ok scalar @out, '==', $commit_count, q{using RUN('log','--format=%H') to get all 2 commit SHAs};

# test --message vs. -m
my @arg_tests = (
    ['message', 'long_arg_no_spaces',   'long arg, no spaces in val',  ],
    ['message', 'long arg with spaces', 'long arg, spaces in val',     ],
    ['m',       'short_arg_no_spaces',  'short arg, no spaces in val', ],
    ['m',       'short arg w spaces',   'short arg, spaces in val',    ],
);

my $arg_file = IO::File->new('>' . File::Spec->catfile($dir, qw(argument_testfile)));

for my $arg_test (@arg_tests) {
    my ($flag, $msg, $descr) = @$arg_test;

    $arg_file->print("$msg\n");
    $git->add('argument_testfile');
    $git->commit({ $flag => $msg });

    my ($arg_log) = $git->log('-n 1');

    is $arg_log->message, "$msg\n", "argument test: $descr";
}

$git->checkout({b => 'new_branch'});

my ($new_branch) = grep {m/^\*/} $git->branch;
$new_branch =~ s/^\*\s+|\s+$//g;

is $new_branch, 'new_branch', 'new branch name is correct';

SKIP: {
  skip 'testing old git without no-filters' , 1 unless $git->supports_hash_object_filters;

  my ($hash) = $git->hash_object({
    no_filters => 1,
    stdin      => 1,
    -STDIN     => 'content to hash',
  });
  is $hash, '4b06c1f876b16951b37f4d6755010f901100f04e',
    'passing content with -STDIN option';
}

done_testing();
