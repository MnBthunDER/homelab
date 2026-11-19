# locate portainer services
root@swm1:~# docker service ls
NAME                  MODE         REPLICAS   IMAGE                           PORTS
portainer_agent       global       3/3        portainer/agent:2.21.5

# download portainer-ee:lts
root@swm1:~# docker pull portainer/portainer-ce:lts
lts: Pulling from portainer/portainer-ce
b2cf3e56c855: Pull complete
5d4061146616: Pull complete
04de093ad5ed: Pull complete
a528983d077c: Pull complete
26eb502a78ed: Pull complete
17df20d55bce: Pull complete
ecfdf0a97dbe: Pull complete
c5aef6168175: Pull complete
ab729d7de243: Pull complete
4f4fb700ef54: Pull complete
Digest: sha256:09db0c204595cab39981fd559faa0a2f4e0f67387eb0b14b2926adf4e058a6d1
Status: Downloaded newer image for portainer/portainer-ce:lts
docker.io/portainer/portainer-ce:lts

# update portainer
root@swm1:~# docker service update --image portainer/portainer-ce:lts --publish-add 9443:9443 --force portainer_portainer
portainer_portainer
overall progress: 1 out of 1 tasks
1/1: running   [==================================================>]
verify: Service portainer_portainer converged

# download portainer agent
root@swm1:~# docker pull portainer/agent:lts
lts: Pulling from portainer/agent
b2cf3e56c855: Already exists
5d4061146616: Already exists
6735663f5b4b: Pull complete
59bcb05b55d5: Pull complete
e00cdeb2e2ec: Pull complete
a8e51a4685d5: Pull complete
8b15d9a100c1: Pull complete
48e7bcca96f2: Pull complete
f46454fda56a: Pull complete
Digest: sha256:c307878eb2a45d2d31492a31163015feab2753c1a13c91d0462b8fbecbf86f6a
Status: Downloaded newer image for portainer/agent:lts
docker.io/portainer/agent:lts

# update portainer agent
root@swm1:~# docker service update --image portainer/agent:lts --force portainer_agent
portainer_agent
overall progress: 3 out of 3 tasks
d28tw3eakdp1: running   [==================================================>]
v0fkd23l7rzd: running   [==================================================>]
y5e7zn9oe8m0: running   [==================================================>]
verify: Service portainer_agent converged
