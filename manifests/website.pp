define webserver::website (
  Array[String] $urls                                  = [],
  String $website_name                                 = $title,
  String $unix_user                                    = undef,
  Optional[Array[String]] $unix_user_keys              = [],
  Optional[String] $unix_password                      = undef,
  Boolean $default                                     = false,
  Boolean $https                                       = false,
  Boolean $robots                                      = true,
  Optional[String] $ssl_cert                           = undef,
  Optional[String] $ssl_key                            = undef,
  Optional[Variant[String, Array[String]]] $unix_group = $unix_user,
  String $db_user                                      = undef,
  String $db_pass                                      = undef,
  String $www_root_folder                              = "www",
  Optional[String] $auth_basic                         = undef,
  Optional[Hash] $auth_basic_users                     = undef,
  Optional[String] $db_name                            = undef,
  Optional[String] $db_host                            = 'localhost',
  Optional[String] $path                               = "/var/www/$website_name",
  Optional[String] $fpm_pool_name                      = "fpm",
  Optional[Boolean] $generate_root_location            = true,
  $rewrite_rules                                       = []
) {

  if( !($unix_user in $facts['users'].split(',')) and !defined(User[$unix_user])) {
    group { $unix_group:
      ensure => 'present'
    }
    if( $unix_password ) {
      user { "website-${unix_user}":
        ensure   => 'present',
        name     => $unix_user,
        home     => $path,
        groups   => $unix_group,
        keys     => $unix_user_keys,
        password => pw_hash($unix_password, 'SHA-512', 'mysalt')
      }
    } else {
      user { "website-${unix_user}":
        ensure => 'present',
        name   => $unix_user,
        home   => $path,
        groups => $unix_group,
        keys   => $unix_user_keys,
      }
    }
  }

  if( size($urls) == 0 ) {
    $_urls = [$website_name]
  } else {
    $_urls = $urls
  }

  if( $default == true ) {
    $listen_options = "default_server"
    $ipv6_listen_options = "default"
  } else {
    $listen_options = undef
    $ipv6_listen_options = ""
  }

  $server_cfg_prepend = {
    root => "${path}/${www_root_folder}"
  }
  if( $auth_basic_users ) {
    $authBasicUserFile = "${path}/${website_name}.auth_users.db"
    file { "${authBasicUserFile}":
      ensure => 'present',
      owner  => $unix_user,
      group  => $unix_group
    }
    $auth_basic_users.each |String $userName, String $userPass | {
      exec { "create or update user ${userName}":
        path    => [
          '/bin',
          '/usr/bin'
        ],
        command => "htpasswd -b ${authBasicUserFile} ${userName} ${userPass}",
        user    => $unix_user


      }
    }
  } else {
    $authBasicUserFile = undef
  }


  nginx::resource::server { "${website_name}":
    use_default_location => !$https and $generate_root_location,
    server_cfg_prepend   => (!$https and $generate_root_location) ? {
      true  => $server_cfg_prepend,
      false => undef
    },
    server_name          => $_urls,
    www_root             => "${path}/${www_root_folder}",
    ipv6_enable          => true,
    listen_port          => 80,
    listen_options       => $listen_options,
    ipv6_listen_options  => $ipv6_listen_options,
    auth_basic           => $auth_basic,
    auth_basic_user_file => $authBasicUserFile,
    ssl                  => false,
    ssl_cert             => false,
    rewrite_rules        => $rewrite_rules,
    try_files            => ['$uri', '$uri/', 'index.php?$args'],
    access_log           => "/var/log/nginx/$website_name/access.log",
    error_log            => "/var/log/nginx/$website_name/error.log",
  }



  if ( $https ) {
    $servers = [ "${website_name}", "${website_name}.ssl"]
    nginx::resource::server { "$website_name.ssl":
      use_default_location => $generate_root_location,
      server_cfg_prepend   => $generate_root_location ? {
        true  => $server_cfg_prepend,
        false => undef
      },
      server_name          => $_urls,
      www_root             => "${path}/${www_root_folder}",
      ipv6_enable          => true,
      listen_port          => 443,
      ipv6_listen_options  => $ipv6_listen_options,
      ssl                  => true,
      ssl_cert             => $ssl_cert,
      ssl_key              => $ssl_key,
      auth_basic           => $auth_basic,
      auth_basic_user_file => $authBasicUserFile,
      rewrite_rules        => $rewrite_rules,
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

  if( !defined( File[$path])) {
    file { "${path}":
      ensure => 'directory',
      mode   => '0755',
      owner  => $unix_user,
      group  => $unix_group
    }
  }

  $parts = split("${www_root_folder}", '/')
  $partsLen = $parts.length
  if( $partsLen > 1 ) {
    $path_tree = range(1, $partsLen).map | Integer $index | {
      inline_epp('<%= $path %>/<%= $left %>', { 'path' => "${path}", 'left' => join($parts[0, $index], "/") })
    }
  } else {
    $path_tree = [ "${path}/${www_root_folder}" ]
  }

  file { $path_tree:
    ensure => 'directory',
    mode   => '0755',
    owner  => $unix_user,
    group  => $unix_group
  }


  if( $db_name and $db_host == 'localhost') {
    Notify { "${db_user}:${db_pass}@${db_host}/${db_name}":}
    mysql::db { "${website_name}":
      dbname   => $db_name,
      user     => $db_user,
      password => $db_pass,
      host     => $db_host,
      charset  => 'utf8mb4',
      collate  => 'utf8mb4_general_ci'
    }
  } /*else {
    mysql::db { "${website_name}":
      user     => $db_user,
      password => $db_pass,
      host     => $db_host
    }
  }*/

  $location_cfg_prepend = {
    limit_req => 'zone=limitedrate burst=2'
  }
  /* generating locations */
  $servers.each | String $serverName | {

    nginx::resource::location { "${serverName}.htaccess":
      index_files   => [],
      server        => $serverName,
      location      => '~ \.htaccess$',
      location_deny => ['all'],
    }

    nginx::resource::location { "${serverName}.empty":
      server      => $serverName,
      index_files => [],
      location    => '@empty',
      expires     => '30d',
      raw_append  => '
      empty_gif;
      '
    }
    nginx::resource::location { "${serverName}.favico":
      index_files => [],
      server      => $serverName,
      expires     => '30d',
      try_files   => ['$uri', '@empty'],
      location    => '/favicon.ico',
      raw_append  => '
        log_not_found off;
        access_log off;
      '
      # log_not_found => 'off',
      # access_log    => 'off'
    }


    if( $robots ) {
      nginx::resource::location { "${serverName}.robots.txt":
        index_files => [],
        server      => $serverName,
        location    => '/robots.txt',
        raw_append  => '
        log_not_found off;
        access_log off;
      '
        # log_not_found => 'off',
        # access_log    => 'off'
      }
    }

    nginx::resource::location { "${serverName}.php":
      index_files          => [],
      server               => $serverName,
      location             => '~ \.php$',
      fastcgi              => $fpm_pool_name,
      location_cfg_prepend => $location_cfg_prepend
    }
  }
}
