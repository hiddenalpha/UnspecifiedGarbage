;(function(){
    "use strict";

    exports.main = main;

    const assert = console.assert;
    const http = require("http");
    const stdout = process.stdout;
    const stdlog = process.stderr;


    function main( argv ){
        var app = Object.seal({
            gateleen: Object.seal({
                host: "127.0.0.1", port: 7013,
                path: "/houston",
            }),
            maxGateleenRequests: 1,
            numGateleenRequestsInProgress: 0,
            requestBacklog: [],
        });
        if( parseArgs(app, argv) !== 0 ){ process.exit(1); }
        run(app);
    }


    function printHelp( app ){
        stdout.write("\n"
            +"  Download subtrees from gateleen.\n"
            +"\n"
            +"  Options:\n"
            +"\n"
            +"    --example\n"
            +"      Run the hardcoded example.\n"
            +"\n");
    }


    function parseArgs( app, argv ){
        var isExample = false;
        for( var i=2 ; i<argv.length ; ++i ){
            var arg = argv[i];
            if( arg == "--help" ){
                printHelp(); return-1;
            }else if( arg == "--example" ){
                isExample = true;
            }else{
                stdlog.write("Unexpected arg: "+ arg +"\n");return-1;
            }
        }
        if( !isExample ){ stdlog.write("Bad arguments\n"); return-1; }
        return 0;
    }


    function run( app ){
        const gateleen = app.gateleen;
        const request = newRequestDto(app);
        request.segment = "data";
        request.parentRequest = null;
        enqueueGateleenRequest(app, request, "preflux", true);
    }


    function enqueueGateleenRequest( app, parent, segment, isDir ){
        assert(typeof(app)=="object", app);
        assert(typeof(parent)=="object", parent);
        assert(typeof(segment)=="string" && /^[^/]+$/.test(segment), segment);
        assert(typeof(isDir)=="boolean");
        //stdlog.write("enqueueGateleenRequest(a, p, '"+ segment +"', "+ isDir +")\n");
        const request = newRequestDto(app);
        request.segment = segment;
        request.isDir = isDir;
        request.parentRequest = parent;
        app.requestBacklog.push(request);
        mayTriggerNextGateleenRequest(app);
    }


    function newRequestDto( app ){
        assert(typeof(app)=="object");
        return Object.seal({
            app: app,
            parentRequest: null,
            segment: null,
            isDir: null,
            delegate: null,
            response: null,
            rspMime: null, rspCharset: null,
            rspJson: null,
        });
    }


    function getFullRequestPath( request ){
        assert(typeof(request.segment)=="string", request.segment);
        const p = request.parentRequest;
        if( p ){ return getFullRequestPath(p) +"/"+ request.segment; }
        else{ return request.app.gateleen.path +"/"+ request.segment; }
    }


    function mayTriggerNextGateleenRequest( app ){
        if( app.numGateleenRequestsInProgress >= app.maxGateleenRequests ){
            //stdlog.write("Request limit reached. Try later.\n");
            return; }
        app.numGateleenRequestsInProgress += 1;
        const request = app.requestBacklog.shift();
        if( request == null ){
            stdlog.write("Request backlog empty\n");
            app.numGateleenRequestsInProgress -= 1;
            return; }
        const path = getFullRequestPath(request);
        stdlog.write("GET "+ path +"\n");
        const gateleen = app.gateleen;
        request.delegate = http.request({
            host: gateleen.host, port: gateleen.port,
            method: "GET", path: path,
        }, onGateleenResponse.bind(0, request)).end();
    }


    function onGateleenResponse( request, rsp ){
        request.response = rsp;
        if( rsp.statusCode != 200 || rsp.statusMessage.toUpperCase() != "OK"){
            stdout.write(""+ rsp.statusCode +" "+ rsp.statusMessage +"\n");
        }
        var mime, charset;
        for( var k in rsp.headers ){
            var v = rsp.headers[k];
            //stdout.write(k +": "+ v +"\n");
            if( k.toUpperCase() == "CONTENT-TYPE" ){
                var m = v.match(/^(application\/json)(?:; *charset=([^; ]+))?$/);
                mime = m[1];
                charset = m[2];
            }
        }
        //stdout.write("\n");
        rsp.on("error", console.error.bind(console));
        if( request.isDir && rsp.statusCode == 200 && mime == "application/json" ){
            rsp.on("data", onGateleenRspDataDirListing.bind(0, request));
            rsp.on("end", onGateleenDirListingEnd.bind(0, request));
        }else{
            rsp.on("data", onGateleenRspDataOther.bind(0, request));
            rsp.on("end", onGateleenDataOtherEnd.bind(0, request));
        }
    }


    function onGateleenRspDataDirListing( request, buf ){
        request.rspJson = request.rspJson ? (request.rspJson + buf) : buf;
    }


    function onGateleenDirListingEnd( request ){
        const app = request.app;
        assert(request.isDir == true);
        const rspJson = JSON.parse(request.rspJson);
        app.numGateleenRequestsInProgress -= 1;
        const keys = Object.keys(rspJson);
        assert(keys.length == 1);
        var keyOfDirlist = keys[0];
        assert(keyOfDirlist == request.segment, keyOfDirlist, request.segment);
        var dirList = rspJson[keyOfDirlist];
        for( var elem of dirList ){
            var isDir = elem.endsWith("/");
            var name = isDir ? elem.substr(0, elem.length-1) : elem;
            enqueueGateleenRequest(app, request, name, isDir);
        }
    }


    function onGateleenRspDataOther( request, buf ){
        stdlog.write("onGateleenRspDataOther(l="+ buf.length +")\n");
    }


    function onGateleenDataOtherEnd( request ){
        const app = request.app;
        stdlog.write("onGateleenDataOtherEnd()\n");
        app.numGateleenRequestsInProgress -= 1;
        mayTriggerNextGateleenRequest(app);
    }


    if( require.main === module ){ main(process.argv); }

}());
