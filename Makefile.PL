use inc::Module::Install;

name          ( 'prefork'                   );
abstract      ( 'Pragma to ensure modules are fully loaded before forking' );
author        ( 'Adam Kennedy<cpan@ali.as>' );
version_from  ( 'lib/prefork.pm'               );
license       ( 'perl'                      );

requires      ( 'perl'           => '5.005' );
requires      ( 'Scalar::Util'   => '1.10'  );

build_requires( 'Test::More'     => '0.47'  );
build_requires( 'File::Spec'     => '0.82'  );

auto_install();

&WriteAll;
