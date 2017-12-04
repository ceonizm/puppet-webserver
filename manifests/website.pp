define webserver::website (
  Array[String] $urls          = [],
  $website_name                = $title,
  $unix_user                   = undef,
  $unix_password               = undef,
  Optional[String] $unix_group = $unix_user,
  String $db_user              = undef,
  String $db_pass              = undef,
  Optional[String] $db_name    = undef,
  Optional[String] $db_host    = 'localhost',
  Optional[String] $path       = "/var/www/$title",
  Optional[String] $fpm_pool   = "fpm"
) {


  user { $unix_user:
    ensure   => 'present',
    home     => $path,
    groups   => 'web',
    password => $unix_password
  }

  if( size($urls) == 0 ) {
    $_urls = [$title]
  } else {
    $_urls = $urls
  }

  nginx::resource::server { $title:

    server_name => $_urls,
    www_root    => "$path/www",
    listen_port => 80,
    ssl         => false,
    ssl_cert    => false,
    try_files   => ['$uri', '$uri/', 'index.php?$args'],
    access_log  => "/var/log/nginx/$title/access.log",
    error_log   => "/var/log/nginx/$title/error.log",
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
    owner => $unix_user,
    group => $unix_group
  }

  file { "${path}/www":
    ensure => 'directory',
    mode   => '0755',
    owner => $unix_user,
    group => $unix_group
  }

  nginx::resource::location { "${title}.favico":
    server        => $title,
    location      => '/favicon.ico',
    log_not_found => 'off',
    access_log    => 'off'
  }
  nginx::resource::location { "${title}.robots.txt":
    server        => $title,
    location      => '/robots.txt',
    log_not_found => 'off',
    access_log    => 'off'
  }

  nginx::resource::location { "${title}.php":
    server   => $title,
    location => '~ \.php$',
    fastcgi  => 'fpm',
  }

  nginx::resource::location { "${title}.assets":
    server        => $title,
    location      => '~* \.(js|css|png|jpg|jpeg|gif|ico)$',
    expires       => 'max',
    log_not_found => 'off'
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

}
