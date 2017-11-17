class webserver::params {

  $default_fpm_pools = {
    'www' => { listen => '/var/run/php7.0-fpm-www.sock', }
  }
}