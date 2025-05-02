
local main, fMziOg5WMNCa7WHtQ


function define_vars( dst )
	dst:write([=[
  && SUDO=sudo \
  && cacheDir=/var/tmp \
  && autheliaVersion='4.39.1' \
  && arch='amd64' \
]=])
end


function define_aptInstall( dst )
	dst:write([=[
  && aptInstall () { true \
      && `# Package missing? Try: $SUDO apt update` \
      && $SUDO apt install --no-install-recommends -y \
           curl \
    ;} \
]=])
end


function define_storeKnownHashes( dst )
	dst:write([=[
  && storeKnownHashes () { true \
      && printf '%s\n' \
          '8f7492da4fc5122721314e936dace124fbd4fc946e27f2723011bba6b16a8bc4 *authelia-v4.39.1-linux-amd64.tar.gz' \
          '254e481f104665561656402164c2190539f06a3088742050f062d0ece7673d81 *authelia-v4.39.1-linux-arm64.tar.gz' \
         | $SUDO tee "${cacheDir:?}/SHA256SUM" >/dev/null \
    ;} \
]=])
end


function define_installAuthelia( dst )
	dst:write([=[
  && installAuthelia () { true \
      && `# dload` \
      && cd /var/tmp \
      && isFileOk () { true \
          && grep -E "authelia.+${autheliaVersion:?}.+${arch:?}" "${cacheDir:?}/SHA256SUM" \
             | sha256sum -c - ;} \
      && if ! isFileOk ;then true \
          && curl -SL \
              -o "${cacheDir:?}/authelia-v${autheliaVersion:?}-linux-${arch:?}.tar.gz" \
              'https://github.com/authelia/authelia/releases/download/v'"${autheliaVersion:?}"'/authelia-v'"${autheliaVersion:?}"'-linux-'"${arch:?}"'.tar.gz' \
          && isFileOk \
        ;fi\
      && `# install` \
      && $SUDO mkdir /opt/authelia-"${autheliaVersion:?}" \
                     /opt/authelia-"${autheliaVersion:?}"/unpack \
                     /opt/authelia-"${autheliaVersion:?}"/bin \
                     /opt/authelia-"${autheliaVersion:?}"/etc \
                     /opt/authelia-"${autheliaVersion:?}"/var \
                     /opt/authelia-"${autheliaVersion:?}"/var/lib \
                     /opt/authelia-"${autheliaVersion:?}"/skel \
      && cd /opt/authelia-"${autheliaVersion:?}/unpack" \
      && $SUDO tar xf "${cacheDir:?}/authelia-v${autheliaVersion:?}-linux-${arch:?}.tar.gz" \
      && cd /opt/authelia-"${autheliaVersion:?}" \
      && $SUDO mv unpack/authelia-linux-amd64          bin/authelia \
      && $SUDO mv unpack/authelia.service              skel/. \
      && $SUDO mv unpack/authelia@.service             skel/. \
      && $SUDO mv unpack/authelia.sysusers.conf        skel/. \
      && $SUDO mv unpack/authelia.tmpfiles.conf        skel/. \
      && $SUDO mv unpack/authelia.tmpfiles.config.conf skel/. \
      && $SUDO mv unpack/config.template.yml           skel/. \
      && $SUDO rmdir unpack \
    ;} \
]=])
end


function getConfigYaml()
    return [=[
log:
	# Sending the Authelia process a SIGHUP will cause it to close and reopen
	# the current log file and truncate it.
	level: "warn"  # OneOf: trace, debug, info, warn, error.
	format: "text"
	file_path: "/var/log/authelia/authelia.log"
	keep_stdout: false
server:
	host: 0.0.0.0
	port: 9091
storage:
	encryption_key: "WUoXVW1HUWc918C5H4qApHVi6A3H3d9Z" # TODO_replaceMe
	local:
		path: "/opt/authelia-]=].. autheliaVersion ..[=[/var/lib/authelia.db"
#jwt_secret: "TODO-a-super-long-strong-string-of-letters-numbers-characters"
#default_redirection_url: "https://auth.example.com"
#totp:
#	issuer: example.com
#	period: 30
#	skew: 1
access_control:
	default_policy: deny
	rules: [{
		domain: [ "noauth.example.com" ]
		policy: bypass
	},{
		domain: [ "foo.example.com" ]
		policy: one_factor
		#networks: [ "192.168.1.0/24" ]
	}]
notifier:
	disable_startup_check: true
	#filesystem:
	#	filename: "/path/to/notification.txt"
#smtp:
#	...
#oidc:
#	...
theme: "dark"
]=]
end


function getUserDbYml()
	return [=[
# Use: authelia hash-password 'blubb'
users:
	john:
		displayname: "John Wick"
		password: "$argon2id$v=19$m=65536,t=3,p=2$BpLnfgDsdfdsgdthgdsdfsdfdg6bUGsDY//8mKUYNZZaR0t4MFFSs+iM"
		email: john@example.com
		groups: ["admins", "dev"]
	harry:
		displayname: "Thanos Infinity"
		password: "$argon2id$v=19$m=65536,t=3,p=2$BpLnfgjhfrtretasdfdfghja44sdfdfa/8mKUYNZZaR0t4MFFSs+iM"
		email: thanos@authelia.com
		groups: []
]=]
end


function define_run( dst )
	dst:write([=[
  && run () { true \
      && storeKnownHashes \
      && aptInstall \
      && installAuthelia \
      && printNginxExampleConfig \
    ;} \
]=])
end


function main()
	local dst = io.stdout
	define_vars(dst)
	define_storeKnownHashes(dst)
	define_aptInstall(dst)
	define_installAuthelia(dst)
	define_run(dst)
	dst:write([=[
  && run \
]=])
end


main()
