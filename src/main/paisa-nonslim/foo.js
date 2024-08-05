/*

Related:
- [Remove Slim Packaging](SDCISA-15648)

*/
;(function(){ "use-strict";

    const child_process = require("child_process");
    const http = require("http");
    const https = require("https");
    const fs = require("fs");
    const promisify = require("util").promisify;
    const zlib = require("zlib");
    const noop = function(){};
    const log = process.stderr;
    const out = process.stdout;
    const logAsString = function( buf ){ log.write(buf.toString()); };

    setImmediate(main);


    function printHelp( argv, app ){
        process.stdout.write("  \n"
            +"  Autmoate some steps that are tedious manually.\n"
            +"  \n"
            +"  Options:\n"
            +"  \n"
            +"    --fetch\n"
            +"      Update local repos from remote.\n"
            +"  \n"
            +"    --reset-platform\n"
            +"      Reset worktree to develop.\n"
            +"  \n"
            +"    --patch-platform\n"
            +"      Remove slim packaging from patform and set snapshot version.\n"
            +"  \n"
            +"    --push-platform\n"
            +"      Same idea as '--push-services' but for platform.\n"
            +"  \n"
            +"    --reset-services\n"
            +"      Reset worktree to develop.\n"
            +"  \n"
            +"    --patch-services\n"
            +"      Disable slim packaging in Jenkinsfile and use platform snapshot in\n"
            +"      pom.\n"
            +"  \n"
            +"    --commit\n"
            +"      Create a git commit with our changes.\n"
            +"  \n"
            +"    --push | --push-force\n"
            +"      Create commits for patched services and push them to upstream. If\n"
            +"      not given, the change is only made locally (aka without cluttering\n"
            +"      remote git repo). The force variant will replace existing branches\n"
            +"      on the remnote. If given multiple times, less-invasive wins.\n"
            +"  \n"
            +"    --print-isa-version\n"
            +"      Prints an isaVersion JSON that can be fed to preflux.\n"
            +"  \n"
            +"    --print-baseline-version\n"
            +"      Prints an isaVersion JSON that can be fed to preflux. Consisting\n"
            +"      of the latest versions found for each service.\n"
            +"  \n"
            // not impl yet
            //+"    --max-parallel <int>\n"
            //+"      How many tasks to run concurrently. Defaults to 1. Which means to\n"
            //+"      do all the work sequentially (HINT: very handy for debugging).\n"
            //+"  \n"
        );
    }


    function parseArgs( argv, app ){
        if( argv.length <= 2 ){
            log.write("EINVAL: Refuse to produce damage with zero args.\n");
            return -1;
        }
        for( var iA = 2 ; iA < argv.length ; ++iA ){
            var arg = argv[iA];
            if( arg == "--help" ){
                app.isHelp = true; return 0;
            }else if( arg == "--fetch" ){
                app.isFetch = true;
            }else if( arg == "--reset-platform" ){
                app.isResetPlatform = true;
            }else if( arg == "--patch-platform" ){
                app.isPatchPlatform = true;
            }else if( arg == "--commit-platform" ){
                app.isCommitPlatform = true;
            }else if( arg == "--push-platform" ){
                app.isPushPlatform = true;
            }else if( arg == "--reset-services" ){
                app.isResetHard = true;
            }else if( arg == "--patch-services" ){
                app.isPatchServices = true;
            }else if( arg == "--commit" ){
                app.isCommit = true;
            }else if( arg == "--push" ){
                if( app.isPushForce ){ log.write("EINVAL: only one of push and push-force allowed\n"); return-1; }
                app.isPush = true;
            }else if( arg == "--push-force" ){
                if( app.isPush ){ log.write("EINVAL: only one of push and push-force allowed\n"); return-1; }
                app.isPushForce = true;
            }else if( arg == "--print-isa-version" ){
                app.isPrintIsaVersion = true;
            }else if( arg == "--print-baseline-version" ){
                app.isPrintBaselineVersion = true;
            //}else if( arg == "--max-parallel" ){
            //    arg = argv[++iA];
            //    if( !/^[0-9]+$/.test(arg) ){ log.write("EINVAL: --max-parallel "+ arg +"\n"); return -1; }
            //    app.maxParallel = 0 + arg;
            }else{
                log.write("EINVAL: "+ arg +"\n");
                return -1;
            }
        }
        return 0;
    }


    function isThingyNameValid( app, thingyName ){
        if( typeof thingyName !== "string" ) return false;
        if( !/^[a-z-]+$/.test(thingyName) ) return false;
        return true;
    }


    function workdirOfSync( app, thingyName ){
        if( !isThingyNameValid(app, thingyName) ) throw TypeError(thingyName);
        return app.workdir +"/"+ thingyName;
    }


    function gitUrlOfSync( app, thingyName ){
        if( !isThingyNameValid(app, thingyName) ) throw TypeError(thingyName);
        return "https://gitit.post.ch/scm/isa/"+ thingyName +".git";
    }


    function isCloned( app, thingyName, onDone){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        var child = child_process.spawn(
            "git", ["status", "--porcelain"],
            { cwd: workdirOfSync(app, thingyName), }
        );
        child.on("error", console.error.bind(console));
        child.stdout.on("data", noop);
        child.stderr.on("data", logAsString);
        child.on("close", function( code, signal ){
            if( code !== 0 || signal !== null ){
                onDone(Error("code "+ code +", signal "+ signal));
            }else{
                onDone(null, true);
            }
        });
    }


    function isWorktreeClean( app, thingyName, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        var isStdoutDirty = false;
        var child = child_process.spawn(
            "git", ["status", "--porcelain"],
            { cwd: workdirOfSync(app, thingyName), }
        );
        child.on("error", console.error.bind(console));
        child.stdout.on("data", function(){ isStdoutDirty = true; });
        child.stderr.on("data", logAsString);
        child.on("close", function( code, signal ){
            if( signal !== null ){
                throw Error("code "+ code +", signal "+ signal +"");
            }else{
                onDone(null, !isStdoutDirty);
            }
        });
    }


    function getPatch( app, thingyName, onDone ){
        var path = __dirname +"/patches/"+ thingyName +".patch";
        var patchAsStr;
        var mangledPlatformVersion, mangledServiceVersion, mangledSlartiVersion;
        var propsToReplace = [ "j21.service.mangledVersion", "j21.platform.version",
            "j21.captain.mangledVersion", "j21.slarti.mangledVersion" ];
        var propValsByKey = {};
        fs.readFile(path, 'utf8', TODO_sBECAHhRAgCcPAIA);
        function TODO_sBECAHhRAgCcPAIA( ex, patchAsStr_ ){
            if( ex && ex.code == "ENOENT" ){
                onDone(null, null); return;
            }else if( ex ){
                onDone(ex); return;
            }
            patchAsStr = patchAsStr_;
            getNextProperty();
        }
        function getNextProperty(){
            var k = propsToReplace.shift();
            if( !k ){ replaceProperties(); return; }
            if( !new RegExp("\\${"+ k +"}").test(patchAsStr) ){ getNextProperty(); return; }
            var subj = false ? null
                : (k == "j21.service.mangledVersion") ? thingyName
                : (k == "j21.platform.version") ? "platform"
                : null;
            if( !subj ){ subj = /^j21.([^.]+).mangledVersion$/.exec(k)[1]; }
            if( !subj ){ onDone(Error("TODO_NkICAG1HAgCDYgIA "+ k)); return; }
            getVersionPipelineMangledByThingyName(app, subj, function( ex, val ){
                if( ex ){ onDone(ex); return; }
                propValsByKey[k] = val;
                getNextProperty();
            });
        }
        function replaceProperties( ex ){
            if( ex ){ onDone(ex); return; }
            for( var k of Object.keys(propValsByKey) ){
                var v = propValsByKey[k];
                patchAsStr = patchAsStr.replace(new RegExp("\\${"+ k +"}", "g"), v);
            }
            onDone(null, patchAsStr);
        }
    }


    function getDropSlimArtifactsTagInPlatformPatch( app, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        /* patch which empties the <slimArtifacts> tag in
         * "poms/service/paisa-service-superpom/pom.xml" as described in
         * SDCISA-15648 */
        var patch = ""
            +"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"
        ;
        patch = Buffer.from(patch, 'base64');
        patch = zlib.inflateRaw(patch, function( ex, patch ){
            if( ex ){ throw ex; }
            setImmediate(onDone, null, patch);
        });
    }


    function getJettyServiceNamesAsArray( app, onDone ){
        setImmediate(onDone, null, [ /*TODO get via args/file */
        ]);
    }


    function getMangledPlatformVersion( app, onDone ){
        if( app.mangledPlatformVersion != null ){
            setTimeout(TODO_TRQCAEYoAgAbPQIA, 0, null, app.mangledPlatformVersion);
        }else{
            getVersionPipelineMangledByThingyName(app, "platform", TODO_TRQCAEYoAgAbPQIA);
        }
        function TODO_TRQCAEYoAgAbPQIA( ex, mangledPlatformVersion ){
            if( !mangledPlatformVersion ){ onDone(Error("mangledPlatformVersion failed")); return; }
            if( app.mangledPlatformVersion != null && app.mangledPlatformVersion != mangledPlatformVersion ){
                onDone(Error("assert("+ app.mangledPlatformVersion +" == "+ mangledPlatformVersion +")")); return;
            }
            onDone(null, app.mangledPlatformVersion = mangledPlatformVersion);
        }
    }


    function getVersionPipelineMangledByThingyName( app, thingyName, onDone ){
        var rspBody = "";
        var path, host = "artifactory.pnet.ch", port = 443, method = "GET";
        collectVersionFromArtifactory();
        function collectVersionFromArtifactory(){
            path = (thingyName == "platform")
                ? "/artifactory/paisa/ch/post/it/paisa/alice/alice-service-web-core/"
                : "/artifactory/paisa/ch/post/it/paisa/"+ thingyName +"/"+ thingyName +"-web/";
            var req = https.request({
                method: method, host: host, port: port, path: path,
            });
            req.on("error", console.log.bind(console));
            req.on("response", TODO_Nw8CALZgAgCEbAIA);
            req.end();
        }
        function TODO_Nw8CALZgAgCEbAIA( rsp ){
            if( rsp.statusCode != 200 ){
                log.write("[ERROR] thingyName '"+ thingyName +"'\n");
                log.write("[ERROR] HTTP "+ rsp.statusCode +"\n");
                onDone(Error("HTTP "+ rsp.statusCode)); return;
            }
            rsp.on("data", function( cnk ){ rspBody += cnk.toString(); });
            rsp.on("end", TODO_MRYCAOIzAgAKFQIA);
        }
        function TODO_MRYCAOIzAgAKFQIA(){
            var pat = new RegExp('\n<a href="(0.0.0-'+ app.issueKey +'-[^/]+-SNAPSHOT)/">[^<]+</a> +([0-9]{2})-([A-Za-z]{3})-([0-9]{4}) ([0-9]{2}):([0-9]{2}) +-', "g");
            var latestVersion, latestDate;
            rspBody.replace(pat, function( match, version, day, mthShrt, yr, hrs, mins, off, rspBody, groupNameMap ){
                /* [FUCK those FUCKING DAMN bullshit formats!!!](https://xkcd.com/1179/) */
                var mth = (mthShrt == "Jul") ? "07" : null;
                if( !mth ){ throw Error("TODO_1iUCAA1ZAgBALgIA "+ mthShrt); }
                var builtAt = yr +"-"+ mth +"-"+ day +" "+ hrs +":"+ mins;
                if( latestVersion == null || builtAt > latestDate ){
                    latestVersion = version;
                    latestDate = builtAt;
                }
                return match;
            });
            if( !latestVersion ){
                log.write("[DEBUG] "+ method +" "+ host +":"+ port + path +"\n");
                onDone(Error("No version found for '"+ thingyName +"' in artifactory")); return;
            }
            onDone(null, latestVersion);
        }
    }


    function getVersionLatestRelease( app, thingyName, onDone ){
        var rspBody = "";
        var path, host = "artifactory.pnet.ch", port = 443, method = "GET";
        collectVersionFromArtifactory();
        function collectVersionFromArtifactory(){
            path = (thingyName == "platform")
                ? "/artifactory/paisa/ch/post/it/paisa/alice/alice-service-web-core/"
                : "/artifactory/paisa/ch/post/it/paisa/"+ thingyName +"/"+ thingyName +"-web/";
            var req = https.request({
                method: method, host: host, port: port, path: path,
            });
            req.on("error", console.log.bind(console));
            req.on("response", TODO_7QwCACAXAgDYFAIA);
            req.end();
        }
        function TODO_7QwCACAXAgDYFAIA( rsp ){
            if( rsp.statusCode != 200 ){
                log.write("[ERROR] thingyName '"+ thingyName +"'\n");
                log.write("[ERROR] HTTP "+ rsp.statusCode +"\n");
                onDone(Error("HTTP "+ rsp.statusCode)); return;
            }
            rsp.on("data", function( cnk ){ rspBody += cnk.toString(); });
            rsp.on("end", TODO_xwwCAHdnAgBOVQIA);
        }
        function TODO_xwwCAHdnAgBOVQIA(){
            var pat = new RegExp('\n<a href="([0-9]+\\.[0-9]+\\.[0-9]+\\.(?:[0-9]+)?)/">[^<]+</a> +([0-9]{2})-([A-Za-z]{3})-([0-9]{4}) ([0-9]{2}):([0-9]{2}) +-', "g");
            var latestVersion, latestDate;
            rspBody.replace(pat, function( match, version, day, mthShrt, yr, hrs, mins, off, rspBody, groupNameMap ){
                /* [FUCK those FUCKING DAMN bullshit formats!!!](https://xkcd.com/1179/) */
                var mth = (false) ? null
                    : (mthShrt == "Jan") ? "01" : (mthShrt == "Feb") ? "02" : (mthShrt == "Mar") ? "03"
                    : (mthShrt == "Apr") ? "04" : (mthShrt == "May") ? "05" : (mthShrt == "Jun") ? "06"
                    : (mthShrt == "Jul") ? "07" : (mthShrt == "Aug") ? "08" : (mthShrt == "Sep") ? "09"
                    : (mthShrt == "Oct") ? "10" : (mthShrt == "Nov") ? "11" : (mthShrt == "Dec") ? "12"
                    : null;
                if( !mth ){ throw Error("TODO_pAwCADRpAgB3TwIA "+ mthShrt); }
                var builtAt = yr +"-"+ mth +"-"+ day +" "+ hrs +":"+ mins;
                if( latestVersion == null || builtAt > latestDate ){
                    latestVersion = version;
                    latestDate = builtAt;
                }
                return match;
            });
            if( !latestVersion ){
                log.write("[DEBUG] "+ method +" "+ host +":"+ port + path +"\n");
                onDone(Error("No version found for '"+ thingyName +"' in artifactory")); return;
            }
            onDone(null, latestVersion);
        }

    }


    function printIsaVersionNoslim( app, onDone ){
        var iSvcGetVersion = 0, iSvcQuery = 0, iSvcPrinted = 0;
        var rspBody = "";
        var nameVersionArr = [];
        var services = app.services.slice(0);
        services.unshift("platform");
        collectNextVersionFromArtifactory();
        function collectNextVersionFromArtifactory( ex ){
            if( ex ){ onDone(ex); return; }
            if( iSvcGetVersion < services.length ){
                var thingyName = services[iSvcGetVersion++];
                getVersionPipelineMangledByThingyName(app, thingyName, TODO_OBgCAKAhAgCcXwIA.bind(0, thingyName));
            }else{
                printIsaVersion(app, nameVersionArr, onDone);
            }
        }
        function TODO_OBgCAKAhAgCcXwIA( thingyName, ex, mangledVersion ){
            if( ex ){ onDone(ex); return; }
            log.write("[DEBUG] versionsByThingy[\""+ thingyName +"\"] = \""+ mangledVersion +"\"\n");
            nameVersionArr.push({ name:thingyName, version:mangledVersion });
            collectNextVersionFromArtifactory();
        }
    }


    function printBaselineVersion( app, onDone ){
        var iSvcGetVersion = 0;
        var services = app.services.slice(0);
        var nameVersionArr = [];
        services.unshift("platform");
        collectNextVersionFromArtifactory();
        function collectNextVersionFromArtifactory( ex ){
            if( ex ){ onDone(ex); return; }
            if( iSvcGetVersion < services.length ){
                var thingyName = services[iSvcGetVersion++];
                getVersionLatestRelease(app, thingyName, TODO_vwECAA4wAgCgEgIA.bind(0, thingyName));
            }else{
                printIsaVersion(app, nameVersionArr, onDone);
            }
        }
        function TODO_vwECAA4wAgCgEgIA( thingyName, ex, version ){
            if( ex ){ onDone(ex); return; }
            log.write("[DEBUG] versionsByThingy[\""+ thingyName +"\"] = \""+ version +"\"\n");
            nameVersionArr.push({ name:thingyName, version:version });
            collectNextVersionFromArtifactory();
        }
    }


    function printIsaVersion( app, nameVersionArr, onDone ){
        var iSvcQuery = 0, iSvcPrinted = 0;
        printIntro();
        function printIntro( ex ){
            if( ex ) throw ex;
            var epochMs = Date.now();
            out.write('{\n');
            out.write('  "timestamp": "'+ new Date().toISOString() +'",\n');
            out.write('  "isaVersionId": "SDCISA-15648-'+ epochMs +'",\n');
            out.write('  "isaVersionName": "SDCISA-15648-'+ epochMs +'",\n');
            out.write('  "trial": true,\n');
            out.write('  "services": [\n');
            out.write('    { "name": "eagle", "version": "02.01.26.00" },\n');
            out.write('    { "name": "storage", "version": "00.25.00.02" },\n');
            out.write('    { "name": "desiato", "version": "00.15.00.00" },\n');
            out.write('    { "name": "fenchurch", "version": "04.01.00.01" },\n');
            out.write('    { "name": "nova", "version": "14.181.1" },\n');
            out.write('    { "name": "hafas", "version": "5.41.SBB.4.15.8" },\n');
            out.write('    { "name": "data-fis-106", "version": "00.36.09.27" },\n');
            out.write('    { "name": "data-fis-17", "version": "00.36.09.24" },\n');
            out.write('    { "name": "data-fis-13", "version": "00.36.09.25" },\n');
            out.write('    { "name": "data-fis-32", "version": "00.36.09.25" },\n');
            out.write('    { "name": "data-fis-63", "version": "00.36.09.24" },\n');
            out.write('    { "name": "data-fis-65", "version": "00.36.05.48.int" },\n');
            out.write('    { "name": "data-fis-4", "version": "00.36.09.22" },\n');
            out.write('    { "name": "data-sale", "version": "01.38.268.01" },\n');
            out.write('    { "name": "data-nova", "version": "14.181.0.20240704-1311.P.P.8937.0" },\n');
            out.write('    { "name": "data-fis-9", "version": "00.36.09.34" },\n');
            out.write('    { "name": "data-fis-1", "version": "00.36.09.25" },\n');
            out.write('    { "name": "data-fpd", "version": "36.24.28.02" },\n');
            out.write('    { "name": "data-fis-14", "version": "00.36.09.22" },\n');
            out.write('    { "name": "data-forms", "version": "01.03.02.03" },\n');
            out.write('    { "name": "data-fis-3", "version": "00.36.09.27" },\n');
            out.write('    { "name": "data-fis-105", "version": "00.36.09.27" },\n');
            out.write('    { "name": "data-fis-64", "version": "00.36.09.26" }');
            nextService();
        }
        function nextService( ex ){
            if( ex ) throw ex;
            if( iSvcQuery >= nameVersionArr.length ){ /*printTail();*/ return; }
            var thingy = nameVersionArr[iSvcQuery++];
            var thingyName = thingy.name;
            var svcVersion = thingy.version;
            if( typeof svcVersion != "string") throw Error(thingyName +", "+ svcVersion);
            iSvcPrinted += 1;
            out.write(",\n    ");
            out.write('{ "name": "'+ thingyName +'", "version": "'+ svcVersion +'" }');
            if( iSvcPrinted >= nameVersionArr.length ){ printTail(); }else{ nextService(); }
        }
        function printTail( ex ){
            if( ex ) throw ex;
            out.write('\n');
            out.write('  ],\n');
            out.write('  "featureSwitches": [],\n');
            out.write('  "mergedBundles": []\n');
            out.write('}\n');
            onDone(/*ex*/null, /*ret*/null);
        }
    }


    function pushPlatform( app, onDone ){
        pushService(app, "platform", onDone);
    }


    function pushService( app, thingyName, onDone ){
        if( typeof onDone != "function" ){ throw TypeError("onDone"); }
        var iRemoteNameToTry = 0;
        push();
        function push( ex, isClean ){
            if( ex ) throw ex;
            var remoteName = app.remoteNamesToTry[iRemoteNameToTry++];
            if( remoteName === undefined ){ endFn(Error("No more remote names. s="+ thingyName +"")); return; }
            log.write("[DEBUG] "+ thingyName +" - git push "+ remoteName +" "
                + app.branchName +(app.isPushForce?" --force":"")+"\n");
            argv = ["push", remoteName, "refs/heads/"+app.branchName +":refs/heads/"+ app.branchName];
            if( app.isPushForce ) argv.push("--force");
            var child = child_process.spawn(
                "git", argv,
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code === 128 ){ /* retry with next upstream name */
                    push(); return;
                }else if( code !== 0 || signal !== null ){
                    endFn(Error("code="+ code +", signal="+ signal +""));
                    return;
                }
                endFn();
            });
        }
        function endFn( ex, ret ){
            onDone(ex, ret);
        }
    }


    function commitPlatform( app, onDone ){
        commitService(app, "platform", onDone);
    }


    function commitService( app, thingyName, onDone ){
        if( typeof onDone != "function" ){ throw Error("onDone"); }
        incrNumTasks(app);
        isWorktreeClean(app, thingyName, gitAdd);
        function gitAdd( ex, isClean ){
            if( ex ) throw ex;
            if( isClean ){
                log.write("[INFO ] Nothing to commit in \""+ thingyName +"\"\n");
                endFn(null, null); return;
            }
            log.write("[DEBUG] "+ thingyName +"$ git add Jenkinsfile\n");
            var child = child_process.spawn(
                "git", ["add", "--", "."],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    endFn(Error("code="+ code +", signal="+ signal +""));
                    return;
                }
                gitCommit();
            });
        }
        function gitCommit( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] "+ thingyName +"$ git commit -m \""+ app.commitMsg +"\"\n");
            var child = child_process.spawn(
                "git", ["commit", "-m", app.commitMsg],
                { cwd:workdirOfSync(app, thingyName) }
            );
            var stdoutBufs = [];
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.stdout.on("data", function( buf ){ stdoutBufs.push(buf); });
            child.on("exit", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    var stdoutStr = "";
                    for( var buf in stdoutBufs ){ log.write(buf.toString()); }
                    endFn(Error("code="+ code +", signal="+ signal));
                    return;
                }
                createBranch(); return;
            });
        }
        function createBranch( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] "+ thingyName +"$ git branch "+ app.branchName +"\n");
            var child = child_process.spawn(
                "git", ["branch", "-f", app.branchName],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("exit", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    endFn(Error("code="+ code +", signal="+ signal +""));
                    return;
                }
                endFn(); return;
            });
        }
        function endFn( ex, ret ){
            decrNumTasks(app);
            onDone(ex, ret);
        }
    }


    function commitAllServices( app, onDone ){
        var iSvc = 0;
        var services;
        incrNumTasks(app);
        getJettyServiceNamesAsArray(app, onGetJettyServiceNamesAsArrayDone);
        function onGetJettyServiceNamesAsArrayDone( ex, ret ){
            if( ex ) throw ex;
            services = ret;
            nextService(null);
        }
        function nextService( ex ){
            if( ex ) throw ex;
            if( iSvc >= services.length ){ endFn(null); return; }
            var thingyName = services[iSvc++];
            if( !thingyName ) throw Error("assert(thingyName != NULL)");
            commitService(app, thingyName, nextService);
        }
        function endFn( ex ){
            decrNumTasks(app);
            if( ex ) throw ex;
            log.write("[DEBUG] No more services to commit\n");
            onDone(null, null);
        }
    }


    function giveServiceOurSpecialVersion( app, thingyName, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        doit();
        function doit( ex ){
            if( ex ) throw ex;
            var child = child_process.spawn(
                "mvn", ["versions:set", "-DgenerateBackupPoms=false", "-DallowSnapshots=true",
                    "-DnewVersion="+ app.serviceSnapVersion],
                { cwd: workdirOfSync(app, thingyName) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                    return;
                }
                onDone();
            });
        }
    }


    function setPlatformVersionInService( app, thingyName, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        TODO_vFICAIhVAgBuAgIA();
        function TODO_vFICAIhVAgBuAgIA(){
            getMangledPlatformVersion(app, updateParent);
        }
        function updateParent( ex, mangledPlatformVersion ){
            if( !mangledPlatformVersion ){ onDone(Error("mangledPlatformVersion missing: "+ thingyName)); return; }
            log.write("[DEBUG] "+ thingyName +" - Set platform version "+ mangledPlatformVersion +"\n");
            var child = child_process.spawn(
                "mvn", ["versions:update-parent", "-DgenerateBackupPoms=false", "-DallowDowngrade=true",
                    "-DallowSnapshots=true", "-DforceUpdate=true", "-DskipResolution=true",
                    "-DparentVersion="+ mangledPlatformVersion],
                { cwd: workdirOfSync(app, thingyName) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                    return;
                }
                updateProperty(mangledPlatformVersion);
            });
        }
        function updateProperty( mangledPlatformVersion ){
            log.write("[DEBUG] "+ thingyName +" - Set parent.version "+ mangledPlatformVersion +"\n");
            var child = child_process.spawn(
                "mvn", ["versions:set-property", "-DgenerateBackupPoms=false", "-DallowSnapshots=true",
                    "-Dproperty=platform.version", "-DnewVersion="+ mangledPlatformVersion],
                { cwd: workdirOfSync(app, thingyName) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                    return;
                }
                onDone();
            });
        }
    }


    function dropSlimFromAllJenkinsfiles( app, onDone ){
        var iSvc = -1;
        var jettyServices;
        var jettyService;
        incrNumTasks(app);
        getJettyServiceNamesAsArray(app, function( ex, jettyServices_ ){
            if( ex ) throw ex;
            jettyServices = jettyServices_;
            nextJettyService();
        });
        function nextJettyService( ex ){
            decrNumTasks(app);
            if( ex ) throw ex;
            if( ++iSvc >= jettyServices.length ){ onNoMoreJettyServices(); return; }
            incrNumTasks(app);
            jettyService = jettyServices[iSvc];
            isWorktreeClean(app, jettyService, TODO_pCMCAEAFAgCfKwIA);
        }
        function TODO_pCMCAEAFAgCfKwIA( ex, isClean ){
            if( ex ){ onDone(ex); return; }
            if( !isClean ){
                log.write("[WARN ] Wont patch: Worktree not clean: "+ jettyService +"\n");
                nextJettyService();
                return;
            }
            getPatch(app, jettyService, TODO_UR0CABMRAgBOAgIA);
        }
        function TODO_UR0CABMRAgBOAgIA( ex, patchStr ){
            if( ex ){ onDone(ex); return; }
            if( !patchStr ){ TODO_qCICAFEnAgD7FgIA(); return; }
            log.write("[DEBUG] Custom patch for '"+ jettyService +"'\n");
            var child = child_process.spawn(
                "patch", [ "-p", "1" ], { cwd: workdirOfSync(app, jettyService) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.stdout.on("data", logAsString);
            child.on("close", nextJettyService);
            child.stdin.write(patchStr);
            child.stdin.end();
        }
        function TODO_qCICAFEnAgD7FgIA( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] Generic patch \""+ jettyService +"/Jenkinsfile\"\n");
            var child = child_process.spawn(
                "sed", [ "-i", "-E", "s_^(.*?buildMaven.*?),? *slim: *true,? *(.*?)$_\\1\\2_", "Jenkinsfile" ],
                { cwd: workdirOfSync(app, jettyService) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", removeEmptyArray);
        }
        /* Pipeline cannot handle an empty array */
        function removeEmptyArray( ex ){
            if( ex ) throw ex;
            var child = child_process.spawn(
                "sed", [ "-i", "-E", "s_^(.*?.buildMaven)\\\\(\\\\[\\\\]\\\\)(.*?)$_\\\\1()\\\\2_", "Jenkinsfile" ],
                { cwd: workdirOfSync(app, jettyService) },
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", nextJettyService);
        }
        function onNoMoreJettyServices(){
            onDone(null, null);
        }
    }


    function checkoutUpstreamDevelop( app, thingyName, onDone){
        var iRemoteName = 0;
        checkout();
        function checkout(){
            var remoteName = app.remoteNamesToTry[iRemoteName];
            if( remoteName === undefined ){ onDone(Error("No more remote names for "+ thingyName)); return; }
            log.write("[DEBUG] git checkout "+ thingyName +" "+ remoteName +"/develop\n");
            var child = child_process.spawn(
                "git", ["checkout", remoteName+"/develop"],
                { cwd: workdirOfSync(app, thingyName), });
            child.on("error", console.error.bind(console));
            child.stderr.on("data", function( buf ){ log.write(buf); });
            child.on("close", function( code, signal ){
                if( !"TODO_GlACAIQoAgDMTwIAIh8CAOJvAgALLgIA" ){
                    checkout(); /* try next remote name */
                }else if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else{
                    onDone(null, null);
                }
            });
        }
    }


    function fetchChangesFromGitit( app, thingyName, onDone ){
        var child;
        var iRemoteName = 0;
        mkAppWorkdir();
        function mkAppWorkdir( ex ){
            if( ex ) throw ex;
            fs.mkdir(app.workdir, {recursive:true}, checkRepoExists);
        }
        function checkRepoExists( ex ){
            if( ex ) throw ex;
            fs.exists(workdirOfSync(app, thingyName) +"/.git", function( isLocalCloneExists ){
                isLocalCloneExists ? fetch() : clone();
            });
        }
        function clone( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] git clone "+ thingyName +"\n");
            var child = child_process.spawn(
                "git", ["clone", "--no-single-branch", "--depth", "4", gitUrlOfSync(app, thingyName)],
                { cwd: app.workdir });
            child.on("error", console.error.bind(console));
            child.stderr.on("data", function( buf ){ log.write(buf); });
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal)); return;
                }
                onDone(null, null);
            });
        }
        function fetch( ex ){
            if( ex ) throw ex;
            var remoteName = app.remoteNamesToTry[iRemoteName++];
            if( remoteName === undefined ){
                onDone(Error("No more remotes to try for "+ thingyName)); return; }
            log.write("[DEBUG] "+ thingyName +" - git fetch "+ remoteName +"\n");
            var child = child_process.spawn(
                "git", ["fetch", remoteName],
                { cwd: workdirOfSync(app, thingyName), });
            child.on("error", console.error.bind(console));
            child.stderr.on("data", function( buf ){ log.write(buf); });
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal)); return;
                }
                onDone(null, null);
            });
        }
    }


    function setVersionInPlatform( app, onDone ){
        if( typeof onDone != "function" ) throw TypeError("onDone");
        setVersion();
        function setVersion(){
            log.write("[DEBUG] platform - mvn versions:set "+ app.platformSnapVersion +"\n");
            var child = child_process.spawn(
                "mvn", ["versions:set", "-DgenerateBackupPoms=false", "-DnewVersion="+app.platformSnapVersion],
                { cwd: workdirOfSync(app, "platform"), }
            );
            child.on("error", console.error.bind(console));
            child.stdout.on("data", noop);
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    endFn(Error("code "+ code +", signal "+ signal));
                    return;
                }
                endFn();
            });
        }
        function endFn( ex, ret ){
            onDone(ex, ret);
        }
    }


    function patchAwaySlimPackagingInPlatform( app, onDone ){
        var onDoneCalledNTimes = 0;
        incrNumTasks(app);
        isWorktreeClean(app, "platform", function( ex, isClean ){
            if( ex ) throw ex;
            if( !isClean ){ log.write("[WARN ] Skip platform patch: Worktree not clean\n");
                endFn(); return; }
            getDropSlimArtifactsTagInPlatformPatch(app, onPatchBufReady);
        });
        function onPatchBufReady( ex, patch ){
            if( ex ) throw ex;
            var stdoutBufs = [];
            var gitApply = child_process.spawn(
                "git", ["apply"],
                { cwd: workdirOfSync(app, "platform"), });
            gitApply.on("error", console.error.bind(console));
            gitApply.stderr.on("data", logAsString);
            gitApply.stdout.on("data", stdoutBufs.push.bind(stdoutBufs));
            gitApply.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    for( var buf in stdoutBufs ){ log.write(buf.toString()); }
                    throw Error(""+ code +", "+ signal +"");
                }
                endFn(null, null);
            });
            setTimeout/*TODO why?*/(function(){
                gitApply.stdin.write(patch);
                gitApply.stdin.end();
            }, 42);
        }
        function endFn( ex, ret ){
            if( onDoneCalledNTimes !== 0 ){ throw Error("assert(onDoneCalledNTimes == 0)"); }
            onDoneCalledNTimes += 1;
            decrNumTasks(app);
            onDone(ex, ret);
        }
    }


    function incrNumTasks( app ){
        //if( app.numRunningTasks >= app.maxParallel ){
        //    throw Error("assert(app.numRunningTasks < app.maxParallel)");
        //}
        app.numRunningTasks += 1;
    }


    function decrNumTasks( app ){
        if( app.numRunningTasks <= 0 ) throw Error("assert(app.numRunningTasks > 0)");
        app.numRunningTasks -= 1;
    }


    function forEachInArrayDo( app, array, onService, onDone ){
        var iE = 0;
        var isOnDoneCalled = false;
        nextElem();
        function nextElem( ex ){
            if( ex ){ endFn(ex); return; }
            if( iE >= array.length ){ endFn(); return; }
            onService(app, array[iE++], nextElem);
        }
        function endFn( ex ){
            if( isOnDoneCalled ){
                throw (ex) ? ex : Error("onDone MUST be called ONCE only");
            }else{
                isOnDoneCalled = true;
                onDone(ex);
            }
        }
    }


    function forEachJettyService( app, onService, onDone ){
        getJettyServiceNamesAsArray(app, onServicesArrived);
        function onServicesArrived( ex, services ){
            if( ex ) throw ex;
            forEachInArrayDo(app, services, onService, onDone);
        }
    }


    function resetPlatform( app, onDone ){
        resetHardToDevelop(app, "platform", onDone);
    }


    function resetHardToDevelop( app, thingyName, onDone ){
        var iRemoteName = 0;
        if( typeof onDone !== "function" ) throw Error("onDone");
        detach();
        function detach(){
            log.write("[DEBUG] "+ thingyName +"$ git checkout --detach\n");
            var child = child_process.spawn(
                "git", ["checkout", "--detach"],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else{
                    tryResetHard();
                }
            });
        }
        function tryResetHard(){
            var remoteName = app.remoteNamesToTry[iRemoteName++];
            if( remoteName === undefined ){ onDone(Error("no usable remote found")); return; }
            log.write("[DEBUG] "+ thingyName +"$ git reset --hard "+ remoteName +"/develop\n");
            var child = child_process.spawn(
                "git", ["reset", "--hard", remoteName +"/develop"],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else if( code !== 0 ){
                    tryResetHard(); /*try next remoteName*/
                }else{
                    wipeWorktree();
                }
            });
        }
        function wipeWorktree(){
            log.write("[DEBUG] "+ thingyName +"$ git rimraf\n");
            var child = child_process.spawn(
                "git", ["rimraf"/*TODO make portable*/],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else{
                    deleteBranch();
                }
            });
        }
        function deleteBranch( ex ){
            if( ex ) throw ex;
            log.write("[DEBUG] "+ thingyName +"$ git branch --delete --force "+ app.branchName +"\n");
            var child = child_process.spawn(
                "git", ["branch", "--delete", "--force", app.branchName],
                { cwd:workdirOfSync(app, thingyName) }
            );
            child.on("error", console.error.bind(console));
            child.stderr.on("data", logAsString);
            child.on("close", function( code, signal ){
                if( code == 1 ){ /* assume branch doesnt exist*/
                    log.write("[INFO ] Ignore: Failed to delete branch '"+ app.branchName +"' in '"
                        + thingyName +"'.\n");
                    endFn(null, null);
                }else if( code !== 0 || signal !== null ){
                    onDone(Error("code "+ code +", signal "+ signal));
                }else{
                    endFn(null, null);
                }
            });
        }
        function endFn( ex, ret ){
            onDone(ex, ret);
        }
    }


    function setPlatformVersionInAllServices( app, onDone ){
        forEachJettyService(app, setPlatformVersionInService, onDone);
    }


    function fetchRemoteChanges( app, onDone ){
        var platformAndServices = app.services.slice(0);
        platformAndServices.unshift("platform");
        forEachInArrayDo(app, platformAndServices, fetchChangesFromGitit, onDone);
    }


    function fetchListOfServices( app, onDone ){
        getJettyServiceNamesAsArray(app, function( ex, ret ){
            if( ex ){ onDone(ex); return; }
            app.services = ret;
            onDone();
        });
    }


    function run( app ){
        var actions = [ fetchListOfServices ];
        if( app.isFetch ){ actions.push(fetchRemoteChanges); }
        if( app.isResetHard ){
            actions.push(function( app, onDone ){
                forEachInArrayDo(app, app.services, checkoutUpstreamDevelop, onDone);
            });
            actions.push(function( app, onDone ){
                forEachInArrayDo(app, app.services, resetHardToDevelop, onDone);
            });
        }
        if( app.isResetPlatform ){ actions.push(resetPlatform); }
        if( app.isPatchPlatform ){
            actions.push(patchAwaySlimPackagingInPlatform);
            actions.push(setVersionInPlatform);
        }
        if( app.isCommitPlatform ){ actions.push(commitPlatform); }
        if( app.isPushPlatform ){ actions.push(pushPlatform); }
        if( app.isPatchServices ){
            actions.push(dropSlimFromAllJenkinsfiles);
            actions.push(setPlatformVersionInAllServices);
            actions.push(function( app, onDone ){
                forEachInArrayDo(app, app.services, giveServiceOurSpecialVersion, onDone);
            });
        }
        if( app.isCommit ) actions.push(function( app, onDone ){
            forEachInArrayDo(app, app.services, commitService, onDone);
        });
        if( app.isPush || app.isPushForce ){
            actions.push(function( app, onDone ){
                forEachJettyService(app, pushService, onDone);
            });
        }
        if( app.isPrintIsaVersion ){ actions.push(printIsaVersionNoslim); }
        if( app.isPrintBaselineVersion ){ actions.push(printBaselineVersion); }
        actions.push(function( app, onDone ){ log.write("[INFO ] App done\n"); });
        triggerNextAction();
        function triggerNextAction( ex ){
            if( ex ) throw ex;
            var action = actions.shift();
            if( action === undefined ){ endFn(); return; }
            action(app, triggerNextAction);
        }
    }


    function main(){
        const app = {
            isHelp: false,
            isFetch: false,
            isResetPlatform: false,
            isPatchPlatform: false,
            isCommitPlatform: false,
            isResetHard: false,
            isPatchServices: false,
            iscommit: false,
            isPush: false,
            isPushForce: false,
            isPrintIsaVersion: false,
            isPrintBaselineVersion: false,
            remoteNamesToTry: ["origin"],
            workdir: "C:/work/tmp/SlimPkg-Repos",
            maxParallel:  1,
            numRunningTasks: 0,
            services: null,
            issueKey: "SDCISA-15648",
            branchName: null,
            commitMsg: null,
            platformSnapVersion: "0.0.0-SNAPSHOT",
            serviceSnapVersion: "0.0.0-SNAPSHOT",
            parentVersion: null,
        };
        app.branchName = app.issueKey +"-RemoveSlimPackaging-n1";
        app.commitMsg = "["+ app.issueKey +"] Remove slim packaging";
        app.parentVersion = "0.0.0-"+ app.branchName +"-SNAPSHOT";
        if( parseArgs(process.argv, app) !== 0 ){ process.exit(1); }
        if( app.isHelp ){ printHelp(); return; }
        run(app);
    }


}());
