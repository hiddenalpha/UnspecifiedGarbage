
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
    `# Remaining builds` \
    https://jenkinspaisa-temp.tools.pnet.ch/job/SERVICE/job/SDCISA-15648-RemoveSlimPackaging-n1/ \


## Installation

{
  "timestamp": "2024-08-06T16:54:42.042+02:00",
  "hostname": "eddie00849",
  "instanceName": "default",
  "eaglePort": 7012,
  "activations": {
    "SDCISA-15648-1722955735781-legacy": "2024-07-01T00:04:00.000Z",
    "SDCISA-15648-1722955733398-noslim": "2024-07-01T00:03:00.000Z",
    "bundle-sw_4011-data_3997": "2024-07-29T11:49:53.152Z",
    "bundle-sw_4012-data_3997": "2024-07-25T02:00:00.000Z",
    "bundle-sw_4012-data_4005": "2024-07-16T23:00:00.000Z"
  }
}



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







