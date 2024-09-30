
Created 20240419 as it seems we need some automation for those tasks.

Currently working on "SDCISA-15648".


[j21 migration branches sandro](https://wikit.post.ch/display/ISA/ISA+Java21+Update)


  DSTDIR=/tmp
  tar czf "${DSTDIR:?}"/andy-noslim-$(date -u +%Y%m%d-%H%M%S).tgz -- conf isa-launch-* isa.sh logs preflux prefluxer-* puppetconfig_version repo


JSSC USERS -> babelfish, benjy, blart, caveman, jeltz, loon, megacamel, vogon

jssc sollte hier drin sein -> "alice-docker-service-base*.jar"

Evtl für diese services den jssc als "provided" angeben.

  && PATH_TO_THE_ONLY_REAL_BROWSER="C:/Users/fankhauseand/.opt/FirefoxPortable-105.0.1/FirefoxPortable.exe" \

  && "${PATH_TO_THE_ONLY_REAL_BROWSER:?}" \
    `# waiting for jenkins build ` \
    https://jenkinspaisa-temp.tools.pnet.ch/job/colin/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    `# waiting for feedback from rudins ` \
    `# LastSuccessfull build at 20240919 ` \
    https://jenkinspaisa-temp.tools.pnet.ch/job/slarti/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/captain/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/megacamel/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/guide/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/allitnil/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/babelfish/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/barman/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/benjy/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/bentstick/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/blart/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/caveman/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/deep/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/drdan/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/hooli/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/jeltz/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/kwaltz/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/loon/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/magician/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/minetti/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/mown/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/poodoo/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/prosser/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/streetmentioner/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/towel/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/vannharl/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/vogon/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/vroom/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/zaphake/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/heimdall/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    `# LastSuccessfull build at 20240920 ` \
    https://jenkinspaisa-temp.tools.pnet.ch/job/thor/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/rob/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/pobble/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/nowwhat/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/zem/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/trillian/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    https://jenkinspaisa-temp.tools.pnet.ch/job/deep/job/SDCISA-15648-RemoveSlimPackaging-n2/ \
    `# Just here to have them somewhere ` \
    https://jenkinspaisa-temp.tools.pnet.ch/job/platform/job/SDCISA-15648-RemoveSlimPackaging-n2/ \


  && for S in allitnil babelfish barman benjy bentstick blart captain caveman colin deep drdan guide heimdall hooli jeltz kwaltz loon magician megacamel minetti mown nowwhat platform pobble poodoo prosser rob slarti streetmentioner thor towel trillian vannharl vogon vroom zaphake zem;
     do \
         printf '%-17s%s\n' "$S" "$(/c/work/tmp/bin/JenkinsReBuild.exe --cookie "${COOKIE?}" --branch "${BRANCH:?}" --service "$S" 2>&1)"; \
     done \


## Measurements

  && while true; do ssh donner -oRemoteCommand='true \
       && while true; do true \
         && printf '\''%%s  %%s  %%s\n'\'' \
           "$(date +%%s)" \
           "$(uptime)" \
           "$(free | grep Mem)" \
         && sleep $((5 - $(date +%%s) %% 5)) || break \
       ;done' | tee -a donner-perf/donner-perf-$(date -u +%Y%m%d-%H%M%SZ).log \
     && sleep 5 || break; done \

  && THELOG="donner-perf-20240930-112559Z.log" \
  && cat "${THELOG:?}" \
      | sed -E 's_^([0-9]+) +([0-9:]+) .+age: ([0-9.]+), ([0-9.]+), ([0-9.]+) +( Mem: .*).*$_\1;\2;\3;\4;\5\6_' \
      | sed -E 's_^(.+) Mem: +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+).*$_\1;\2;\3;\4;\5;\6_' \
      > "${THELOG:?}.csv" \

  && for E in donner-perf-2024*Z.log.csv ;do true \
     && echo "__ ${E:?} __" \
     && csv-to-bmp --xcol 1 --ycol 3 --outsz 4096x2160 --srccsv "${E:?}" --dstbmp "${E%.*}.bmp" \
     ;done


Boot ab KassenTaster, login mit RFID, vorgeschlagene Fahrt anmelden, warten.

When+0200;version;LoginScreen[sec];FahrtGewaehlt[sec];
2024-08-02T13:31;legacy;190;208;
2024-08-02T13:40;legacy;180;208;
2024-08-02T13:47;legacy;175;198;
2024-08-02T14:03;legacy;172;196;


## Performance smoketest from remote at 27sep2024

1313Z umschalten auf "new" (aka NoSlim) dann reboot mit messung.
1338Z umschalten auf "alt" (aka "bundle-sw_4098-data_4110") dann reboot mit messung.

## Performance smoketest vor Ort at 30sep2024

When[CEST];version;LoginScreen[sec];FahrtGewaehlt[sec];
2024-09-30 13:25;noslim;240;274;Logout nach 20min.
2024-09-30 13:47;noslim;237;282;Logout ca nach 8min. Drucker geht nicht (siehe Foto & video)
2024-09-30 14:00;noslim;282;315;Logout nach 14min.
2024-09-30 14:20;legacy;180;203;Logout nach 14min.
2024-09-30 14:38;legacy;180;206;Logout spääät.
2024-09-30 15:10;legacy;187;218;
2024-09-30 16:31;noslim;247;278;
2024-09-30 __:__;__;__;__;
2024-09-30 __:__;__;__;__;




