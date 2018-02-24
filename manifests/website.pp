class webserver::website (
  Array[String] $urls             = [],
  $website_name                   = $title,
  $unix_user                      = undef,
  $unix_password                  = undef,
  Boolean $https                  = false,
  Optional[String] $ssl_cert      = undef,
  Optional[String] $ssl_key       = undef,
  Optional[String] $unix_group    = $unix_user,
  String $db_user                 = undef,
  String $db_pass                 = undef,
  Optional[String] $db_name       = undef,
  Optional[String] $db_host       = 'localhost',
  Optional[String] $path          = "/var/www/$title",
  Optional[String] $fpm_pool_name = "fpm",
) {


  user { $unix_user:
    ensure   => 'present',
    home     => $path,
    groups   => 'web',
    password => pw_hash($unix_password, 'SHA-512', 'mysalt')
  }

  if( size($urls) == 0 ) {
    $_urls = [$title]
  } else {
    $_urls = $urls
  }

  nginx::resource::server { $title:
    use_default_location => false,
    server_name          => $_urls,
    www_root             => "$path/www",
    listen_port          => 80,
    ssl                  => false,
    ssl_cert             => false,
    try_files            => ['$uri', '$uri/', 'index.php?$args'],
    access_log           => "/var/log/nginx/$title/access.log",
    error_log            => "/var/log/nginx/$title/error.log",
  }



  if( $https ) {

  } else {

  }
  if ( $https ) {
    $servers = [ "${title}", "${title}.ssl"]
    nginx::resource::server { "$title.ssl":
      use_default_location => false,
      server_name          => $_urls,
      www_root             => "$path/www",
      listen_port          => 443,
      ssl                  => true,
      ssl_cert             => $ssl_cert,
      ssl_key              => $ssl_key,
      try_files            => ['$uri', '$uri/', 'index.php?$args'],
      access_log           => "/var/log/nginx/${title}.ssl/access.log",
      error_log            => "/var/log/nginx/${title}.ssl/error.log",
    }
  } else {
    $servers = [ "${title}"]
  }

  file { "${::nginx::log_dir}/${title}":
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
    mysql::db { "${title}":
      dbname   => $db_name,
      user     => $db_user,
      password => $db_pass,
    }
  } else {
    mysql::db { "${title}":
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
