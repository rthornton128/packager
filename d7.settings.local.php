<?php

/* Database */
$databases['default']['default'] = array(
  'driver' => 'mysql',
  'database' => '{DBNAME}',
  'username' => '{DBUSER}',
  'password' => '{DBPASS}',
  'host' => 'localhost',
  'port' => '',
  'prefix' => '',
);

/* Error output */
$conf['error_level'] = 2;

/* File system */
$conf['file_public_path'] = '{FILESDIR}';
$conf['file_private_path'] = '{PRIVATEDIR}';
$conf['file_temporary_path'] = '{TMPDIR}';

/* Theme debugging */
$conf['theme_debug'] = TRUE;

/* Aggregation and caching */
$conf['preprocess_css'] = FALSE;
$conf['preprocess_js'] = FALSE;

/* Email rerouting */
$conf['reroute_email_enable'] = 1;
$conf['reroute_email_address'] = "rthornton@acromediainc.com";

/* Stage file proxy */
$conf['stage_file_proxy_origin'] = '{REMOTE}';
$conf['stage_file_proxy_use_imagecache_root'] = FALSE;
$conf['stage_file_proxy_hotlink'] = FALSE;
$conf['stage_file_proxy_origin_dir'] = 'sites/default/files';
