
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

  && THELOG="donner-perf-20240927-131453Z.log" \
  && cat "${THELOG:?}" \
      | sed -E 's_^([0-9]+) +([0-9:]+) .+age: ([0-9.]+), ([0-9.]+), ([0-9.]+) +( Mem: .*).*$_\1;\2;\3;\4;\5\6_' \
      | sed -E 's_^(.+) Mem: +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+) +([0-9]+).*$_\1;\2;\3;\4;\5;\6_' \
      > "${THELOG:?}.csv" \


Boot ab KassenTaster, login mit RFID, vorgeschlagene Fahrt anmelden, warten.

2024-07-31 (begin-): isa ausschalten, backups erstellen.
2024-07-31 (1140-1150): Erster legacy boot versuch. Abbruch, weil port falsch.
2024-07-31 (1152-1200): Legacy begin. Ca 77sec bis ssh ok. Abbruch, weil cntnr re-create.
2024-07-31 (1329-): Legacy begin.
2024-08-09 (1320-): Vorbereiten -> Failed, weil ständig reboot.
2024-08-09 (1450-): PowBox Stecker raus, nochmal neu versuchen.
2024-08-09 (-1700): ALLE LÄUFE bis 1700 FALSCHE VERSION!
2024-08-09 (1700-): NOCHMAL!

When+0200;version;LoginScreen[sec];FahrtGewaehlt[sec];
2024-08-02T13:31;legacy;190;208;
2024-08-02T13:40;legacy;180;208;
2024-08-02T13:47;legacy;175;198;
2024-08-02T14:03;legacy;172;196;
2024-08-09T__:__;noslim;___;___;
2024-08-09T__:__;noslim;___;___;


## Performance smoketest from remote at 27sep2024

1313Z umschalten auf "new" (aka NoSlim) dann reboot mit messung.
1338Z umschalten auf "alt" (aka "bundle-sw_4098-data_4110") dann reboot mit messung.



