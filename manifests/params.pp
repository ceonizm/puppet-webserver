class webserver::params {

  $default_fpm_pools = {
    'www' => {
      listen       => '/var/run/php7.0-fpm-www.sock',
      listen_owner => 'www-data',
      listen_group => 'www-data',
      listen_mode  => '0660'
    }
  }
}
