<?php
  if (isset($_GET['ip']) && isset($_GET['port']))
  {
    $connect = "steam://connect/" . $_GET['ip'] . ":" . $_GET['port'];
    header('Location: ' . $connect);
  }
  else
  {
    die("invalid adress");
  }
?>
