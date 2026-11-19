# Check and ensure docker is currently not on any swarm
docker swarm leave --force

# Create initial docker swarm manager
docker swarm init

# Generated token to be copied into the other node, example:
docker swarm join --token SWMTKN-1-fakerandom6p020zd20gxk44asadasdasasdasdds-but7l197dukateqoky31uqbc3 10.1.30.1:2377

# Promote remaining workers node as managers
docker node promote <node name>

# Check docker swarm manager nodes (swm) status, example:
docker node ls

    ID                            HOSTNAME            STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
    fakerandomidawds34ssf8da2 *   swm1.domain.com       Ready     Active         Leader           27.5.1
    fakerandomvsfgdfdfg34gde4     swm2.domain.com       Ready     Active         Reachable        27.5.1
    fakerandomiwzxvx3973j4345     swm3.domain.com       Ready     Active         Reachable        27.5.1

# Docker Swarm In Action https://yanbin.blog/english-docker-swarm-in-action/
# How does Docker Swarm implement volume sharing? https://stackoverflow.com/questions/47756029/how-does-docker-swarm-implement-volume-sharing