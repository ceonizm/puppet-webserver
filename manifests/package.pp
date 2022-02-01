class webserver::package {


  include apt

  if( ! defined(Apt::Source[mariadb])) {
    apt::source { 'mariadb':
      location => "http://mirror.klaus-uwe.me/mariadb/repo/${webserver::params::default_mariadb_version}/ubuntu",
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
  }
  if ( $webserver::install_db_server == true ) {
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
  }

  class { '::mysql::client':
    package_name    => 'mariadb-client',
    #    package_ensure  => '10.1.14+maria-1~trusty',
    bindings_enable => false,
  }

  class { 'mysql::bindings':
    perl_enable   => false,
    python_enable => false,
    java_enable   => false,
  }
  # Dependency management. Only use that part if you are installing the repository as shown in the Preliminary step of this example.
  Apt::Source['mariadb'] ~>
  Class['apt::update'] ->
  Class['::mysql::client']


}

