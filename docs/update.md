# To update the AV run the following:

```bash
$ docker run --name=zoner malice/zoner update
```

## Then to use the updated zoner container:

```bash
$ docker commit zoner malice/zoner:updated
$ docker rm zoner # clean up updated container
$ docker run --rm malice/zoner:updated EICAR
```
