;(function(){
    "use static";

    const N = null;
    const createConnection = require("net").createConnection;
    const log = process.stderr;
    const out = process.stdout;


    function run( app ){
        app.sock = createConnection({
            host: app.peerHost,
            port: app.peerPort,
        });
        app.sock.on('connect', onSocketConnect.bind(N, app));
        //app.sock.on('close', );
        app.sock.on('data', onSocketData.bind(N, app));
        //app.sock.on('drain', );
        //app.sock.on('end', );
        //app.sock.on('error', );
        //app.sock.on('lookup', );
        //app.sock.on('ready', );
        //app.sock.on('timeout', );
    }


    function onSocketConnect( app ){
        app.sock.write("GET / HTTP/1.1\r\n"
            +"Host: "+ app.peerHost +":"+ app.peerPort +"\r\n"
            +"\r\n");
        log.write("onSocketConnect()\n");
    }


    function onSocketData( app, buf ){
        out.write(buf);
    }


    const newMultigetEncoder = (function(){
        return function(){
            const mGetEnc = {
                lastAction: null,
            };
            return Object.defineProperties({
                "beginPath": { value: onBeginPath.bind(N, mGetEnc) },
            });
        };
        function onBbeginPath( mGetEnc ){
        }
    }());


    function main(){
        const app = {
            peerHost: "127.0.0.1",
            peerPort: 8081,
            sock: null,
        };
        run(app);
    }


    setTimeout(main);

}());
