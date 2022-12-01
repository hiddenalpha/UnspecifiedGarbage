;(function(){ "use strict";

const http = require("http");
const util = require("util");
const DevNull = { write:function(){} };

const hrtime = process.hrtime;
const stdin  = process.stdin ;
const stdlog = process.stderr;
const stdout = process.stdout;
const noop = function(){};


setTimeout(main);


function printHelp(){
    stdout.write("\n"
        +"  hiddenalphas HTTP pressure test utility.\n"
        +"\n"
        +"Options:\n"
        +"\n"
        +"    --host <ip|hostname>\n"
        +"        Eg:  127.0.0.1\n"
        +"\n"
        +"    --port <int>\n"
        +"        Eg:  7013\n"
        +"\n"
        +"    --path <str>\n"
        +"        Eg:  /houston/services/nullsink\n"
        +"\n"
        +"    --max-parallel <int>\n"
        +"        Defaults to 42.\n"
        +"\n"
        +"    --inter-request-gap <int>\n"
        +"        Milliseconds to wait before starting another request when the previous\n"
        +"        one has ended.\n"
        +"        Defaults to zero.\n"
        +"\n");
}


function parseArgs( cls_flood, argv ){
    // Some defaults
    cls_flood.maxParallel = 42;
    cls_flood.interRequestGapMs = 0;
    // Parse args
    for( var i=2 ; i<argv.length ; ++i ){
        var arg = argv[i];
        if( arg == "--help" ){
            printHelp();
            return -1;
        }else if( arg == "--host" ){
            cls_flood.host = argv[++i];
            if( !cls_flood.host ){ stdlog.write("Arg --host: Value missing\n"); return -1; }
        }else if( arg == "--port" ){
            cls_flood.port = parseInt(argv[++i]);
            if( isNaN(cls_flood.port) ){ stdlog.write("Arg --port: Cannot parse "+ argv[i]+"\n"); return -1; }
        }else if( arg == "--path" ){
            cls_flood.reqPath = argv[++i];
            if( !cls_flood.reqPath ){ stdlog.write("Arg --path: Value missing\n"); return -1; }
        }else if( arg == "--max-parallel"){
            cls_flood.maxParallel = parseInt(argv[++i]);
            if( isNaN(cls_flood.maxParallel) ){ stdlog.write("Arg --max-parallel: Cannot parse "+ argv[i]+"\n"); return -1; }
        }else if( arg == "--inter-request-gap"){
            cls_flood.interRequestGapMs = parseInt(argv[++i]);
            if( isNaN(cls_flood.interRequestGapMs) ){ stdlog.write("Arg --inter-request-gap: Cannot parse "+argv[i]); return -1; }
        }else{
            stdlog.write("Unknown arg: "+ arg +"\n");
            return -1;
        }
    }
    // A few validity checks.
    if( cls_flood.host === null ){ stdlog.write("Arg --host missing\n"); return -1; }
    if( cls_flood.port === null ){ stdlog.write("Arg --port missing\n"); return -1; }
    if( cls_flood.reqPath === null ){ stdlog.write("Arg --path missing\n"); return -1; }
    if( ! cls_flood.reqPath.startsWith("/") ){ cls_flood.reqPath = "/"+ cls_flood.reqPath; }
    return 0;
}


function main() {
    const cls_flood = Object.seal({
        host: null, port: null, reqPath: null,
        //
        interRequestGapMs: null,
        isNullsink: null,
        maxParallel: null,
        totalReqCount: 0,
        statsIntervalMs: 3000,
        httpAgent: null,
        method: "PUT",
        printLowMs: 50,
        printHigMs: Number.MAX_SAFE_INTEGER,
    });

    if( parseArgs(cls_flood, process.argv) ) return;

    cls_flood.httpAgent = new http.Agent({
        keepAlive:true, maxSockets:cls_flood.maxParallel, keepAliveMsecs: 42000
    });

    flood_sendParallelRequests(cls_flood);
    stdin.on("data", function(){}); // <- Allows entering newlines in console :)
}


function flood_sendParallelRequests( cls_flood ){
    stdlog.write("Flood  '"+ cls_flood.method +" "
        + cls_flood.host +":"+ cls_flood.port + cls_flood.reqPath +"'\n '- on  "
        + cls_flood.maxParallel +"  connections. Print if  t > "
        + cls_flood.printLowMs
        +"\n" );
    let floodBegin = hrtime();
    let prevStatsPrint = floodBegin;
    let numRequestsTotl = 0;
    let numRequests = 0;
    for( let iSt=0 ; iSt < cls_flood.maxParallel ; ++iSt ){
        fireOne();
    }
    function fireOne(){ flood_performHttpRequest(cls_flood, onOneDone); }
    function onOneDone(){
        numRequests += 1;
        let now = hrtime();
        let msSinceStatsPrint = hrtimeDiffMs(now, prevStatsPrint);
        if( msSinceStatsPrint > cls_flood.statsIntervalMs ){
            numRequestsTotl += numRequests;
            printStats(now, numRequestsTotl, numRequests, msSinceStatsPrint);
            prevStatsPrint = now;
            numRequests = 0;
        }
        // Use the free slot to fire another request.
        if( cls_flood.interRequestGapMs > 0 ){
            setTimeout(fireOne, cls_flood.interRequestGapMs);
        }else{
            fireOne();
        }
    }
    function printStats( now, numRequestsTotl, numRequests, msSinceStatsPrint ){
        const reqPerSecStr = ("      "+ Math.floor(numRequests / msSinceStatsPrint * 1000)).substr(-6);
        const numReqTotalStr = ("         "+ numRequestsTotl).substr(-9);
        const runningSinceSecStr = ("         "+ Math.floor(hrtimeDiffMs(now, floodBegin)/1000)).substr(-9);
        stdlog.write("Stats:  "
            + reqPerSecStr +"/sec, "
            + numReqTotalStr +" req total,  "
            + runningSinceSecStr +"s running"
            +"\n");
    }
}


function flood_performHttpRequest( cls_flood, onResponseEndCb ) {
    const cls_req = Object.seal({
        cls_flood: cls_flood,
        onResponseEndCb: onResponseEndCb || noop,
        req: null, rsp: null,
        tsReqBegin: hrtime(), tsRspBegin: null, tsRspEnd: null,
    });
    let path = cls_flood.reqPath;
    let headers = undefined;
    if( path.indexOf("/{vehicleId}/") != -1 ){
        let vehicleId = "vehiku00"+ Math.floor(Math.random()*4000);
        path = path.replace( /\/{vehicleId}\//, "/"+ vehicleId +"/" );
        headers = { "x-vehicleid": vehicleId };
    }
    const req = cls_req.req = http.request({
        hostname: cls_flood.host, port: cls_flood.port,
        method: cls_flood.method, path: path,
        headers: headers,
        agent: cls_flood.httpAgent,
    });
    req.on("error", function( err ){ console.error(err); });
    req.on("response", function( rsp ){
        cls_req.rsp = rsp;
        cls_req.tsRspBegin = hrtime();
        rsp.on("data", onResponseData.bind(0,cls_req));
        rsp.on("end", onResponseEnd.bind(0,cls_req));
        let s = rsp.statusCode;
        if( s == 200 || s == 404 ){
            // Fine
        }else{
            stdlog.write( "Received a: HTTP "+ rsp.statusCode +" "+ rsp.statusMessage +"\n" );
        }
    });
    if( cls_flood.method != "GET" ){
        req.write( '{ "info":"Nume es guguseli tscheison zum testle" }' );
    }
    req.end();
}


function onResponseData( cls_req, rspBodyChunk ) {
    const rsp = cls_req.rsp;
    if( ! rsp.isContinuedBodyChunk ){
        rsp.isContinuedBodyChunk = true;
//        stdout.write("\n");
    }
//    stdout.write(rspBodyChunk);
//    stdout.write("\n");
}


function onResponseEnd( cls_req, rsp ){
    const cls_flood = cls_req.cls_flood;
    cls_req.tsRspEnd = hrtime();
    let reqTime = Math.round(hrtimeDiffMs( cls_req.tsRspBegin, cls_req.tsReqBegin ));
    let rspTime = Math.round(hrtimeDiffMs( cls_req.tsRspEnd, cls_req.tsRspBegin ));
    let totTime = Math.round(hrtimeDiffMs( cls_req.tsRspEnd, cls_req.tsReqBegin ));
    if( totTime < cls_flood.printLowMs ){
        // Do NOT print
    }else if( totTime > cls_flood.printHigMs ){
        // Do NOT print
    }else{
//        stdlog.write(util.format( "%s%d%s%d%s%d\n",
//            "HttpCycle: ", totTime, "ms, TTFB: ", reqTime, ", DownloadMs: ", rspTime ));
    }
    cls_req.onResponseEndCb();
}


function hrtimeDiffMs( subtrahend, minuend ){
    return    1000 * (subtrahend[0] - minuend[0])
        + 0.000001 * (subtrahend[1] - minuend[1]) ;
}


}()); /*endOfModuleScope*/
