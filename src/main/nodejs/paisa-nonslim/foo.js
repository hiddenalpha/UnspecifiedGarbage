;(function(){ "use-strict";

    const child_process = require("child_process");
    const promisify = require("util").promisify;
    const zlib = require("zlib");
    const noop = function(){};
    const log = process.stderr;

    setImmediate(main);


    function parseArgs( argv, app ){
        log.write("[WARN ] TODO impl parseArgs()\n");
        return 0;
    }


    function workdirOfSync( app, thingyName ){
        if( typeof thingyName !== "string" || !/^[a-z-]+$/.test(thingyName) ) throw TypeError(thingyName);
        return "C:/work/projects/isa-svc/"+ thingyName;
    }


    function isWorktreeClean( app, thingyName, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        var child = child_process.spawn(
            "sh", [ "-c", "git status --porcelain | grep ." ],
            {   cwd: workdirOfSync(app, thingyName), windowsHide: true, }
        );
        child.on("error", console.error.bind(console));
        child.stdout.on("data", noop);
        child.stderr.on("data", function( buf ){ log.write(buf.toString()); });
        child.on("close", function( code, signal ){
            if( signal !== null ){
                throw Error("code "+ code +", signal "+ signal +"");
            }else{
                onDone(null, code !== 0);
            }
        });
    }


    function getDropSlimArtifactsTagInPlatformPatch( app, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        /* patch which empties the <slimArtifacts> tag in
         * "poms/service/paisa-service-superpom/pom.xml" as described in
         * SDCISA-15648 */
        var patch = ""
            +"tVnNcuMoEL7nKbTXzUKc2WRmQk1tZav2Ppd9AYRaEgoCCpBj79NvI0u2E9uJxUg+CJDpr4Fu+k+F"
            +"LMuMkEqGjN9Z0/o7D24tBdxZLj0nw4j4zoLD/+McumlVlk+ZfSN1AZssL+9L8fj9cUXpt+JhxfFR"
            +"Zver1deHhxtCyLQV3Nze3k5cxfNzRp5W9398f8puY/ste36+yT77/birDFf+rytmCqNLWXWOB2n0"
            +"FQQ9kXUG1xkkIAtyFUmk8kq2fyNVyUWYQhh/3FiulORaADvq//iNkH9//vOTZRrW4LJCOhBBbbPO"
            +"Q5FJnVnFQ2lcS8hEhqKm1vhAZaC9iChXMvJWvZgGce0ODxsHC6AXpuVSL4WOMhTg/VLwylSV1Iud"
            +"zSvkCdDGVZR7iyrSsKF9BY6K0+uR49rLINcw6k++zbx1cRe7yX6yFp1h6MKCSotWo+Q+gEPbwYTi"
            +"3rc8wMXd1TIHp3EGWePxFjwYl8RTG1DSeOrABwWBnXlHYRNolB72L66naaWWm6WWMDvbg6Iit9Zo"
            +"GjWS7fq9dpIWAsdj5ZP3gwie5MB1F6Ty7OTNAkfYMxCmAMHejFKBlEKtRqfi2Zl3aaClVNBZZXjB"
            +"Tl+lQUrDDt00CMV1xY4HiTA7i8nejWcFI9zK2QHZ0xNdobcCT7QJBDbSh2lMNNoHX1KoBRc1sKFN"
            +"MPAj0H+tcbZmQzv3ZYlWfW866d50sjPm9FeAG77mG4qBlscDhRj5HBg0lpMv9H66PHuPZOPx0joE"
            +"i+K0RoMOnvVDJbE/K2Kak76I18p2ajxx7BTxUMWLH031MCBco+LyNMP0GXZCAPQ5aPQpOWYocwBH"
            +"rLC1b8HjC9J49+f96nJsVEOhjHhJuj9VDE5K6WuKoRzbqTqoaTgj1Z58+nXYUR7kz96/SLKY1Hea"
            +"YpYj1yPoC3eBH71KWWUUWhQ6wm3y9HW9hUlTz1Mc2dqJ0ota0OTGezr6ln40epZFg9bI26vyoWGN"
            +"UMRgFE764XKheb/b3t2wXTNRA0zBSUDbx/a9JM/YxAuuJN64obNELF4ZUymgMXqkJWpI3lWeRWOy"
            +"epwGJg2tZKi7vPeFBIWOa0QkPzEoPRJ3p0gw54U9i4wHzzUocWyRa/9MzVcvAyY5/zFBOur3uRkK"
            +"3wgZtksES2d4XmRzJnFL4GmQl1kw4RsqExj8DuleeoD9AWjMl9E0zYPpt+j5W+LRr3V+3nVimuuk"
            +"mAkTheSIgwqDXpfqgs/hrqGWQqFi6Rdizet851pzBwUap7Ws5lzvESDezDmRY1kRE4pYQCUmj0qW"
            +"iH6wq/0zEaAvsZWOt/Bq3AsbS27GflaVw8ixXYs053+B6a7ONxterNdcrtUctjHnHoRB4W4SkriP"
            +"8eK3CWvcnLgp7vACGGwsOgs/ObL+ADLA1DLGB2Ao4zmxUO1TMoghYI4pyaH7SzWEMWpgn4YP0OZQ"
            +"FGgom3YT4oTEEHpHTEc4doKbvJehtLUvcVlj1JcF9xND8igX4bo293RMp9k+r97Je2bQtKJa3inV"
            +"47Yo52LLDt3Ee9w4g8kj2zXTU4xQm66qQ7wWnm4wUgDesqGd8Eny7t03ydurKd8SngBdyf74Q+qV"
            +"fE3nBFw5O/4wMUer3RsAqjGhigVz+vvN/wsTxCQ="
        ;
        patch = Buffer.from(patch, 'base64');
        patch = zlib.inflateRaw(patch, function( ex, patch ){
            if( ex ){ throw ex; }
            setImmediate(onDone, null, patch);
        });
    }


    function getJettyServiceNamesAsArray( app, onDone ){
        setImmediate(onDone, null, [ /*TODO get via args/file */
            TODO_1zwCAF4NAgAfcAIA628CAJE4AgDnRgIA
        ]);
    }


    function dropSlimFromAllJenkinsfiles( app, onDone ){
        var iSvc = -1;
        var jettyServices;
        var jettyService;
        getJettyServiceNamesAsArray(app, function( ex, jettyServices_ ){
            if( ex ){ throw ex; }
            jettyServices = jettyServices_;
            nextJettyService();
        });
        function nextJettyService(){
            if( ++iSvc >= jettyServices.length ){ onNoMoreJettyServices(); return; }
            jettyService = jettyServices[iSvc];
            isWorktreeClean(app, jettyService, onIsWorktreeCleanRsp);
        }
        function onIsWorktreeCleanRsp( ex, isClean ){
            if( ex ) throw ex;
            if( !isClean ){
                log.write("[WARN ] Worktree not clean. Will skip: "+ jettyService +"\n");
                nextJettyService();
                return;
            }
            log.write("[DEBUG] Patching \""+ jettyService +"/Jenkinsfile\"\n");
            var child = child_process.spawn(
                "sed", [ "-i", "-E", "s_^(.*?buildMaven.*?),? *slim: *true,? *(.*?)$_\\1\\2_", "Jenkinsfile" ],
                { cwd: workdirOfSync(app, jettyService) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", function( buf ){ log.write(buf.toString()); });
            child.on("close", function(){
                nextJettyService();
            });
        }
        function onNoMoreJettyServices( app ){
            onDone(null, null);
        }
    }


    function checkoutUpstreamDevelop( app, thingyName, onDone){
        var child;
        child = child_process.spawn(
            "sh", ["-c", "git checkout upstream/develop || git checkout origin/develop"],
            { cwd: workdirOfSync(app, thingyName), });
        child.on("error", console.error.bind(console));
        child.stderr.on("data", function( buf ){ log.write(buf); });
        child.on("close", function( code, signal ){
            if( code !== 0 || signal !== null ){
                onDone(Error("code "+ code +", signal "+ signal));
            }else{
                onDone(null, null);
            }
        });
    }


    function checkoutUpstreamDevelopForAllJettyServices( app, onDone){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        var iSvc = -1, jettyServices, jettyService;
        getJettyServiceNamesAsArray(app, function( ex, ret ){
            if( ex ) throw ex;
            jettyServices = ret;
            nextJettyService();
        });
        function nextJettyService( ex ){
            if( ex ) throw ex;
            if( ++iSvc >= jettyServices.length ){ onDone(null, null); return; }
            jettyService = jettyServices[iSvc];
            log.write("[DEBUG] git checkout "+ jettyService +"\n");
            checkoutUpstreamDevelop(app, jettyService, nextJettyService);
        }
    }


    function fetchChangesFromGitit( app, thingyName, onDone ){
        var child;
        child = child_process.spawn(
            "sh", ["-c", "git fetch upstream || git fetch origin"],
            { cwd: workdirOfSync(app, thingyName), });
        child.on("error", console.error.bind(console));
        child.stderr.on("data", function( buf ){ log.write(buf); });
        child.on("close", function( code, signal ){
            if( code !== 0 || signal !== null ){
                onDone(Error("code "+ code +", signal "+ signal));
            }else{
                onDone(null, null);
            }
        });
    }


    function fetchChangesFromGititForAllJettyServices( app, onDone ){
        var iSvc = -1, jettyServices, jettyService;
        getJettyServiceNamesAsArray(app, function( ex, ret ){
            if( ex ) throw ex;
            jettyServices = ret;
            nextJettyService();
        });
        function nextJettyService( ex ){
            if( ex ) throw ex;
            if( ++iSvc >= jettyServices.length ){ onDone(null, null); return; }
            jettyService = jettyServices[iSvc];
            log.write("[DEBUG] git fetch "+ jettyService +"\n");
            fetchChangesFromGitit(app, jettyService, nextJettyService);
        }
    }


    function patchAwaySlimPackagingInPlatform( app, onDone ){
        isWorktreeClean(app, "platform", function( ex, isClean ){
            if( ex ){ throw ex; }
            if( !isClean ){ onDone(Error("Platform worktree not clean")); return; }
            getDropSlimArtifactsTagInPlatformPatch(app, onPatchBufReady);
        });
        function onPatchBufReady( ex, patch ){
            if( ex ){ throw ex; }
            var gitApply = child_process.spawn(
                "sh", ["-c", "git apply"],
                { cwd: workdirOfSync(app, "platform"), });
            gitApply.on("error", console.error.bind(console));
            gitApply.stderr.on("data", function( buf ){ log.write(buf.toString()); });
            gitApply.stdout.on("data", noop);
            gitApply.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){ throw Error(""+ code +", "+ signal +""); }
                onDone(null, null);
            });
            gitApply.stdin.write(patch);
            gitApply.stdin.end();
        }
    }


    function run( app ){
        patchAwaySlimPackagingInPlatform(app, onPatchAwaySlimPackagingInPlatformDone);
        function onPatchAwaySlimPackagingInPlatformDone( ex, ret ){
            if( ex ){ log.write("[WARN ] "+ ex.message +"\n"); /*throw ex;*/ }
            fetchChangesFromGititForAllJettyServices(app,
                onFetchChangesFromGititForAllJettyServicesDone);
        }
        function onFetchChangesFromGititForAllJettyServicesDone( ex ){
            if( ex ){ throw ex; }
            checkoutUpstreamDevelopForAllJettyServices(app,
                onCheckoutUpstreamDevelopForAllJettyServicesDone);
        }
        function onCheckoutUpstreamDevelopForAllJettyServicesDone( ex ){
            if( ex ) throw ex;
            dropSlimFromAllJenkinsfiles(app, onDropSlimFromAllJenkinsfilesDone);
        }
        function onDropSlimFromAllJenkinsfilesDone( ex ){
            if( ex ){ throw ex; }
            log.write("[INFO ] App done\n");
        }
    }


    function main(){
        const app = Object.seal({
            isHelp: false,
            maxParallel:  1,
        });
        if( parseArgs(process.argv, app) !== 0 ){ os.exit(1); }
        if( app.isHelp ){ printHelp(); return; }
        run(app);
    }


}());
