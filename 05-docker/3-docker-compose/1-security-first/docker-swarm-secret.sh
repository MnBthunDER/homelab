echo "Test2" | \
> docker secret create Test2 -
fdlhyz6a79gc8i7go5nr4kwls


docker secret ls
ID                          NAME      DRIVER    CREATED              UPDATED
iy6etf0v9u8cgni63124zhljk   Test1               About a minute ago   About a minute ago

docker secret inspect Test1 
[
    {
        "ID": "iy6etf0v9u8cgni63124zhljk",
        "Version": {
            "Index": 2504359
        },
        "CreatedAt": "2026-09-04T07:07:35.306141755Z",
        "UpdatedAt": "2026-09-04T07:07:35.306141755Z",
        "Spec": {
            "Name": "Test1",
            "Labels": {}
        }
    }
]


On docker-compose.yaml

secrets:
   Test1:
   external: true


services:
   app:
      image: 
      ports:
      secrets:
         - Test1


docker exec -it container /bin/sh/code


cd /run/secrets
ls

cat Test1