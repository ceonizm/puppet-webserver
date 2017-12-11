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

  nginx::resource::location { "${title}.default":
    index_files   => [],
    server   => $title,
    location => '/',
    try_files => ['$uri', '/index.php?$query_string']
  }
 
  nginx::resource::location { "${title}.htaccess":
    index_files   => [],
    server        => $title,
    location      => '~ \.htaccess$',
    location_deny => ['all'],
  } 
  nginx::resource::location { "${title}.favico":
    index_files   => [],
    server        => $title,
    location      => '/favicon.ico',
    log_not_found => 'off',
    access_log    => 'off'
  }

  nginx::resource::location { "${title}.robots.txt":
    index_files   => [],
    server        => $title,
    location      => '/robots.txt',
    log_not_found => 'off',
    access_log    => 'off'
  }


  nginx::resource::location { "${title}.php":
    index_files   => [],
    server   => $title,
    location => '~ \.php$',
    fastcgi  => $fpm_pool,
  }

  nginx::resource::location { "${title}.drupal":
    index_files   => [],
    server        => $title,
    location      => '@drupal',
    rewrite_rules => ['^/(.*)$ /index.php?q=$1'],
  }

  nginx::resource::location { "${title}.imagestyles":
    index_files   => [],
    server    => $title,
    location  => '~ ^/sites/.*/files/styles/',
    try_files => ['$uri', '@drupal']
  }

  nginx::resource::location{ "${title}.private-files":
    index_files   => [],
    server        => $title,
    location      => '~ ^(/[a-z\-]+)?/system/files/',
    rewrite_rules => ['^/(.*)$ /index.php?q=$1'],
  }

  nginx::resource::location { "${title}.assets":
    index_files   => [],
    server        => $title,
    location      => '~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$',
    try_files     => ['$uri', '@drupal'],
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
