class webserver::website (
  Array[String] $urls             = [],
  $website_name                   = $title,
  $unix_user                      = undef,
  $unix_password                  = undef,
  Boolean $default                = false,
  Boolean $https                  = false,
  Optional[String] $ssl_cert      = undef,
  Optional[String] $ssl_key       = undef,
  Optional[String] $unix_group    = $unix_user,
  String $db_user                 = undef,
  String $db_pass                 = undef,
  Optional[String] $db_name       = undef,
  Optional[String] $db_host       = 'localhost',
  Optional[String] $path          = "/var/www/$website_name",
  Optional[String] $fpm_pool_name = "fpm",
) {


  user { $unix_user:
    ensure   => 'present',
    home     => $path,
    groups   => 'web',
    password => pw_hash($unix_password, 'SHA-512', 'mysalt')
  }

  if( size($urls) == 0 ) {
    $_urls = [$website_name]
  } else {
    $_urls = $urls
  }

  if( $default == true ) {
    $listen_options="default_server"
  } else {
    $listen_options=undef
  }
  nginx::resource::server { $website_name:
    use_default_location => false,
    server_name          => $_urls,
    www_root             => "$path/www",
    listen_port          => 80,
    listen_options       => $listen_options,
    ssl                  => false,
    ssl_cert             => false,
    try_files            => ['$uri', '$uri/', 'index.php?$args'],
    access_log           => "/var/log/nginx/$website_name/access.log",
    error_log            => "/var/log/nginx/$website_name/error.log",
  }



  if ( $https ) {
    $servers = [ "${website_name}", "${website_name}.ssl"]
    nginx::resource::server { "$website_name.ssl":
      use_default_location => false,
      server_name          => $_urls,
      www_root             => "$path/www",
      listen_port          => 443,
      ssl                  => true,
      ssl_cert             => $ssl_cert,
      ssl_key              => $ssl_key,
      try_files            => ['$uri', '$uri/', 'index.php?$args'],
      access_log           => "/var/log/nginx/${website_name}.ssl/access.log",
      error_log            => "/var/log/nginx/${website_name}.ssl/error.log",
    }
  } else {
    $servers = [ "${website_name}"]
  }

  file { "${::nginx::log_dir}/${website_name}":
    ensure => 'directory',
    mode   => $::nginx::log_mode,
    owner  => $::nginx::daemon_user,
    group  => $::nginx::log_group
  }

  file { "${path}":
    ensure => 'directory',
    mode   => '0755',
    owner  => $unix_user,
    group  => $unix_group
  }

  file { "${path}/www":
    ensure => 'directory',
    mode   => '0755',
    owner  => $unix_user,
    group  => $unix_group
  }
  if( $db_name ) {
    mysql::db { "${website_name}":
      dbname   => $db_name,
      user     => $db_user,
      password => $db_pass,
    }
  } else {
    mysql::db { "${website_name}":
      user     => $db_user,
      password => $db_pass,
    }
  }

  /* generating locations */
  $servers.each | String $serverName | {

    nginx::resource::location { "${serverName}.htaccess":
      index_files   => [],
      server        => $serverName,
      location      => '~ \.htaccess$',
      location_deny => ['all'],
    }
    nginx::resource::location { "${serverName}.favico":
      index_files   => [],
      server        => $serverName,
      location      => '/favicon.ico',
      log_not_found => 'off',
      access_log    => 'off'
    }

    nginx::resource::location { "${serverName}.robots.txt":
      index_files   => [],
      server        => $serverName,
      location      => '/robots.txt',
      log_not_found => 'off',
      access_log    => 'off'
    }

    nginx::resource::location { "${serverName}.php":
      index_files => [],
      server      => $serverName,
      location    => '~ \.php$',
      fastcgi     => $fpm_pool_name,
    }
  }
}
