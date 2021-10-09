define webserver::drupal (

  Array[String] $urls              = [],
  $website_name                    = $title,
  $unix_user                       = undef,
  $unix_password                   = undef,
  $https                           = false,
  Optional[String] $ssl_cert       = undef,
  Optional[String] $ssl_key        = undef,
  String $db_user                  = undef,
  String $db_pass                  = undef,
  String $www_root_folder          = "www",
  Optional[String] $unix_group     = $unix_user,
  Optional[String] $db_name        = undef,
  Optional[String] $db_host        = 'localhost',
  Optional[String] $path           = "/var/www/$title",
  Optional[String] $auth_basic     = undef,
  Optional[Hash] $auth_basic_users = undef,
  Optional[String] $fpm_pool       = "fpm",
  Optional[Integer] $version       = 7
) {

  ensure_packages(['drush'], { 'ensure' => 'present' })

  webserver::website { $title:
    urls                   => $urls,
    website_name           => $website_name,
    unix_user              => $unix_user,
    unix_password          => $unix_password,
    unix_group             => $unix_group,
    https                  => $https,
    robots                 => false,
    ssl_cert               => $ssl_cert,
    ssl_key                => $ssl_key,
    db_user                => $db_user,
    db_pass                => $db_pass,
    db_name                => $db_name,
    db_host                => $db_host,
    path                   => $path,
    auth_basic             => $auth_basic,
    auth_basic_users       => $auth_basic_users,
    www_root_folder        => $www_root_folder,
    fpm_pool_name          => $fpm_pool,
    generate_root_location => false
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
      try_files   => ['$uri', '@drupal'],
      expires     => '30d'
    }

    # support for advagg_css
    nginx::resource::location { "${serverName}.advagg-css":
      index_files => [],
      server      => $serverName,
      location    => '^~ /sites/default/files/advagg_css/',
      expires     => 'max',
      add_header  => {
        'ETag'          => '',
        'Last-Modified' => 'Wed, 20 Jan 1988 04:20:42 GMT',
        'Accept-Ranges' => ''
      },
      raw_append  => '
        location ~* /sites/default/files/advagg_css/css[_[:alnum:]]+\.css$ {
            access_log off;
            try_files $uri @drupal;
        }
      '
    }
    # support for advagg_js
    nginx::resource::location { "${serverName}.advagg-js":
      index_files => [],
      server      => $serverName,
      location    => '^~ /sites/default/files/advagg_js/',
      try_files   => ['$uri', '@drupal'],
      expires     => 'max',
      add_header  => {
        'ETag'          => '',
        'Last-Modified' => 'Wed, 20 Jan 1988 04:20:42 GMT',
        'Accept-Ranges' => ''
      },
      raw_append  => '
        location ~* /sites/default/files/advagg_js/js[_[:alnum:]]+\.js$ {
            access_log off;
            try_files $uri @drupal;
        }
      '
    }


    nginx::resource::location { "${serverName}.private-files":
      index_files   => [],
      server        => $serverName,
      location      => '~ ^(/[a-z\-]+)?/system/files/',
      rewrite_rules => ['^/(.*)$ /index.php?q=$1'],
      raw_append    => '
      log_not_found off;
      '
    }

    nginx::resource::location {"${serverName}.private-files.direct-access":
      index_files   => [],
      server        => $serverName,
      location      => '^~ /sites/default/files/private/',
      internal      => true
    }

    nginx::resource::location { "${serverName}.assets":
      index_files   => [],
      server        => $serverName,
      location      => '~* \.(css|cur|js|jpe?g|gif|htc|ico|png|html|xml|otf|ttf|eot|woff2?|svg)$',
      try_files     => ['$uri', '@drupal'],
      expires       => 'max',
      raw_append    => '
      log_not_found off;
      ## No need to bleed constant updates. Send the all shebang in one
      ## fell swoop.
      tcp_nodelay off;
      ## Set the OS file cache.
      open_file_cache max=3000 inactive=120s;
      open_file_cache_valid 45s;
      open_file_cache_min_uses 2;
      open_file_cache_errors off;
      '
    }

    nginx::resource::location { "${serverName}.hide-files":
      location => '~* ^(?:.+\.(?:htaccess|make|txt|engine|inc|info|install|module|profile|po|pot|sh|.*sql|test|theme|tpl(?:\.php)?|xtmpl)|code-style\.pl|/Entries.*|/Repository|/Root|/Tag|/Template)$',
      raw_append => '
        return 404;
      '
    }

    nginx::resource::location { "${serverName}.robots.txt":
      index_files => [],
      server      => $serverName,
      location    => '/robots.txt',
      try_files   => ['$uri', '@drupal'],
      raw_append  => '
        log_not_found off;
        access_log off;
      '
      # log_not_found => 'off',
      # access_log    => 'off'
    }

    nginx::resource::location { "${serverName}.rss.xml":
      index_files => [],
      location    => '/rss.xml',
      try_files   => ['$uri', '@drupal'],
    }

    nginx::resource::location { "${serverName}.sitemap.xml":
      index_files => [],
      location    => '/sitemap.xml',
      try_files   => ['$uri', '@drupal'],
    }


  }
}
