<?php
$srcSqlFile = "path/to/query.sql";
$dstDbFile = "path/to/sqlite.db";
$stmts = file_get_contents($srcSqlFile) or exit(1);
$stmts = explode(';', $stmts);
$db = new SQLite3($dstDbFile);
$db->enableExceptions(true);
foreach( $stmts AS $stmtStr ){
    $stmtStr = trim($stmtStr);
    if( !$stmtStr ) continue;
    $st = $db->prepare($stmtStr .';');
    $st->execute();
    //$id = $db->lastInsertRowID();
    //if( $id ){ echo "lastInsertRowID() -> $id\n"; }
    $st->close();
}
$db->close();
