# Copyright (C) 2015-2017 Yoann Le Garff, Nicolas Boquet and Yann Le Bras
# navel-dispatcher-manager is licensed under the Apache License, Version 2.0

#-> BEGIN

#-> initialization

use strict;
use warnings;

use ExtUtils::MakeMaker;

use File::ShareDir::Install;

#-> main

my $min_perl_version = '5.20.0';

install_share('share');

WriteMakefile(
    NAME => 'Navel::DispatcherManager',
    VERSION_FROM => 'lib/Navel/DispatcherManager.pm',
    ABSTRACT => 'navel-dispatcher-manager',
    AUTHOR => 'Yoann Le Garff, Nicolas Boquet and Yann Le Bras',
    LICENSE => 'apache_2_0',
    META_MERGE => {
        requires => {
            perl => $min_perl_version
        },
        resources => {
            license => 'http://www.apache.org/licenses/LICENSE-2.0.html',
            repository => 'http://github.com/Navel-IT/navel-dispatcher-manager'
        }
    },
    MIN_PERL_VERSION => $min_perl_version,
    PREREQ_PM => {
        'Navel::Base' => 0,
        'Navel::Base::WorkerManager' => 0,
        'Navel::Mojolicious::Plugin::Logger' => 0,
        'Navel::Mojolicious::Plugin::API::StdResponses' => 0,
        'Navel::Logger' => 0,
        'Navel::API' => 0,
        'Navel::Definition::Dispatcher' => 0,
        'Navel::Queue' => 0,
        'Navel::Event' => 0,
        'Navel::Notification' => 0,
        'Navel::AnyEvent::Pool' => 0,
        'Promises' => 0,
        'File::ShareDir' => 0,
        'Mojolicious' => 0,
        'JSON::Validator' => 0,
        'URI' => 0,
        'AnyEvent::HTTP' => 0
    },
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 6.64,
        'File::ShareDir::Install' => 0
    },
    TEST_REQUIRES => {
        'Test::More' => 0,
        'Test::Exception' => 0,
        'Test::Mojo' => 0
    },
    EXE_FILES => [
        'bin/navel-dispatcher-manager'
    ],
    test => {
        TESTS => 't/*.t'
    }
);

package MY;

use File::ShareDir::Install 'postamble';

#-> END

__END__
