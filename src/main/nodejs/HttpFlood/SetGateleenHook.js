;(function(){ "use strict";

const http = require("http");
const util = require("util");
const DevNull = { write:function(){} };

const stdin  = process.stdin ;
const stdout = process.stdout;
const stdlog = process.stderr;


setTimeout(main);


function printHelp(){
    stdout.write("\n"
        +"  hiddenalphas simple gateleen hook utilty.\n"
        +"\n"
        +"  Options:\n"
        +"\n"
        +"    --host <ip|hostname>  (default 127.0.0.1)\n"
        +"        Gateleen to use.\n"
        +"\n"
        +"    --port <int>  (default 7012)\n"
        +"        Target port.\n"
        +"\n"
        +"    --path <string>\n"
        +"        Target path where to set the hook for.\n"
        +"\n"
        +"    --destination <url>\n"
        +"        Destination of the hook. Aka where gateleen will forward the\n"
        +"        requests to.\n"
        +"\n"
        +"    --hook-timeout-sec <int>  (default 300)\n"
        +"        Lifetime of the hook in seconds.\n"
        +"\n"
        +"    --route\n"
        +"        Set a route hook.\n"
        +"\n"
        +"    --listener\n"
        +"        Set a listener hook.\n"
        +"\n");
}


function parseArgs( cls_hook, args ){
    cls_hook.host = "127.0.0.1";
    cls_hook.port = 7012;
    cls_hook.path = null;
    cls_hook.destination = null;
    cls_hook.hookTimeoutSec = 300;
    cls_hook.isRoute = false;
    cls_hook.isListener = false;
    for( let i=2 ; i<args.length ; ++i ){
        let arg = args[i];
        if( arg == "--help" ){
            printHelp(); return -1;
        }else if( arg == "--host" ){
            cls_hook.host = args[++i];
            if( !args[i] ){ stdlog.write("Arg --host expects a value\n"); return -1; }
        }else if( arg == "--port" ){
            cls_hook.port = parseInt(args[++i]);
            if( isNaN(cls_hook.port) ){ stdlog.write("Arg --port: Cannot parse "+ argv[i]+"\n"); return -1; }
        }else if( arg == "--path" ){
            cls_hook.path = args[++i];
            if( !args[i] ){ stdlog.write("Arg --path expects a value\n"); return -1; }
        }else if( arg == "--destination"){
            cls_hook.destination = args[++i];
            if( !args[i] ){ stdlog.write("Arg --destination expects a value\n"); return -1; }
        }else if( arg == "--hook-timeout-sec"){
            cls_hook.hookTimeoutSec = parseInt(args[++i]);
            if( isNaN(cls_hook.hookTimeoutSec) ){ stdlog.write("Parse --hook-timeout-sec failed: "+args[i]+"\n"); return -1; }
        }else if( arg == "--route"){
            cls_hook.isRoute = true;
        }else if( arg == "--isListener"){
            cls_hook.isListener = true;
        }else{
            stdlog.write("Unknown arg: "+ arg +"\n");
        }
    }
    if( cls_hook.host === null ){ stdlog.write("Arg --host missing\n"); return -1; }
    if( cls_hook.port === null ){ stdlog.write("Arg --port missing\n"); return -1; }
    if( cls_hook.path === null ){ stdlog.write("Arg --path missing\n"); return -1; }
    if( cls_hook.destination === null ){ stdlog.write("Arg --destination missing\n"); return -1; }
    if( !cls_hook.isRoute && !cls_hook.isListener ){ stdlog.write("Need one of --route or --listener\n"); return -1; }
    if( cls_hook.isRoute && cls_hook.isListener ){ stdlog.write("Cannot be --route and --listener simultaneously\n"); return -1; }
    return 0;
}


function main() {
    const cls_hook = Object.seal({
        host: null,
        port: null,
        path: null,
        destination: null,
        hookTimeoutSec: null,
        isRoute: false,
        isListener: false,
    });
    if( parseArgs(cls_hook, process.argv) ) return;
    setHook(cls_hook);
}


function setHook( cls_hook ){
    const req = http.request({
        hostname: cls_hook.host, port: cls_hook.port,
        method: "PUT",
        path: cls_hook.path + "/_hooks/"+ (cls_hook.isRoute ? "route" : "listener"),
        headers: {
            "Content-Type": "application/json",
        },
    });
    req.on("error", function( err ){ console.error(err); });
    req.on("response", function( rsp ){
        stdout.write( "HTTP "+ rsp.statusCode +" "+ rsp.statusMessage +"\n" );
    });
    req.end(JSON.stringify({
        destination: cls_hook.destination,
        methods: [],
    }));
}


}()); /*endOfModule*/

