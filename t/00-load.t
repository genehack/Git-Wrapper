use Test::More tests => 5;

BEGIN {
  use_ok('Git::Wrapper::Status');
  use_ok('Git::Wrapper::Statuses');
  use_ok('Git::Wrapper::Exception');
  use_ok('Git::Wrapper::Log');
  use_ok('Git::Wrapper');
}

diag( "Testing Git::Wrapper $Git::Wrapper::VERSION" );
