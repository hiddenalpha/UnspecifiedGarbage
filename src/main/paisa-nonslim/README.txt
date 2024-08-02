
Created 20240419 as it seems we need some automation for those tasks.

Currently working on "SDCISA-15648".


[j21 migration branches sandro](https://wikit.post.ch/display/ISA/ISA+Java21+Update)



git d -w $(git mb origin/develop origin/SDCISA-15636-Migrate-to-Java-21) origin/SDCISA-15636-Migrate-to-Java-21


git d -w $(git mb origin/develop origin/SDCISA-15636-Migrate-to-Java-21-test) origin/SDCISA-15636-Migrate-to-Java-21-test --name-status


  DSTDIR=/tmp
  tar czf "${DSTDIR:?}"/andy-noslim-$(date -u +%Y%m%d-%H%M%S).tgz -- conf isa-launch-* isa.sh logs preflux prefluxer-* puppetconfig_version repo


## Measurements

  && `# Eddie` \
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

2024-08-02 (1331-): Legacy begin.

When+0200;version;LoginScreen[sec];FahrtGewaehlt[sec];
2024-08-02T13:31;legacy;190;208;
2024-08-02T13:40;legacy;180;208;
2024-08-02T13:47;legacy;175;198;
2024-08-02T14:03;legacy;172;196;
2024-08-02T14:26;legacy;___;208;
2024-08-02T14:43;noslim;210;;Ca, dann Kartenleser NICHT bereit







