
Created 20240419 as it seems we need some automation for those tasks.

Currently working on "SDCISA-15648".


[j21 migration branches sandro](https://wikit.post.ch/display/ISA/ISA+Java21+Update)


[rob NoClassDefFoundError](https://jenkinspaisa-temp.tools.pnet.ch/job/rob/job/SDCISA-15648-RemoveSlimPackaging-n1/)

Exception in thread "Thread-0" java.lang.NoClassDefFoundError: ch/qos/logback/classic/spi/ThrowableProxy
	at ch.qos.logback.classic.spi.LoggingEvent.<init>(LoggingEvent.java:145)
	at ch.qos.logback.classic.Logger.buildLoggingEventAndAppend(Logger.java:424)
	at ch.qos.logback.classic.Logger.filterAndLog_0_Or3Plus(Logger.java:386)
	at ch.qos.logback.classic.Logger.error(Logger.java:543)
	at org.eclipse.jgit.internal.util.ShutdownHook.cleanup(ShutdownHook.java:87)
	at java.base/java.lang.Thread.run(Unknown Source)
Caused by: java.lang.ClassNotFoundException: ch.qos.logback.classic.spi.ThrowableProxy
	at java.base/java.net.URLClassLoader.findClass(Unknown Source)
	at org.sonarsource.scanner.api.internal.IsolatedClassloader.loadClass(IsolatedClassloader.java:82)
	at java.base/java.lang.ClassLoader.loadClass(Unknown Source)
	... 6 more


[deep NoClassDefFoundError](https://jenkinspaisa-temp.tools.pnet.ch/job/deep/job/SDCISA-15648-RemoveSlimPackaging-n1/)

Exception in thread "Thread-0" java.lang.NoClassDefFoundError: ch/qos/logback/classic/spi/ThrowableProxy
	at ch.qos.logback.classic.spi.LoggingEvent.<init>(LoggingEvent.java:145)
	at ch.qos.logback.classic.Logger.buildLoggingEventAndAppend(Logger.java:424)
	at ch.qos.logback.classic.Logger.filterAndLog_0_Or3Plus(Logger.java:386)
	at ch.qos.logback.classic.Logger.error(Logger.java:543)
	at org.eclipse.jgit.internal.util.ShutdownHook.cleanup(ShutdownHook.java:87)
	at java.base/java.lang.Thread.run(Unknown Source)
Caused by: java.lang.ClassNotFoundException: ch.qos.logback.classic.spi.ThrowableProxy
	at java.base/java.net.URLClassLoader.findClass(Unknown Source)
	at org.sonarsource.scanner.api.internal.IsolatedClassloader.loadClass(IsolatedClassloader.java:82)
	at java.base/java.lang.ClassLoader.loadClass(Unknown Source)
	... 6 more



git d -w $(git mb origin/develop origin/SDCISA-15636-Migrate-to-Java-21) origin/SDCISA-15636-Migrate-to-Java-21


git d -w $(git mb origin/develop origin/SDCISA-15636-Migrate-to-Java-21-test) origin/SDCISA-15636-Migrate-to-Java-21-test --name-status



