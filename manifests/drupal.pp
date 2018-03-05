define webserver::drupal (

  Array[String] $urls          = [],
  $website_name                = $title,
  $unix_user                   = undef,
  $unix_password               = undef,
  $https                       = false,
  Optional[String] $ssl_cert   = undef,
  Optional[String] $ssl_key    = undef,
  String $db_user              = undef,
  String $db_pass              = undef,
  Optional[String] $unix_group = $unix_user,
  Optional[String] $db_name    = undef,
  Optional[String] $db_host    = 'localhost',
  Optional[String] $path       = "/var/www/$title",
  Optional[String] $fpm_pool   = "fpm",
  Optional[Integer] $version   = 7
) {

  package { 'drush':
    ensure => 'installed'
  }

  webserver::website { $title:
    urls          => $urls,
    website_name  => $website_name,
    unix_user     => $unix_user,
    unix_password => $unix_password,
    unix_group    => $unix_group,
    https         => $https,
    ssl_cert      => $ssl_cert,
    ssl_key       => $ssl_key,
    db_user       => $db_user,
    db_pass       => $db_pass,
    db_name       => $db_name,
    db_host       => $db_host,
    path          => $path,
    fpm_pool_name => $fpm_pool
  }
  


  if( $https ) {
    $servers = [ "${title}", "${title}.ssl"]
  } else {
    $servers = [ "${title}"]
  }
  $servers.each | String $serverName | {
    if( $version >= 7 ) {
      nginx::resource::location { "${serverName}.default":
        index_files => [],
        server      => $serverName,
        location    => '/',
        try_files   => ['$uri', '/index.php?$query_string']
      }
    } else {

      nginx::resource::location { "${serverName}.default":
        index_files => [],
        server      => $serverName,
        location    => '/',
        try_files   => ['$uri', '@drupal']
      }
    }

    nginx::resource::location { "${serverName}.drupal":
      index_files   => [],
      server        => $serverName,
      location      => '@drupal',
      rewrite_rules => ['^/(.*)$ /index.php?q=$1'],
    }

    nginx::resource::location { "${serverName}.imagestyles":
      index_files => [],
      server      => $serverName,
      location    => '~ ^/sites/.*/files/styles/',
      try_files   => ['$uri', '@drupal']
    }

    nginx::resource::location { "${serverName}.private-files":
      index_files   => [],
      server        => $serverName,
      location      => '~ ^(/[a-z\-]+)?/system/files/',
      rewrite_rules => ['^/(.*)$ /index.php?q=$1'],
    }

    nginx::resource::location { "${serverName}.assets":
      index_files   => [],
      server        => $serverName,
      location      => '~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$',
      try_files     => ['$uri', '@drupal'],
      expires       => 'max',
      log_not_found => 'off'
    }
  }
}
