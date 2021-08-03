class webserver::package {


  include apt

  group { 'web':
    ensure => 'present',
    gid    => '502',
  }

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
    root_password    => $webserver::db_root_password,
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
    php_version => $webserver::php_version,
  }



  if( $webserver::fpm_pools ) {
    $fpm_pools = deep_merge( $default_fpm_pools, $webserver::fpm_pools)
  } else {
    $fpm_pools = $webserver::params::default_fpm_pools
  }

  package { 'imagemagick':
    ensure => 'installed'
  }

  class { '::php':
    ensure       => 'installed',
    manage_repos => true,
    fpm          => true,
    fpm_pools    => $fpm_pools,
    dev          => false,
    extensions   => {
      imagick       => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      readline      => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      curl          => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      gd            => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      console-table => {
        provider       => 'apt',
        package_prefix => "php-",
      },
      memcached     => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      #mcrypt        => {
      #  provider       => 'apt',
      #  package_prefix => "php-",
      #},
      #xml           => {
      #  provider       => 'apt',
      #  package_prefix => "php${::php::globals::php_version}-",
      #},
      mbstring           => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      igbinary      => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
    }
  }

  $http_preprend_config={
    limit_req_zone => '$binary_remote_addr zone=limitedrate:10m rate=2r/s',
    fastcgi_buffers => '16 16k',
    fastcgi_buffer_size => '32k'
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
      'text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/x-icon application/vnd.ms-fontobject font/opentype application/x-font-ttf',
    http_cfg_prepend      => $http_preprend_config
  }

  nginx::resource::upstream { 'fpm':
    members => {
      'unix:/var/run/php7.0-fpm-www.sock' => {
        server => 'unix:/var/run/php7.0-fpm-www.sock'
      },
    }  
    
  }

  nginx::resource::upstream { 'fpm7.2':
    members => {
      'unix:/var/run/php7.2-fpm-www.sock' => {
        server => 'unix:/var/run/php7.2-fpm-www.sock'
      },
    }  
    
  }

  nginx::resource::upstream { 'fpm7.3':
    members => {
      'unix:/var/run/php7.3-fpm-www.sock' => {
        server => 'unix:/var/run/php7.3-fpm-www.sock'
      },
    }  
  }

  file { "/var/www":
    ensure => 'directory',
    mode   => '0755',
    owner => 'root',
    group => 'web'
  }
}

