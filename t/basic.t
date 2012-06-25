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

unless ( Git::Wrapper->has_git_in_path ) {
  diag 'EXITING TESTS due to lack of installed git in $PATH.';
  SKIP: {skip 'no git in $PATH',1;}
  done_testing();
  exit();
}

my $dir = tempdir(CLEANUP => 1);

my $git = Git::Wrapper->new($dir);

diag( "Testing git version: " . $git->version );

$git->init;

$git->config( 'user.name'  , 'Test User'        );
$git->config( 'user.email' , 'test@example.com' );

mkpath(File::Spec->catfile($dir, 'foo'));

IO::File->new(">" . File::Spec->catfile($dir, qw(foo bar)))->print("hello\n");

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

SKIP: {
  skip 'testing old git without raw date support' , 1
    unless $git->supports_log_raw_dates;

  my $log_date = $log->date;
  $log_date =~ s/ [+-]\d+$//;
  cmp_ok(( $log_date - $time ), '<=', 5, 'date');
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

SKIP: {
    # Test empty commit message
    IO::File->new(">" . File::Spec->catfile($dir, qw(second_commit)))->print("second_commit\n");
    $git->add('second_commit');
    eval {
      $git->commit({ message => "", 'allow-empty-message' => 1 });
    };

    if ( $@ ){
      my $msg = substr($@,0,50);
      skip $msg, 1;
    }

    @log = $git->log();
    is(@log, 2, 'two log entries, one with empty commit message');
};


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

my ($hash) = $git->hash_object({ no_filters => 1, stdin => 1, -STDIN => 'content to hash' });
is $hash, '4b06c1f876b16951b37f4d6755010f901100f04e', 'passing content with -STDIN option';

done_testing();
