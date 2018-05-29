use strict;
use warnings;
use Test::More;

use File::Temp qw(tempdir);
use Git::Wrapper;
use Sort::Versions;
use Test::Exception;
use File::Spec;
use Cwd qw/abs_path/;

my $DO_WIN32_GETLONGPATHNAME = ($^O eq 'MSWin32') ? eval 'use Win32; 1' : 0;

eval "use Path::Class 0.26; 1" or plan skip_all =>
    "Path::Class 0.26 is required for this test.";

my $tmpdir = File::Spec->tmpdir;
$tmpdir = Win32::GetLongPathName(abs_path($tmpdir)) if $DO_WIN32_GETLONGPATHNAME;
my $tempdir = tempdir(DIR => $tmpdir, CLEANUP => 1);
my $dir = Path::Class::dir($tempdir);

my $git = Git::Wrapper->new($dir);
my ($status, @statuses);

my $version = $git->version;
if ( versioncmp( $git->version , '1.5.0') eq -1 ) {
  plan skip_all =>
    "Git prior to v1.5.0 doesn't support 'init' subcmd which we need for this test."
}

diag( "Testing git version: " . $version );

$git->init;

# see https://github.com/genehack/Git-Wrapper/issues/91
$git->config('commit.gpgsign', 'false');

$git->config( 'user.name'  , 'Test User'        );
$git->config( 'user.email' , 'test@example.com' );

# make sure git isn't munging our content so we have consistent hashes
$git->config( 'core.autocrlf' , 'false' );
$git->config( 'core.safecrlf' , 'false' );

is( $git->status->is_dirty, 0, 'Git directory is clean after init' );


# New File
$dir->file('foo')->spew(iomode => '>:raw', "hello\n");
is( $git->status->is_dirty, 1, 'Git directory is dirty after new file' );

foreach my $empty_status (qw/indexed changed conflict/){
  is( $git->status->get($empty_status), 0, "Nothing is $empty_status after new file" );
}
@statuses = $git->status->get('unknown');
is( scalar @statuses, 1, 'There is one unknown after new file'      );
is( $statuses[0]->to,   '',        'To is empty after new file'     );
is( $statuses[0]->from, 'foo',     'From is foo after new file'     );
is( $statuses[0]->mode, 'unknown', 'Mode is unknown after new file' );



# Add
$git->add($tempdir);
is( $git->status->is_dirty, 1, 'Git directory is dirty after add' );

foreach my $empty_status (qw/unknown changed conflict/){
  is( $git->status->get($empty_status), 0, "Nothing is $empty_status after add" );
}
@statuses = $git->status->get('indexed');
is( scalar @statuses, 1, 'There is one indexed after add'  );
is( $statuses[0]->to,   '',      'To is empty after add'   );
is( $statuses[0]->from, 'foo',   'From is foo after add'   );
is( $statuses[0]->mode, 'added', 'Mode is added after add' );



# Commit
$git->commit({ message => 'commit 1' });
is( $git->status->is_dirty, 0, 'Git directory is clean after commit' );
foreach my $empty_status (qw/unknown indexed changed conflict/){
  is( $git->status->get($empty_status), 0, "Nothing is $empty_status after commit" );
}



# Modify
$dir->file('foo')->spew(iomode => '>:raw', "hello\nworld\n");
is( $git->status->is_dirty, 1, 'Git directory is dirty after modification' );

foreach my $empty_status (qw/unknown indexed conflict/){
  is( $git->status->get($empty_status), 0, "Nothing is $empty_status after modification" );
}
@statuses = $git->status->get('changed');
is( scalar @statuses, 1, 'There is one changed after modification'    );
is( $statuses[0]->to,   '',         'To is empty after modification'  );
is( $statuses[0]->from, 'foo',      'From is foo after modification'  );
is( $statuses[0]->mode, 'modified', 'Mode is modified after modification' );

$dir->file('foo')->spew(iomode => '>:raw', "hello\n");
is( $git->status->is_dirty, 0, 'Git directory is clean after modification test is over' );



# Rename
$dir->file('foo')->move_to("$tempdir/bar");
is( $git->status->is_dirty, 1, 'Git directory is dirty after rename' );

foreach my $empty_status (qw/indexed conflict/){
  is( $git->status->get($empty_status), 0, "Nothing is $empty_status after rename" );
}
@statuses = $git->status->get('unknown');
is( scalar @statuses, 1, 'There is one unknown after rename (new-file)'        );
is( $statuses[0]->to,   '',         'To of new-file is empty after rename'     );
is( $statuses[0]->from, 'bar',      'From of new-file is bar after rename'     );
is( $statuses[0]->mode, 'unknown',  'Mode of new-file is unknown after rename' );
@statuses = $git->status->get('changed');
is( scalar @statuses, 1, 'There is one changed after rename (old-file)'        );
is( $statuses[0]->to,   '',         'To of old-file is empty after rename'     );
is( $statuses[0]->from, 'foo',      'From of old-file is foo after rename'     );
is( $statuses[0]->mode, 'deleted',  'Mode of old-file is deleted after rename' );



# Rename - add
$git->add($tempdir);
is( $git->status->is_dirty, 1, 'Git directory is dirty after rename-add' );

foreach my $empty_status (qw/unknown changed conflict/){
  is( $git->status->get($empty_status), 0, "Nothing is $empty_status after rename-add" );
}
@statuses = $git->status->get('indexed');
is( scalar @statuses, 1, 'There is one indexed after rename-add'    );
is( $statuses[0]->to,   'bar',     'To is bar after rename-add'     );
is( $statuses[0]->from, 'foo',     'From is foo after rename-add'   );
is( $statuses[0]->mode, 'renamed', 'Mode is added after rename-add' );



# Rename - Commit
$git->commit({ message => 'commit 2' });
is( $git->status->is_dirty, 0, 'Git directory is clean after rename commit' );
foreach my $empty_status (qw/unknown indexed changed conflict/){
  is( $git->status->get($empty_status), 0, "Nothing is $empty_status after rename commit" );
}



done_testing();
