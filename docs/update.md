# To update the AV run the following:

```bash
$ docker run --name kaspersky malice/kaspersky update
```

## Then to use the updated zoner container:

```bash
$ docker commit kaspersky malice/kaspersky:updated
$ docker rm kaspersky # clean up updated container
$ docker run --rm malice/kaspersky:updated EICAR
```
