;(function(){ "use strict";

const http = require("http");
const util = require("util");
const DevNull = { write:function(){} };

const hrtime = process.hrtime;
const stdin  = process.stdin ;
const stdout = process.stdout;
const stdlog = process.stderr;


setTimeout(main);


function printHelp(){
    stdout.write("\n"
        +"  hiddenalphas simple HTTP server just responding '200 OK' for every\n"
        +"  incoming request.\n"
        +"\n"
        +"  Options:\n"
        +"\n"
        +"    --host <ip|hostname>  (default 127.0.0.1)\n"
        +"        Listen address.\n"
        +"\n"
        +"    --port <int>\n"
        +"        Listen port.\n"
        +"\n"
        +"    --statsIntervalMs <int>  (default 5000)\n"
        +"        Interval when to print statistics.\n"
        +"\n");
}


function parseArgs( cls_nullsink, args ){
    cls_nullsink.host = "127.0.0.1";
    cls_nullsink.port = null;
    cls_nullsink.statsIntervalMs = 5000;
    for( let i=2 ; i<args.length ; ++i ){
        let arg = args[i];
        if( arg=="--help" ){
            printHelp(); return -1;
        }else if( arg=="--host" ){
            cls_nullsink.host = args[++i];
            if( !args[i] ){ stdlog.write("Arg --host expects a value\n"); return -1; }
        }else if( arg=="--port" ){
            cls_nullsink.port = parseInt(args[++i]);
            if( isNaN(cls_nullsink.port) ){ stdlog.write("Arg --port: Cannot parse "+ argv[i]+"\n"); return -1; }
        }else if( arg=="--statsIntervalMs" ){
            cls_nullsink.statsIntervalMs = parseInt(args[++i]);
            if( isNaN(cls_nullsink.statsIntervalMs) ){ stdlog.write("Arg --statsIntervalMs: Cannot parse "+ argv[i]+"\n"); return -1; }
        }else{
            stdlog.write("Unknown arg: "+ arg +"\n");
        }
    }
    if( cls_nullsink.host === null ){ stdlog.write("Arg --host missing\n"); return -1; }
    if( cls_nullsink.port === null ){ stdlog.write("Arg --port missing\n"); return -1; }
    return 0;
}


function main() {
    const cls_nullsink = Object.seal({
        server: null,
        host: null,
        port: null,
        backlog: undefined,
        statsIntervalMs: null,
        srvStart: hrtime(),
        reqTotl: 0,
        reqCnt: 0,
        lastStats: hrtime(),
    });
    if( parseArgs(cls_nullsink, process.argv) ) return;
    launchServer(cls_nullsink);
    logStatsPeriodically(cls_nullsink);
    // Attaching a listener is enough to allow pressing enter in console.
    stdin.on("data", function(){});
}


function launchServer( cls_nullsink ){
    const server = cls_nullsink.server = http.createServer(onRequest.bind(0,cls_nullsink));
    server.listen(cls_nullsink.port, cls_nullsink.host, cls_nullsink.backlog);
    stdlog.write("Server listening on "
        + cls_nullsink.host +":"+ cls_nullsink.port
        +" (backlog "+ cls_nullsink.backlog +")\n");
}


function onRequest( cls_nullsink, req, rsp ){
    // Just respond "200 OK" for all requests.
    cls_nullsink.reqCnt += 1;
    rsp.writeHead(200);
    rsp.end();
}


function logStatsPeriodically( cls_nullsink ){
    scheduleOne();
    function scheduleOne(){
        setTimeout(log, cls_nullsink.statsIntervalMs-1);
    }
    function log(){
        const now = hrtime();
        const durationMs = Math.floor(hrtimeDiffMs(now, cls_nullsink.lastStats));
        const totlMs = Math.floor(hrtimeDiffMs(now, cls_nullsink.srvStart))
        cls_nullsink.reqTotl += cls_nullsink.reqCnt;
        stdlog.write("Stats: Consumed  "
            + cls_nullsink.reqCnt +"  req in  "
            + durationMs +"  ms. So avg  "
            + Math.floor(cls_nullsink.reqCnt / durationMs * 1000) +"  req/sec of overall  "
            + cls_nullsink.reqTotl +"  req in  "
            + Math.floor(totlMs/1000) +"  sec. Avg  "
            + Math.floor(cls_nullsink.reqTotl / totlMs)
            +"\n");
        cls_nullsink.lastStats = now;
        cls_nullsink.reqCnt = 0;
        scheduleOne();
    }
}


function hrtimeDiffMs( subtrahend, minuend ){
    return    1000 * (subtrahend[0] - minuend[0])
        + 0.000001 * (subtrahend[1] - minuend[1]) ;
}


}()); /*endOfModule*/
