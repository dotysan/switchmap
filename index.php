<?php
$configfile='/usr/web/nets/internal/portlists/ThisSite.pm';
$cols=80;
$rows=30;

?>
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html><head>
<meta name="ROBOTS" content="NOINDEX, NOFOLLOW">
<meta Http-Equiv="Cache-Control" Content="no-cache">
<meta Http-Equiv="Pragma" Content="no-cache">
<meta Http-Equiv="Cache-Control:" max-age="0">
<meta Http-Equiv="Expires" Content="-100">
<title>Configure Switchmap</title>
<link href="/nets/internal/SwitchMap.css" rel="stylesheet">
</head>
<body>

<?php
if (!isset($_REQUEST['content'])) {
?>

<h1>Edit config file</h1>

<form action="<?php echo $_SERVER['PHP_SELF']; ?>" method="post">
<textarea name="content" cols=<?php echo $cols; ?> rows=<?php echo $rows; ?>>
<?php
include $configfile;
?>
</textarea>
<p>
<input type=submit value="Save">
</form>
<form action="<?php echo $_SERVER['PHP_SELF']; ?>" method=get>
<input type=submit value="Discard Changes">
</form>
</p>
<form action="/switchmap" method=get>
<input type=submit value="Cancel">
</form>
</p>

</form>

<?php

# End editing page
}
else {
# Begin uploading page
    $fh=fopen($configfile, 'w');
    $confdata=stripslashes($_REQUEST['content']);
    fwrite($fh, $confdata);
    fclose($fh);
?>

<p>
Config file changed.
</p>

<?php
}
?>


</body>
</html>
