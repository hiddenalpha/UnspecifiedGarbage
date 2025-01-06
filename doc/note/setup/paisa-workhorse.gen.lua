#!/usr/bin/env lua
--[===========================================================================[

  Prints Provisioning (POSIX shell) script for "paisa-workhorse" to stdout.

  Intended to be used with "http://devuan.org/".

  [isa kube/config](https://gitit.post.ch/projects/ISA/repos/wsl-playbooks/raw/roles/isa/files/kube/config?at=refs%2Fheads%2Fmaster)
  [Some other kube/config](https://artifactory.tools.post.ch/artifactory/generic-kubernetes-local/EKS/Int/eks-int-m01cn0001/config)

  [How to run kubectl Commands in my Namespace](https://wikit.post.ch/x/kIeTZg)

  TODO keep! Mit dem gehts! (vo mattiphil 2024-12-19:
  (https://artifactory.tools.post.ch/artifactory/generic-kubernetes-local/EKS/Int/eks-int-m15cn0001/config)

  [übersicht, namespaces, etc](https://deployment-eks-int-m15cn0001.eks.aws.pnetcloud.ch/applications?view=list&showFavorites=false&proj=&sync=&autoSync=&health=&namespace=&cluster=&labels=)

  ]===========================================================================]
-- Customize your install here ------------------------------------------------
-- TODO Make sure to insert your roles, etc here BEFORE use.

-- UNUSED local awsNamespace = "_TODO_-snapshot"
local yourPhysicalHostname = "TODO_your_windoof_hostname" -- "w00o2z", "${PUT_YOUR_HOSTS_NAME_HERE:?}"
local proxy_url = "http://10.0.2.2:3128/"
local proxy_no  = "localhost,pnet.ch,post.ch,tools.post.ch,gitit.post.ch,pnetcloud.ch,eu-central-1.eks.amazonaws.com,"..assert(yourPhysicalHostname)

-- Values from here onwards usually are ok as-is.
local cmdSudo = "sudo"
local kubeloginVersion = "0.1.6"
local argocdVersion = "2.11.7"
local getaddrinfoVersion = "0.0.2"
local cacheDir = "/var/tmp"
local kubeConfigFile = "eks-int-m15cn0001"
local kubeConfigUrl = "https://artifactory.tools.post.ch/artifactory/generic-kubernetes-local/EKS/Int/eks-int-m15cn0001/config"
local ceeMiscLibVersion = false -- "0.0.5-330-g2b037a5"

-- EndOf Customization --------------------------------------------------------

local main


function writeVariables( dst )
    dst:write([=[
  && SUDO=']=].. cmdSudo ..[=[' \
  && ARCH=x86_64-linux-gnu \
  && proxy_url=']=].. proxy_url ..[=[' \
  && proxy_no="]=].. proxy_no ..[=[" \
  && cacheDir=']=].. cacheDir ..[=[' \
  && repoDir="${cacheDir:?}/repo" \
  && argocdVersion=]=].. argocdVersion ..[=[ \
  && getaddrinfoVersion=]=].. getaddrinfoVersion ..[=[ \
  && kubeloginVersion=]=].. kubeloginVersion ..[=[ \
  && kubeConfigUrl=']=].. kubeConfigUrl ..[=[' \
  && kubeConfigFile=']=].. kubeConfigFile ..[=[' \
]=])
    if ceeMiscLibVersion then dst:write([=[
  && ceeMiscLibVersion=]=].. (ceeMiscLibVersion or"") ..[=[ \
  && ceeMiscLibUrl="http://hiddenalpha.ch/assets/dloads/CeeMiscLib-${ceeMiscLibVersion:?}+${ARCH:?}.tgz" \
  && ceeMiscLibLocal="$(basename "${ceeMiscLibUrl:?}")" \
]=])end
end


function writeDloadIfMissingFunc( dst )
    dst:write([=[
  && dloadIfMissing () { true \
      && dst="${1:?}" \
      && uri="${2:?}" \
      && if test -e "${dst:?}" ;then true \
          && printf 'EEXISTS: Skip dload: %s\n' "${dst:?}" \
        ;else true \
          && printf 'Dload  "%s"  (%s)\n' "${dst:?}" "${uri:?}" \
          && curl -Lo "${dst:?}" "${uri:?}" \
        ;fi \
  } \
  && dloadInsecureIfMissing () { true \
      && dst="${1:?}" \
      && uri="${2:?}" \
      && if test -e "${dst:?}" ;then true \
          && printf 'EEXISTS: Skip dload: %s\n' "${dst:?}" \
        ;else true \
          && printf 'Dload  "%s"  (%s)\n' "${dst:?}" "${uri:?}" \
          && curl --insecure -Lo "${dst:?}" "${uri:?}" \
        ;fi \
  } \
]=])
end


function writeProxySettings( dst )
    dst:write([=[
  && `# Proxy settings ` \
  && printf %s\\n \
        "no_proxy=${proxy_no?}" \
        "https_proxy=${proxy_url:?}" \
        "http_proxy=${proxy_url:?}" \
        "NO_PROXY=${proxy_no?}" \
        "HTTPS_PROXY=${proxy_url:?}" \
        "HTTP_PROXY=${proxy_url:?}" \
     | $SUDO tee -a /etc/environment >/dev/null \
  && export "no_proxy=${proxy_no?}" \
  && export "https_proxy=${proxy_url:?}" \
  && export "http_proxy=${proxy_url:?}" \
  && export "NO_PROXY=${proxy_no?}" \
  && export "HTTPS_PROXY=${proxy_url:?}" \
  && export "HTTP_PROXY=${proxy_url:?}" \
  && if test ! -e /etc/apt/apt.conf.d/80proxy ;then true \
      && printf %s\\n \
            'Acquire::http::proxy "'"${proxy_url:?}"'";' \
            'Acquire::https::proxy "'"${proxy_url:?}"'";' \
         | $SUDO tee -a /etc/apt/apt.conf.d/80proxy > /dev/null \
    ;fi \
]=])
end


function writeSwapSetup( dst )
    dst:write([=[
  && `# Add some swap ` \
  && SWAP_MIB=$((12*1024)) `# aka 12GiB ` \
  && $SUDO dd if=/dev/zero of=/swapfile1 bs=$((1024*1024)) count="${SWAP_MIB:?}" \
  && $SUDO chmod 0600 /swapfile1 \
  && $SUDO mkswap /swapfile1 \
  && printf '/swapfile1  none  swap  sw,pri=10  0  0\n' | $SUDO tee -a /etc/fstab > /dev/null \
]=])
end


function writePkgInstallation( dst )
    -- 20240715: Removed: gcc-mingw-w64-x86-64-win32 gcc libc6-dev
    -- TODO: update only all few hours.
    dst:write([=[
  && `# Install packages ` \
  && $SUDO apt update \
  && $SUDO RUNLEVEL=1 apt install -y --no-install-recommends \
         net-tools vim curl nfs-common htop ncat git ca-certificates tmux \
         kubernetes-client awscli openjdk-17-jre-headless maven podman \
         bash-completion lua5.4 \
]=])
end


function writeHiddenalphaToolsInstallation( dst )
    -- download
    dst:write([=[
  && `# Install custom tools` \
]=])
    if ceeMiscLibVersion then dst:write([=[
  && dloadIfMissing "${repoDir:?}/${ceeMiscLibLocal:?}" "${ceeMiscLibUrl:?}" \
  && if test "$(cd "${repoDir:?}" && grep -i "${ceeMiscLibVersion:?}" "${cacheDir:?}"/SHA256SUM | sha256sum --ignore-missing -c - |grep -E ' OK$'|wc -l)" -ne 1 ;then true \
      && printf 'ERROR: CeeMiscLib download checksum mismatch\n' && false \
    ;fi \
]=])end if getaddrinfoVersion then dst:write([=[
  && dloadInsecureIfMissing "${repoDir:?}/getaddrinfo-${getaddrinfoVersion:?}+${ARCH:?}.tgz" "https://github.com/hiddenalpha/getaddrinfo-cli/releases/download/v${getaddrinfoVersion:?}/getaddrinfo-${getaddrinfoVersion:?}+${ARCH:?}.tgz" \
  && if test "$(cd "${repoDir:?}" && grep "getaddrinfo-.*${getaddrinfoVersion:?}" "${cacheDir:?}/MD5SUM" | md5sum --ignore-missing -c - |grep -E ' OK$'|wc -l)" -ne 1 ;then true \
      && printf 'ERROR: getaddrinfo download checksum mismatch\n' && false \
    ;fi \
]=])end
    -- install
    if getaddrinfoVersion then dst:write([=[
  && $SUDO mkdir -p "/opt/getaddrinfo-${getaddrinfoVersion:?}" \
  && (cd /opt/getaddrinfo-${getaddrinfoVersion:?} && $SUDO tar xf "${repoDir:?}/getaddrinfo-${getaddrinfoVersion:?}+${ARCH:?}.tgz") \
  && mkdir -p ~/.local/bin \
  && ln -s "/opt/getaddrinfo-${getaddrinfoVersion:?}/bin/getaddrinfo" ~/.local/bin/getaddrinfo \
]=])end if ceeMiscLibVersion then dst:write([=[
  && $SUDO mkdir -p "/opt/CeeMiscLib-${ceeMiscLibVersion}" \
  && (cd "/opt/CeeMiscLib-${ceeMiscLibVersion:?}" && $SUDO tar xf "${repoDir:?}/${ceeMiscLibLocal:?}") \
  && mkdir -p ~/.local/bin \
  && (cd ~/.local/bin \
      && for E in /opt/CeeMiscLib-"${ceeMiscLibVersion:?}"/bin/* ;do true \
          && ln -s "$E" \
        ;done) \
]=])end
end


function writeAwsToolsInstallation( dst )
    dst:write--[[install argocd]]([=[
  && `# Install AWS related tools ` \
  && dloadInsecureIfMissing "${repoDir:?}/argocd-${argocdVersion:?}+linux-amd64" "https://github.com/argoproj/argo-cd/releases/download/v${argocdVersion:?}/argocd-linux-amd64" \
  && $SUDO mkdir -p "/opt/argocd-${argocdVersion:?}/bin" \
  && (cd /opt/argocd-${argocdVersion:?}/bin && $SUDO cp "${repoDir:?}/argocd-${argocdVersion:?}+linux-amd64" .) \
  && $SUDO chmod 0655 "/opt/argocd-${argocdVersion:?}/bin/argocd-${argocdVersion:?}+linux-amd64" \
  && mkdir -p ~/.local/bin \
  && (cd ~/.local/bin && ln -s /opt/argocd-${argocdVersion:?}/bin/argocd-${argocdVersion:?}+linux-amd64 argocd) \
]=])dst:write--[[install kubelogin]]([=[
  && kubeloginUrl="https://github.com/Azure/kubelogin/releases/download/v${kubeloginVersion:?}/kubelogin-linux-amd64.zip" \
  && printf %s\\n "Dload '${kubeloginUrl:?}'" \
  && rspCode=$(cd "${repoDir:?}" && curl -L --insecure -O -w '%{http_code}\n' "${kubeloginUrl:?}") \
  && if test "${rspCode?}" -ne "200" ;then true \
      && printf "kubelogin dload failed:\n%s\n" "${rspCode?}" && false \
    ;fi \
  && if test "$(cd "${repoDir:?}" && sha256sum --ignore-missing -c "${cacheDir:?}"/SHA256SUM |grep -E ' OK$'|wc -l)" -ne 1 ;then true \
      && printf 'ERROR: kubelogin download checksum mismatch\n' && false \
    ;fi \
  && $SUDO mkdir -p /opt/kubelogin-"${kubeloginVersion:?}/bin" /tmp/fuckstupidpackaging \
  && (cd /tmp/fuckstupidpackaging && $SUDO rm -rf * && $SUDO unzip "${repoDir:?}/kubelogin-*.zip") \
  && $SUDO mv "$(ls -d /tmp/fuckstupidpackaging/bin/*/kubelogin)" /opt/kubelogin-"${kubeloginVersion:?}/bin/." \
  && $SUDO chown root:root /opt/kubelogin-"${kubeloginVersion:?}"/bin/kubelogin \
  && $SUDO chmod 655 /opt/kubelogin-"${kubeloginVersion:?}"/bin/kubelogin \
  && mkdir -p ~/.local/bin \
  && ln -s /opt/kubelogin-"${kubeloginVersion:?}"/bin/kubelogin ~/.local/bin/. \
]=])dst:write--[[config]]([=[
  && mkdir "/home/${USER:?}/.kube" \
  && printf %s\\n "Dload '${kubeConfigUrl:?}'" \
  && rspCode=$(curl -sSL -o /home/${USER:?}/.kube/"${kubeConfigFile:?}" -w '%{http_code}\n' "${kubeConfigUrl:?}") \
  && if test "${rspCode?}" -ne "200" ;then true \
      && printf "kube/config dload failed:\n%s\n" "${rspCode?}" && false \
    ;fi \
  && if test -e "/home/${USER:?}/.kube/config" ;then true \
      && mv /home/${USER:?}/.kube/config /home/${USER:?}/.kube/config-$(date +%s).old \
    ;fi \
  && cp /home/${USER:?}/.kube/"${kubeConfigFile:?}" /home/${USER:?}/.kube/config \
]=])
end


function writeHostShareSetup( dst )
    dst:write([=[
  && $SUDO mkdir -p /c && $SUDO ln -s /mnt/cdrive/work /c/work \
  && $SUDO mkdir /mnt/cdrive \
  && (printf '/mnt/cdrive/work  /c/work  none  noauto,bind,user  0  0\n') | $SUDO tee -a /etc/fstab >/dev/null \
  && (printf '//10.0.2.2:/c  /mnt/cdrive  nfs  noauto,vers=3,user  0  0\n') | $SUDO tee -a /etc/fstab >/dev/null \
]=])
end


function writeKnownHashes( dst )
    dst:write([=[
  && `# Known hashes ` \
  && printf %s\\n \
       'e990013d2d658dd19ef2731bc9387d4ed88c60097d5364ac2d832871f2fc17d5 *kubelogin-linux-amd64.zip' \
       'ca47b335ee7433eca7d839ece328498944427b4f83f99de919ea26e8d7f07ee4 *CeeMiscLib-0.0.5-306-g99d785d+aarch64-linux-gnu.tgz' \
       'ec1077009965ee1c4681a043a74803ef96185590421af02b6ae8d877a793cf9d *CeeMiscLib-0.0.5-306-g99d785d+x86_64-linux-gnu.tgz' \
       '2d070cb39e06098373387984ef8d56635cded6e6bad4c8f8b36e9320b3a60511 *CeeMiscLib-0.0.5-306-g99d785d+x86_64-w64-mingw32.tgz' \
       '88f4143fd7d9579846e2294f1c87fc78f43264d8f0d4149e68c2367bcba44a86 *CeeMiscLib-0.0.5-330-g2b037a5+x86_64-linux-gnu.tgz' \
       '65fd69b505f2a62e741f15aa49ce64e4a58e9a8b6918308890de7da60f5be953 *CeeMiscLib-0.0.5-330-g2b037a5+x86_64-w64-mingw32.tgz' \
       '2085ada7dcbd7feaeefe40aa81ef6e0893e4944160f9db88e5fd159b26566a76 *CeeMiscLib-0.0.5-330-g2b037a5+aarch64-linux-gnu.tgz' \
     | $SUDO tee "${cacheDir:?}"/SHA256SUM > /dev/null \
  && printf %s\\n \
       'b97fbffbebfe73e6e75371bdbc032a4f *getaddrinfo-0.0.2+x86_64-linux-gnu.tgz' \
       '200e49e0046b42f35f6dfc12d7ad93fc *getaddrinfo-0.0.2+x86_64-w64-mingw32.tgz' \
       '6981e10f59385fe974ebd0c8e7432516 *getaddrinfo-0.0.2+x86_64-alpine-linux-musl.tgz' \
       'c6c789fc990b8aa18dbb8800b8417d06 *getaddrinfo-0.0.2+aarch64-linux-gnu.tgz' \
     | $SUDO tee "${cacheDir:?}"/MD5SUM > /dev/null \
]=])
end


function writeEmbeddedReadme( dst )
    dst:write([=[
  && printf %s\\n \
       '' \
       '  PaISA Workhorse Notes' \
       '  =====================' \
       '' \
       '  - [saml is dead](https://wikit.post.ch/x/0Fu4Vg)' \
       '  - [Maybe saml2aws becomes obsolete](https://wikit.post.ch/display/CDAF/How+to%3A+Setup-Guide+saml2aws?focusedCommentId=1741722098&src=mail&src.mail.product=confluence-server&src.mail.timestamp=1721914205401&src.mail.notification=com.atlassian.confluence.plugins.confluence-notifications-batch-plugin%3Abatching-notification&src.mail.recipient=8a81e4a6427b972601427b98b9262c20&src.mail.action=view#comment-1741722098)' \
       '' \
       '' \
       '' \
       '  ## Docker (local)' \
       '' \
       '  sudo podman pull docker.tools.post.ch/paisa/r-service-base:03.06.42.00' \
       '  sudo podman pull docker.tools.post.ch/library/amazonlinux:2023.6.20241121.0' \
       '' \
       '' \
       '' \
       '  ## Kubectl, Kubernetes, AWS, ...' \
       '' \
       '  Common args:  --namespace isa-houston-int --kubeconfig ~/.kube/config' \
       '  export KUBECONFIG=path/to/one:path/to/two' \
       '' \
       '  Thx erbmi (2024-12-19):' \
       '  alias eksm15int="aws eks update-kubeconfig --name eks-int-m15cn0001"' \
       '  alias agrajagtest="kubectl config set-context --current --namespace=isa-diNamespace-test"' \
       '' \
       '  FüdleWall: https://fwehfnet.pnet.ch/connect' \
       '  Known Namespaces: isa-houston-prod, isa-houston-int, isa-houston-snapshot,' \
       '      isa-houston-test' \
       '' \
       '  kubectl version   (WARN: server/client max 2 minor versions apart of each other!)' \
       '  kubectl config view' \
       '  kubectl config get-contexts' \
       '  kubectl config use-context TODO_replace_me' \
       '  kubectl config view | grep namespace' \
       '  kubectl config set-context $(kubectl config current-context) --namespace=TODO_replace_me' \
       '  kubectl get nodes,pods,service,configmaps,deployments,statefulset' \
       '  kubectl get pods houston-42' \
       '  kubectl get statefulset houston-42 -o yaml' \
       '  kubectl exec -ti preflux-5d57f7dbcc-42w7m -- bash' \
       '  kubectl top pod houston-42' \
       '' \
       '  Output with details:  -o yaml' \
       '' \
     | tee /home/${USER:?}/README.txt \
]=])
end


function main()
    local dst = io.stdout
    dst:write("#!/bin/sh\nset -e \\\n")
    writeVariables(dst)
    writeDloadIfMissingFunc(dst)
    dst:write("  && mkdir -p \"${cacheDir:?}\" \"${repoDir:?}\" \\\n")
    writeKnownHashes(dst)
    writeProxySettings(dst)
    writePkgInstallation(dst)
    writeSwapSetup(dst)
    writeAwsToolsInstallation(dst)
    writeHiddenalphaToolsInstallation(dst)
    --writeHostShareSetup(dst)
    dst:write([=[
  && printf 'export PATH="%s/.local/bin:$PATH"\n' ~ >> ~/.bashrc \
  && export PATH="/home/${USER?}/.local/bin:$PATH" \
  && printf 'MAVEN_OPTS="--add-opens jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED --add-opens jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED --add-opens jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED --add-opens jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED --add-opens jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-opens java.base/java.util=ALL-UNNAMED --add-opens java.base/java.lang.reflect=ALL-UNNAMED --add-opens java.base/java.text=ALL-UNNAMED --add-opens java.desktop/java.awt.font=ALL-UNNAMED"' | $SUDO tee -a /etc/environment > /dev/null \
]=])
    writeEmbeddedReadme(dst)
    dst:write("  && printf '\\n  DONE. Setup completed.\\n\\n' \\\n")
end






main()

