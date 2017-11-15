class webserver::package {


  include apt

  apt::source { 'mariadb':
    location => 'http://mirror.klaus-uwe.me/mariadb/repo/10.2/ubuntu',
    release  => $::lsbdistcodename,
    repos    => 'main',
    key      => {
      id     => '177F4010FE56CA3336300305F1656F24C74CD1D8',
      server => 'hkp://keyserver.ubuntu.com:80',
    },
    include  => {
      src => false,
      deb => true,
    },
  }

  class { '::mysql::server':
    package_name     => 'mariadb-server',
    #    package_ensure   => '10.1.14+maria-1~trusty',
    service_name     => 'mysql',
    root_password    => 'rYeNumJJaL5PbT',
    override_options => {
      mysqld      => {
        'log-error' => '/var/log/mysql/mariadb.log',
        'pid-file'  => '/var/run/mysqld/mysqld.pid',
      },
      mysqld_safe => {
        'log-error' => '/var/log/mysql/mariadb.log',
      },
    }
  }

  # Dependency management. Only use that part if you are installing the repository
  # as shown in the Preliminary step of this example.
  Apt::Source['mariadb'] ~>
  Class['apt::update'] ->
  Class['::mysql::server']

  class { '::mysql::client':
    package_name    => 'mariadb-client',
    #    package_ensure  => '10.1.14+maria-1~trusty',
    bindings_enable => true,
  }

  # Dependency management. Only use that part if you are installing the repository as shown in the Preliminary step of this example.
  Apt::Source['mariadb'] ~>
  Class['apt::update'] ->
  Class['::mysql::client']

  class { '::php::globals':
    php_version => '7.0',
  }

  class { '::php':
    ensure       => 'latest',
    manage_repos => true,
    fpm          => true,
    fpm_pools    => {
      'www' => { listen => '/var/run/php7.0-fpm-www.sock', }
    },
    dev          => false,
    extensions   => {
      imagick       => {
        provider       => 'apt',
        package_prefix => 'php-',
      },
      readline      => {
        provider       => 'apt',
        package_prefix => 'php-',
      },
      curl          => {
        provider       => 'apt',
        package_prefix => 'php-',
      },
      gd            => {
        provider       => 'apt',
        package_prefix => 'php-',
      },
      console-table => {
        provider       => 'apt',
        package_prefix => 'php-',
      },
      memcached     => {
        provider       => 'apt',
        package_prefix => 'php-',
      },
      mcrypt        => {
        provider       => 'apt',
        package_prefix => 'php-',
      },
      igbinary      => {
        provider       => 'apt',
        package_prefix => 'php-',
      },
    }
  }

  # nginx
  class { 'nginx':
    manage_repo            => true,
    package_source         => 'nginx-stable',
    names_hash_bucket_size => 128,
    server_tokens          => 'off',
    gzip                   => 'on',
    gzip_disable           => 'msie6',
    gzip_http_version      => '1.1',
    gzip_vary              => 'on',
    gzip_proxied           => 'any',
    gzip_types             =>
      'text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/x-icon application/vnd.ms-fontobject font/opentype application/x-font-ttf'
  }

  nginx::resource::upstream { 'fpm':
    members => [
      'unix:/var/run/php7.0-fpm-www.sock',
    ]
  }


}

