class webserver::params {
  $default_php_version = "7.0"
  $default_mariadb_version = "10.6"
  $default_install_db_server = true
  $default_web_user = 'www-data'
  $default_web_group = 'www-data'
  $default_fpm_pools = {
    'www' => {
      listen       => "/var/run/php${default_php_version}-fpm-www.sock",
      listen_owner => "${default_web_user}",
      listen_group => "${default_web_group}",
      listen_mode  => '0660'
    }
  }
}
