<?php

throw new Exception("Sorry, cannot just execute from file :(");


function run( $app ){
    $lotsOfSql = file_get_contents($app->srcPath);
    if( !$lotsOfSql ) throw new Exception("fopen(\"{$app->srcPath}\")");
    $app->db = new SQLite3($app->dstPath);
    if( !$app->db ) throw new Exception("SQLite3(\"{$app->dstPath}\")");
    $db = $app->db;
    $db->enableExceptions(true);
    $st = $db->prepare($lotsOfSql);
    $st->execute();
    $st->close();
}


function main(){
    $app = (object)array(
        "srcPath" => NULL/*TODO set me*/,
        "dstPath" => NULL/*TODO set me*/,
        "srcFile" => NULL,
        "db" => NULL,
    );
    run($app);
}


main();
