;(function(){

    const http = require("http");
    const log = process.stderr;
    const out = process.stdout;

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
        foo(app);
    }


    function foo( app ){
        const req = Object.seal({
            base: null,
        });
        req.base = http.request({
            host: app.host, port: app.port,
            method: "PUT", path: app.uri,
            headers: {
                "X-Queue": app.queueName,
                "X-Queue-Expire-After": 9999999,
            },
        });
        req.base.on("response", onResponse.bind(0, app));
        req.base.end("{\"guguseli\":42}\n");
    }


    function onResponse( app, rsp ){
        log.write("[DEBUG] < HTTP/"+ rsp.httpVersion +" "+ rsp.statusCode +" "+ rsp.statusMessage +"\n");
        for( var k of Object.keys(rsp.headers) ) log.write("[DEBUG] < "+ k +": "+ rsp.headers[k] +"\n");
    }


}());
