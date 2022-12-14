;(function(){ "use strict";


const http = require("http");
const stdout = process.stdout;
const stdlog = process.stderr;
const noop = function(){};


setTimeout(main);


function printHelp(){
    stdout.write("\n"
        +"  Put showcase data into gateleen-playground via HTTP\n"
        +"\n"
        +"  Options:\n"
        +"\n"
        +"    --host <ip|hostname>\n"
        +"        Gateleen host to use.\n"
        +"\n"
        +"    --port <int>  (default 7012)\n"
        +"        TCP port of gateleen to use.\n"
        +"\n"
        +"    --path <string>\n"
        +"        Root where to PUT trash data. Example: '/playground/tmp/my-trash'.\n"
        +"\n");
}


function parseArgs( cls_putit, args ){
    // Defaults
    cls_putit.host = null;
    cls_putit.port = 7012;
    cls_putit.path = null;
    for( let i=2 ; i<args.length ; ++i ){
        let arg = args[i];
        if( arg == "--help" ){
            printHelp(); return -1;
        }else if( arg == "--host" ){
            cls_putit.host = args[++i];
            if( !args[i] ){ stdlog.write("Arg --host needs value\n"); return -1; }
        }else if( arg == "--port" ){
            cls_putit.port = parseInt(args[++i]);
            if( isNaN(cls_putit.port) ){ stdlog.write("Failed to parse --port: "+args[i]+"\n"); return -1; }
        }else if( arg == "--path" ){
            cls_putit.path = args[++i];
            if( !args[i] ){ stdlog.write("Arg --path expects a value\n"); return -1; }
        }else{
            stdlog.write("Unknown arg: "+ arg +"\n");
        }
    }
    if( !cls_putit.host ){ stdlog.write("Arg --host missing\n"); return -1; }
    if( !cls_putit.path ){ stdlog.write("Arg --path missing\n"); return -1; }
    return 0;
}


function main(){
    const cls_putit = Object.seal({
        host: null,
        port: null,
        path: null,
        pendingRequests: 0,
        httpAgent: null,
    });
    if( parseArgs(cls_putit, process.argv) ) return;
    cls_putit.httpAgent = new http.Agent({
        keepAlive:true, maxSockets:16, keepAliveMsecs: 42000,
    });
    putShowcase(cls_putit, onPutShowcaseComplete.bind(0,cls_putit));
}


function onPutShowcaseComplete( cls_putit ){
    stdout.write("Done :) Take a look at your gateleen. There's some trash for experimenting now.\n");
}


function putShowcase( cls_putit, onComplete ){
    const level1 = 10;
    const level2 = 3000;
    let body = {};
    for( let i=0 ; i<42 ; ++i ){
        body["prop-"+ i] = "Hi There :)";
    }
    body = JSON.stringify( body );
    stdlog.write("PUTting trash to http://"+ cls_putit.host +":"+ cls_putit.port + cls_putit.path +"\n");
    stdlog.write("Might take a moment. You can consult your CPU monitor meanwhile ;)\n");
    for( let iOne=0 ; iOne < level1 ; ++iOne ){
        for( let iTwo=0 ; iTwo < level2 ; ++iTwo ){
            const cls_req = Object.seal({
                cls_putit: cls_putit,
                onComplete: onComplete,
                req: null,
                rsp: null,
            });
            const req = cls_req.req = http.request({
                agent: cls_putit.httpAgent,
                host: cls_putit.host,
                port: cls_putit.port,
                path: cls_putit.path +"/levlA-"+iOne+"/levlB-"+(iTwo),
                method: "PUT",
            });
            req.on("error", function( err ){ console.error(err); });
            req.on("response", function( rsp ){
                cls_req.rsp = rsp;
                if( rsp.statusCode!=200 ){
                    stdlog.write( "ERROR: HTTP "+ rsp.statusCode +" "+ rsp.statusMessage +"\n" );
                }
                rsp.on("data", noop);
                rsp.on("end", onResponseEnd.bind(0,cls_req));
            });
            cls_putit.pendingRequests += 1;
            cls_req.req.end(body);
        }
    }
}


function onResponseEnd( cls_req ){
    const cls_putit = cls_req.cls_putit;
    cls_putit.pendingRequests -= 1;
    if( cls_putit.pendingRequests > 0 ){
        return; // Await more.
    }
    if( cls_req.onComplete ){
        cls_req.onComplete();
    }
}


}());
