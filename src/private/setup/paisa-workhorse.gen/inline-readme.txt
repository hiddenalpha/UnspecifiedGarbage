
  PaISA Workhorse Notes
  =====================

  - [saml is dead](https://wikit.post.ch/x/0Fu4Vg)
  - [Maybe saml2aws becomes obsolete](https://wikit.post.ch/display/CDAF/How+to%3A+Setup-Guide+saml2aws?focusedCommentId=1741722098&src=mail&src.mail.product=confluence-server&src.mail.timestamp=1721914205401&src.mail.notification=com.atlassian.confluence.plugins.confluence-notifications-batch-plugin%3Abatching-notification&src.mail.recipient=8a81e4a6427b972601427b98b9262c20&src.mail.action=view#comment-1741722098)



  ## How to upgrade kubectl version

  sudo nano /etc/apt/sources.list.d/kubernetes.list
  sudo apt update
  sudo apt purge -y kubectl
  sudo apt install --no-install-recommends -y kubectl



  ## redis 

  sudo service --status-all 2>&1 | grep redis
  sudo service redis-houston stop
  sudo service redis-houston start
  sudo update-rc.d redis-houston remove
  sudo update-rc.d redis-houston defaults
  tail -n42 -F /var/log/redis/redis-houston.log

  sudo nano /etc/redis/redis-eagle.conf
  sudo nano /etc/redis/redis-houston.conf
  sudo nano /etc/redis/redis-volatile.conf

  There is an additional redis 'redis-volatile' configured with persistence
  disabled. Can be handy for exmaple for integration tests which happily spam
  our redis with a lot of trash. For example Gateleen + Friends have some very
  annoying test cases cluttering redis storage without asking.



  ## Docker (local)

  sudo podman pull docker.tools.post.ch/paisa/alice:04.00.09.00
  sudo podman pull docker.tools.post.ch/paisa/r-service-base:03.06.49.00
  sudo podman pull docker.tools.post.ch/library/amazonlinux:2023.6.20241121.0
  sudo podman pull docker.tools.post.ch/library/alpine:3.21.2
  sudo podman pull docker.tools.post.ch/library/busybox:1.37.0-musl
  sudo podman pull docker.tools.post.ch/library/busybox:1.37.0-glibc



  ## Kubectl, Kubernetes, AWS, ...

  Common args:  --namespace isa-houston-int --kubeconfig ~/.kube/config
  export KUBECONFIG=path/to/one:path/to/two

  Thx erbmi (2024-12-19):
  alias eksm15int="aws eks update-kubeconfig --name eks-int-m15cn0001"
  alias agrajagtest="kubectl config set-context --current --namespace=isa-diNamespace-test"

  Firewall: https://fwehfnet.pnet.ch/connect
  Known Namespaces: isa-houston-prod, isa-houston-int, isa-houston-snapshot,
      isa-houston-test

  kubectl version   (WARN: server/client max 2 minor versions apart of each other!)
  kubectl config view
  kubectl config view | grep namespace
  kubectl config get-contexts
  kubectl config use-context eks-int-m15cn0001
  kubectl config set-context $(kubectl config current-context) --namespace=TODO_replace_me
  kubectl get nodes,pods,service,configmaps,deployments,statefulset
  kubectl describe configmaps ${SERVICE:?}-config
  kubectl get pods houston-42
  kubectl get statefulset houston-42 -o yaml
  kubectl exec -ti preflux-5d57f7dbcc-42w7m -- bash
  kubectl top pod houston-42

  Output with details:  -o yaml

