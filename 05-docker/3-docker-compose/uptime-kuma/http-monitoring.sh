# Using HTTP - Keyword monitors that query the swarm task states of the docker services...

# URL
http://<manager node ip>:2375/tasks?filters={"desired-state":["running"],"service":["service_name"]}

# Keyword
"State":"running"