# Class: website
# ===========================
#
# Full description of class website here.
#
# Parameters
# ----------
#
# Document parameters here.
#
# * `sample parameter`
# Explanation of what this parameter affects and what it defaults to.
# e.g. "Specify one or more upstream ntp servers as an array."
#
# Variables
# ----------
#
# Here you should define a list of variables that this module would require.
#
# * `sample variable`
#  Explanation of how this variable affects the function of this class and if
#  it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#  External Node Classifier as a comma separated list of hostnames." (Note,
#  global variables should be avoided in favor of class parameters as
#  of Puppet 2.6.)
#
# Examples
# --------
#
# @example
#    class { 'website':
#      servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#    }
#
# Authors
# -------
#
# Author François Boukhalfa <francois@ceonizme.fr>
#
# Copyright
# ---------
#
# Copyright 2017 Your name here, unless otherwise noted.
#
class webserver (
  Optional[String] $php_version        = $::webserver::params::default_php_version,
  Optional[Boolean] $install_db_server = $::webserver::params::default_install_db_server,
  Optional[String] $web_user           = $::webserver::params::default_web_user,
  Optional[String] $web_group          = $::webserver::params::default_web_group,
  Optional[String] $db_root_password   = undef,
  Optional[String] $server_name        = undef,
  Optional[Hash] $fpm_pools            = undef
) inherits webserver::params {
  group { $web_group:
    ensure => 'present'
  }


  contain '::webserver::package'

  class { '::php::globals':
    php_version => $php_version,
    config_root => "/etc/php/${php_version}"
  }

  if( $webserver::fpm_pools ) {
    $_fpm_pools = deep_merge($default_fpm_pools, $webserver::fpm_pools)
  } else {
    $_fpm_pools = $webserver::params::default_fpm_pools
  }

  $noListenDefined = $_fpm_pools.filter |$key,$pool| {
    !('listen' in $pool)
  }.map | $key, $value | {
    [[$key,'listen'], "/var/run/php${php_version}-fpm-${$key}.sock"]
  }

  $poolsTree = $_fpm_pools.tree_each.map| $entry | {
    if( $entry[0][$entry.length()-1] == "listen") {
      $value = "/var/run/php${php_version}-fpm-${entry[0][0]}.sock"
    } else {
       $value = $entry[1]
    }
    [ $entry[0], $value ]
  }

  $_processedFpmPools =  Hash($poolsTree+$noListenDefined,'hash_tree')
  notify { "after conversion":
    message => $_processedFpmPools
  }

  package { 'apache2-utils':
    ensure => 'installed'
  }

  package { 'imagemagick':
    ensure => 'installed'
  }

  class { '::php':
    ensure       => 'installed',
    manage_repos => true,
    fpm          => true,
    fpm_pools    => $_processedFpmPools,
    dev          => true,
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
      "Console_Table" => {
        provider       => 'pear',
      },
      msgpack     => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      memcached     => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      #mcrypt        => {
      #  provider       => 'apt',
      #  package_prefix => "php-",
      #},
      mysql         => {
        provider    => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      xml           => {
       provider       => 'apt',
       package_prefix => "php${::php::globals::php_version}-",
      },
      mbstring      => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
      igbinary      => {
        provider       => 'apt',
        package_prefix => "php${::php::globals::php_version}-",
      },
    }
  }

  exec { 'rename cli memcached.ini if needed:':
    user     => "root",
    path     => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ],
    provider => "shell",
    onlyif   => sprintf('test -f /etc/php/%s/cli/20-memcached.ini', $::php::globals::php_version),
    command  => "mv /etc/php/${::php::globals::php_version}/cli/20-memcached.ini /etc/php/${::php::globals::php_version}/cli/21-memcached.ini"
  }

  exec { 'rename fpm memcached.ini if needed:':
    user     => "root",
    path     => [ '/bin/', '/sbin/', '/usr/bin/', '/usr/sbin/' ],
    provider => "shell",
    onlyif   => sprintf('test -f /etc/php/%s/fpm/20-memcached.ini', $::php::globals::php_version),
    command  => "mv /etc/php/${::php::globals::php_version}/fpm/20-memcached.ini /etc/php/${::php::globals::php_version}/cli/21-memcached.ini"
  }


  $http_preprend_config = {
    limit_req_zone      => '$binary_remote_addr zone=limitedrate:10m rate=2r/s',
    fastcgi_buffers     => '16 16k',
    fastcgi_buffer_size => '32k',
    fastcgi_read_timeout => 3000
  }

  # nginx
  class { 'nginx':
    manage_repo            => true,
    package_source         => 'nginx-stable',
    names_hash_bucket_size => 128,
    server_tokens          => 'off',
    gzip                   => 'on',
    gzip_disable           => 'msie6',
    gzip_http_version      => '1.0',
    gzip_vary              => 'on',
    gzip_proxied           => 'any',
    gzip_types             =>
      'text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript image/x-icon application/vnd.ms-fontobject font/opentype application/x-font-ttf'
    ,
    http_cfg_prepend       => $http_preprend_config,

  }

  nginx::resource::upstream { 'fpm':
    members => {
      "unix:/var/run/php${php_version}-fpm-www.sock" => {
        server => "unix:/var/run/php${php_version}-fpm-www.sock"
      },
    }
  }

  if( !defined(File['/var/www'])) {
    file { "/var/www":
      ensure => 'directory',
      mode   => '0755',
      owner  => 'root',
      group  => $web_group,
      require => Group[$web_group]
    }
  }
}

