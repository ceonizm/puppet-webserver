define webserver::website (
  Array[String] $urls          = [],
  $website_name                = $title,
  $unix_user                   = undef,
  Optional[String] $unix_group = $unix_user,
  String $db_user              = undef,
  String $db_pass              = undef,
  Optional[String] $db_host    = 'localhost',
  Optional[String] $path       = "/var/www/$title/www",
  Optional[String] $fpm_pool   = "fpm"
) {


  if( size($urls) == 0 ) {
    $_urls = [$title]
  } else {
    $_urls = $urls
  }

  nginx::resource::server { $title:
    server_name => $_urls,
    www_root    => $path,
    listen_port => 80,
    ssl         => false,
    ssl_cert    => false,
    try_files   => ['$uri', '$uri/', 'index.php?$args'],
    access_log  => "/var/log/nginx/$title/access.log",
    error_log   => "/var/log/nginx/$title/error.log",
  }

  file { "/var/log/nginx/${title}":
    ensure => 'directory',
    owner  => $nginx::params::super_user
  }

  nginx::resource::location { 'favico':
    server        => $title,
    location      => '/favicon.ico',
    log_not_found => 'off',
    access_log    => 'off'
  }
  nginx::resource::location { 'robots.txt':
    server        => $title,
    location      => '/robots.txt',
    log_not_found => 'off',
    access_log    => 'off'
  }

  nginx::resource::location { 'php':
    server   => $title,
    location => '~ \.php$',
    fastcgi  => 'fpm',
  }

  nginx::resource::location { 'assets':
    server        => $title,
    location      => '~* \.(js|css|png|jpg|jpeg|gif|ico)$',
    expires       => 'max',
    log_not_found => 'off'
  }

  mysql::db { "${title}:db":
    user     => $db_user,
    password => $db_pass,
  }
}
