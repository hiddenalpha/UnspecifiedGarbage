;(function(){

    const http = require("http");
    const log = process.stderr;
    const out = process.stdout;
    const NOOP = function(){};

    setTimeout(main); return;


    function main(){
        const app = Object.seal({
            isHelp: false,
            host: "localhost",
            port: 7013,
            uri: "/houston/tmp/gugus/bar",
            queueName: "my-gaga-queue",
        });
        if( parseArgs(app, process.argv) !== 0 ) process.exit(1);
        if( app.isHelp ){ printHelp(); return; }
        run(app);
    }



    function printHelp(){
        out.write("\n"
            +"  Produce a bunch of gateleen queues\n"
            +"  \n"
            +"  Options:\n"
            +"  \n"
            +"  \n")
    }


    function parseArgs( app, argv ){
        var isYolo = false;
        for( var iA = 2 ; iA < argv.length ; ++iA ){
            var arg = argv[iA];
            if( arg == "--help" ){
                app.isHelp = true; return 0;
            }else if( arg == "--yolo" ){
                isYolo = true;
            }else{
                log.write("EINVAL: "+ arg +"\n");
                return -1;
            }
        }
        if( !isYolo ){ log.write("EINVAL: wanna yolo?\n"); return; }
        return 0;
    }


    function run( app ){
        //placeHook(app);
        putSomeNonsense(app);
    }


    function placeHook( app ){
        const req = Object.seal({
            base: null,
            app: app,
        });
        req.base = http.request({
            host: app.host, port: app.port,
            method: "PUT", path: app.uri +"/_hooks/listeners/http",
            //headers: {
            //    "X-Expire-After": "42",
            //},
        });
        req.base.on("response", onResponse.bind(0, req));
        req.base.end(JSON.stringify({
            destination: "http://127.0.0.1:7099/guguseli",
            queueExpireAfter/*seconds*/: 42,
        }));
        function onResponse( req, rsp ){
            var app = req.app;
            log.write("[DEBUG] < HTTP/"+ rsp.httpVersion +" "+ rsp.statusCode +" "+ rsp.statusMessage +"\n");
            for( var k of Object.keys(rsp.headers) ) log.write("[DEBUG] < "+ k +": "+ rsp.headers[k] +"\n");
        }
    }


    function putSomeNonsense( app ){
        const nonsense = Object.seal({
            app: app,
            req: null,
            i: 0,
            limit: 42,
        });
        putNextRequest(nonsense);
        function putNextRequest( nonsense ){
            nonsense.req = http.request({
                host: app.host, port: app.port,
                method: "PUT", path: app.uri +"/foo/"+ nonsense.i,
                headers: {
                    "X-Queue": app.queueName +"-"+ nonsense.i,
                    "X-Queue-Expire-After": 9999999,
                },
            });
            nonsense.req.on("response", onResponse.bind(0, nonsense));
            nonsense.req.end("{\"guguseli\":\""+ new Date().toISOString() +"\"}\n");
        }
        function onResponse( nonsense, rsp ){
            var app = nonsense.app;
            log.write("[DEBUG] < HTTP/"+ rsp.httpVersion +" "+ rsp.statusCode +" "+ rsp.statusMessage +"\n");
            for( var k of Object.keys(rsp.headers) ) log.write("[DEBUG] < "+ k +": "+ rsp.headers[k] +"\n");
            rsp.on("data", NOOP);
            if( nonsense.i++ < nonsense.limit ){
                putNextRequest(nonsense);
            }
        }
    }


}());
